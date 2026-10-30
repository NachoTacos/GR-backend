using Ricartti.Application.Common;
using Ricartti.Domain.Portfolio;

namespace Ricartti.Application.Portfolio.Admin;

/// <summary>
/// Casos de uso del panel para proyectos (handoff §6.17 y §9). Reglas clave:
/// un proyecto nace oculto; solo se publica con portada y textos en ES y EN; los
/// archivos subidos se validan por firma binaria y nunca usan el nombre del cliente.
/// </summary>
public sealed class AdminProjectService(
    IAdminProjectRepository repository,
    IUnitOfWork unitOfWork,
    IPublicImageStorage images,
    ImageOptions imageOptions)
{
    private const int MaxResults = 12;
    private const int MaxEvidence = 12;
    private const string ManagedPrefix = "/uploads/projects/";

    public async Task<IReadOnlyList<ProjectDto>> ListAsync(CancellationToken ct) =>
        (await repository.ListAllAsync(ct)).Select(p => ProjectMapper.ToDto(p, includeVersion: true)).ToList();

    public async Task<Result<ProjectDto>> GetAsync(long id, CancellationToken ct)
    {
        var project = await repository.GetAsync(id, tracking: false, ct);
        return project is null ? Error.NotFound() : ProjectMapper.ToDto(project, includeVersion: true);
    }

    public async Task<IReadOnlyList<AdminCategoryDto>> ListCategoriesAsync(CancellationToken ct) =>
        (await repository.ListCategoriesAsync(ct))
        .Select(c => new AdminCategoryDto(c.Slug, new Localized(c.NameEs, c.NameEn), c.SortOrder, c.IsActive))
        .ToList();

    public async Task<IReadOnlyList<SupportAreaDto>> ListSupportAreasAsync(CancellationToken ct) =>
        (await repository.ListSupportAreasAsync(ct))
        .Select(a => new SupportAreaDto(a.Code, new Localized(a.NameEs, a.NameEn)))
        .ToList();

    // ------------------------------------------------------------------
    // Crear: siempre oculto, aunque el cliente intente otra cosa.
    // ------------------------------------------------------------------
    public async Task<Result<ProjectDto>> CreateAsync(
        ProjectWriteData data, ProjectUploads uploads, long adminId, CancellationToken ct)
    {
        var normalized = await NormalizeAsync(data, uploads, existing: null, ct);
        if (!normalized.IsSuccess)
        {
            return normalized.Error!;
        }
        var n = normalized.Value!;

        var project = new Project
        {
            CategoryId = n.Category.Id,
            Category = n.Category,
            Slug = n.Slug,
            Name = n.Name,
            Stage = n.Stage,
            Year = n.Year,
            SummaryEs = n.SummaryEs,
            SummaryEn = n.SummaryEn,
            DescriptionEs = n.DescriptionEs,
            DescriptionEn = n.DescriptionEn,
            IsVisible = false,
            CreatedBy = adminId,
            UpdatedBy = adminId,
        };
        repository.Add(project);

        var saved = new List<string>();
        try
        {
            await unitOfWork.ExecuteAsync(async () =>
            {
                // Primero la fila, para conocer su id y poder guardar los archivos en su carpeta.
                await repository.SaveChangesAsync(ct);

                if (uploads.Cover is not null)
                {
                    project.CoverImagePath = await SaveAsync(project.Id, uploads.Cover, n.CoverExtension!, saved, ct);
                }

                await ApplyEvidenceFilesAsync(project, n, uploads, saved, ct);

                ApplyResults(project, n);
                project.SupportAreas.Clear();
                project.SupportAreas.AddRange(n.Support);

                await repository.SaveChangesAsync(ct);
            }, ct);
        }
        catch
        {
            await DeleteQuietlyAsync(saved);
            throw;
        }

        return await GetAsync(project.Id, ct);
    }

    // ------------------------------------------------------------------
    // Editar: exige la versión que se cargó; 409 si otra persona editó antes.
    // ------------------------------------------------------------------
    public async Task<Result<ProjectDto>> UpdateAsync(
        long id, ProjectWriteData data, ProjectUploads uploads, long adminId, CancellationToken ct)
    {
        var project = await repository.GetAsync(id, tracking: true, ct);
        if (project is null)
        {
            return Error.NotFound();
        }
        if (data.Version is null)
        {
            return Error.Validation("version", "required");
        }
        if (data.Version != project.Version)
        {
            return Error.Conflict();
        }

        var normalized = await NormalizeAsync(data, uploads, project, ct);
        if (!normalized.IsSuccess)
        {
            return normalized.Error!;
        }
        var n = normalized.Value!;

        // Un proyecto visible no puede quedar sin portada o sin textos: la BD lo rechazaría.
        if (project.IsVisible)
        {
            var missing = MissingForPublication(
                hasCover: project.CoverImagePath is not null || uploads.Cover is not null,
                n.SummaryEs, n.SummaryEn, n.DescriptionEs, n.DescriptionEn);
            if (missing.Count > 0)
            {
                return Error.Validation(missing);
            }
        }

        project.CategoryId = n.Category.Id;
        project.Category = n.Category;
        project.Slug = n.Slug;
        project.Name = n.Name;
        project.Stage = n.Stage;
        project.Year = n.Year;
        project.SummaryEs = n.SummaryEs;
        project.SummaryEn = n.SummaryEn;
        project.DescriptionEs = n.DescriptionEs;
        project.DescriptionEn = n.DescriptionEn;
        project.UpdatedBy = adminId;

        var saved = new List<string>();
        var toDelete = new List<string>();
        try
        {
            await unitOfWork.ExecuteAsync(async () =>
            {
                if (uploads.Cover is not null)
                {
                    if (project.CoverImagePath is { } oldCover && IsManaged(oldCover))
                    {
                        toDelete.Add(oldCover);
                    }
                    project.CoverImagePath = await SaveAsync(project.Id, uploads.Cover, n.CoverExtension!, saved, ct);
                }

                // Se quitan las evidencias que ya no aparecen en la lista.
                var keptSrcs = n.Evidence.Where(e => e.ExistingSrc is not null).Select(e => e.ExistingSrc!).ToHashSet();
                foreach (var image in project.Images.Where(i => !keptSrcs.Contains(i.ImagePath)).ToList())
                {
                    project.Images.Remove(image);
                    if (IsManaged(image.ImagePath))
                    {
                        toDelete.Add(image.ImagePath);
                    }
                }

                await ApplyEvidenceFilesAsync(project, n, uploads, saved, ct);

                project.Results.Clear();
                ApplyResults(project, n);
                project.SupportAreas.Clear();
                project.SupportAreas.AddRange(n.Support);

                repository.Touch(project);
                await repository.SaveChangesAsync(ct);
            }, ct);
        }
        catch (ConcurrencyException)
        {
            await DeleteQuietlyAsync(saved);
            return Error.Conflict();
        }
        catch
        {
            await DeleteQuietlyAsync(saved);
            throw;
        }

        // Los archivos reemplazados se borran solo después de confirmar la transacción.
        await DeleteQuietlyAsync(toDelete);
        return await GetAsync(project.Id, ct);
    }

    // ------------------------------------------------------------------
    // Visibilidad: PATCH { visible } (handoff §9). Ocultar nunca falla; publicar exige contenido completo.
    // ------------------------------------------------------------------
    public async Task<Result<ProjectDto>> SetVisibilityAsync(
        long id, bool? visible, long adminId, CancellationToken ct)
    {
        if (visible is null)
        {
            return Error.Validation("visible", "required");
        }

        var project = await repository.GetAsync(id, tracking: true, ct);
        if (project is null)
        {
            return Error.NotFound();
        }

        if (visible is true)
        {
            var missing = MissingForPublication(
                hasCover: project.CoverImagePath is not null,
                project.SummaryEs, project.SummaryEn, project.DescriptionEs, project.DescriptionEn);
            if (missing.Count > 0)
            {
                return Error.Validation(missing);
            }
        }

        project.IsVisible = visible.Value;
        project.UpdatedBy = adminId;
        repository.Touch(project);
        try
        {
            await repository.SaveChangesAsync(ct);
        }
        catch (ConcurrencyException)
        {
            return Error.Conflict();
        }

        return await GetAsync(id, ct);
    }

    /// <summary>Campos que faltan para publicar (handoff §6.17: ambos idiomas son obligatorios).</summary>
    private static Dictionary<string, string> MissingForPublication(
        bool hasCover, string? summaryEs, string? summaryEn, string? descriptionEs, string? descriptionEn)
    {
        var missing = new Dictionary<string, string>();
        if (!hasCover) missing["cover"] = "required";
        if (summaryEs is null) missing["summary.es"] = "required";
        if (summaryEn is null) missing["summary.en"] = "required";
        if (descriptionEs is null) missing["description.es"] = "required";
        if (descriptionEn is null) missing["description.en"] = "required";
        return missing;
    }

    // ------------------------------------------------------------------
    // Validación y normalización (compartida por crear y editar).
    // ------------------------------------------------------------------
    private sealed record EvidencePlan(string? ExistingSrc, int? FileIndex, string CaptionEs, string? CaptionEn);

    private sealed record ResultPlan(string Value, string LabelEs, string? LabelEn);

    private sealed record Normalized(
        string Name,
        string Slug,
        Category Category,
        ProjectStage Stage,
        short Year,
        string? SummaryEs,
        string? SummaryEn,
        string? DescriptionEs,
        string? DescriptionEn,
        IReadOnlyList<ResultPlan> Results,
        IReadOnlyList<SupportArea> Support,
        IReadOnlyList<EvidencePlan> Evidence,
        string? CoverExtension,
        IReadOnlyList<string> EvidenceExtensions);

    private async Task<Result<Normalized>> NormalizeAsync(
        ProjectWriteData data, ProjectUploads uploads, Project? existing, CancellationToken ct)
    {
        // Un archivo demasiado grande es un 413, antes de validar el resto.
        if (uploads.Cover is { } bigCover && bigCover.Length > imageOptions.MaxBytes)
        {
            return Error.PayloadTooLarge("cover", "file_size");
        }
        if (uploads.Evidence.Any(f => f.Length > imageOptions.MaxBytes))
        {
            return Error.PayloadTooLarge("evidence", "file_size");
        }

        var v = new FieldValidator();
        var name = v.Line(data.Name, "name", required: true, min: 1, max: 120);

        // Categoría
        Category? category = null;
        if (string.IsNullOrWhiteSpace(data.Category))
        {
            v.Fail("category", "required");
        }
        else
        {
            category = await repository.FindCategoryAsync(data.Category.Trim(), ct);
            if (category is null) v.Fail("category", "invalid");
        }

        // Etapa y año
        ProjectStage stage = default;
        var stageText = v.OneOf(data.Stage, "stage", ["incubacion", "venture", "exit"]);
        if (stageText is not null) stage = Enum.Parse<ProjectStage>(stageText, ignoreCase: true);

        short year = 0;
        if (data.Year is null) v.Fail("year", "required");
        else if (data.Year is < 1990 or > 2100) v.Fail("year", "invalid");
        else year = (short)data.Year.Value;

        // Textos bilingües. Pueden estar vacíos en un borrador; no para publicar.
        var summaryEs = v.Line(data.Summary?.Es, "summary.es", required: false, min: 1, max: 120);
        var summaryEn = v.Line(data.Summary?.En, "summary.en", required: false, min: 1, max: 120);
        var descriptionEs = v.Text(data.Description?.Es, "description.es", required: false, max: 5000);
        var descriptionEn = v.Text(data.Description?.En, "description.en", required: false, max: 5000);

        // Resultados
        var results = new List<ResultPlan>();
        var resultInputs = data.Results ?? [];
        if (resultInputs.Count > MaxResults) v.Fail("results", "invalid");
        for (var i = 0; i < Math.Min(resultInputs.Count, MaxResults); i++)
        {
            var r = resultInputs[i];
            var value = v.Line(r.Value, $"results[{i}].value", required: true, min: 1, max: 30);
            var labelEs = v.Line(r.Label?.Es, $"results[{i}].label.es", required: true, min: 1, max: 100);
            var labelEn = v.Line(r.Label?.En, $"results[{i}].label.en", required: false, min: 1, max: 100);
            if (value is not null && labelEs is not null) results.Add(new ResultPlan(value, labelEs, labelEn));
        }

        // Áreas de respaldo
        var codes = (data.Support ?? []).Select(c => c?.Trim() ?? "").ToList();
        IReadOnlyList<SupportArea> support = [];
        if (codes.Any(c => c.Length == 0) || codes.Distinct().Count() != codes.Count)
        {
            v.Fail("support", "invalid");
        }
        else if (codes.Count > 0)
        {
            support = await repository.FindSupportAreasAsync(codes, ct);
            if (support.Count != codes.Count) v.Fail("support", "invalid");
        }

        // Evidencias: cada una conserva una imagen existente (Src) o usa un archivo nuevo (FileIndex).
        var evidence = new List<EvidencePlan>();
        var evidenceInputs = data.Evidence ?? [];
        if (evidenceInputs.Count > MaxEvidence) v.Fail("evidence", "invalid");
        var usedFiles = new HashSet<int>();
        var usedSrcs = new HashSet<string>();
        var existingSrcs = existing?.Images.Select(i => i.ImagePath).ToHashSet() ?? [];
        for (var i = 0; i < Math.Min(evidenceInputs.Count, MaxEvidence); i++)
        {
            var e = evidenceInputs[i];
            var captionEs = v.Line(e.Caption?.Es, $"evidence[{i}].caption.es", required: true, min: 1, max: 150);
            var captionEn = v.Line(e.Caption?.En, $"evidence[{i}].caption.en", required: false, min: 1, max: 150);

            var hasSrc = !string.IsNullOrWhiteSpace(e.Src);
            if (hasSrc == (e.FileIndex is not null))
            {
                v.Fail($"evidence[{i}]", "invalid"); // Debe traer exactamente uno de los dos.
                continue;
            }

            if (hasSrc)
            {
                var src = e.Src!.Trim();
                if (!existingSrcs.Contains(src) || !usedSrcs.Add(src)) v.Fail($"evidence[{i}].src", "invalid");
                else if (captionEs is not null) evidence.Add(new EvidencePlan(src, null, captionEs, captionEn));
            }
            else
            {
                var index = e.FileIndex!.Value;
                if (index < 0 || index >= uploads.Evidence.Count || !usedFiles.Add(index)) v.Fail($"evidence[{i}].fileIndex", "invalid");
                else if (captionEs is not null) evidence.Add(new EvidencePlan(null, index, captionEs, captionEn));
            }
        }
        if (usedFiles.Count != uploads.Evidence.Count)
        {
            v.Fail("evidence", "invalid"); // Hay archivos que ninguna evidencia usa.
        }

        // Archivos: solo JPEG, PNG y WebP, reconocidos por su firma.
        string? coverExtension = null;
        if (uploads.Cover is not null)
        {
            coverExtension = await ImageSignature.DetectExtensionAsync(uploads.Cover.Content, ct);
            if (coverExtension is null) v.Fail("cover", "file_type");
        }
        var evidenceExtensions = new List<string>();
        foreach (var file in uploads.Evidence)
        {
            var ext = await ImageSignature.DetectExtensionAsync(file.Content, ct);
            if (ext is null) v.Fail("evidence", "file_type");
            evidenceExtensions.Add(ext ?? "");
        }

        // Slug: el que se envíe (único), el actual al editar, o uno generado desde el nombre.
        string? slug = null;
        var rawSlug = data.Slug?.Trim();
        if (!string.IsNullOrEmpty(rawSlug))
        {
            if (!Slugs.IsValid(rawSlug, GalleryService.ProjectSlugMaxLength)) v.Fail("slug", "invalid");
            else if (await repository.SlugExistsAsync(rawSlug, existing?.Id, ct)) v.Fail("slug", "taken");
            else slug = rawSlug;
        }
        else if (existing is not null)
        {
            slug = existing.Slug;
        }
        else if (name is not null)
        {
            slug = await UniqueSlugAsync(name, ct);
        }

        if (!v.IsValid)
        {
            return Error.Validation(v.Errors);
        }

        return new Normalized(name!, slug!, category!, stage, year, summaryEs, summaryEn, descriptionEs,
            descriptionEn, results, support, evidence, coverExtension, evidenceExtensions);
    }

    private async Task<string> UniqueSlugAsync(string name, CancellationToken ct)
    {
        var max = GalleryService.ProjectSlugMaxLength;
        var baseSlug = Slugs.From(name, max - 4, "proyecto");
        var candidate = baseSlug;
        for (var suffix = 2; await repository.SlugExistsAsync(candidate, null, ct); suffix++)
        {
            candidate = $"{baseSlug}-{suffix}";
        }
        return candidate;
    }

    // ------------------------------------------------------------------
    // Aplicar cambios a la entidad
    // ------------------------------------------------------------------
    private static void ApplyResults(Project project, Normalized n)
    {
        for (var i = 0; i < n.Results.Count; i++)
        {
            project.Results.Add(new ProjectResult
            {
                Value = n.Results[i].Value,
                LabelEs = n.Results[i].LabelEs,
                LabelEn = n.Results[i].LabelEn,
                SortOrder = i + 1,
            });
        }
    }

    /// <summary>Reordena y renombra las evidencias existentes y guarda las nuevas (en el orden de la lista).</summary>
    private async Task ApplyEvidenceFilesAsync(
        Project project, Normalized n, ProjectUploads uploads, List<string> saved, CancellationToken ct)
    {
        for (var i = 0; i < n.Evidence.Count; i++)
        {
            var plan = n.Evidence[i];
            if (plan.ExistingSrc is not null)
            {
                var image = project.Images.First(x => x.ImagePath == plan.ExistingSrc);
                image.CaptionEs = plan.CaptionEs;
                image.CaptionEn = plan.CaptionEn;
                image.SortOrder = i + 1;
            }
            else
            {
                var index = plan.FileIndex!.Value;
                var path = await SaveAsync(project.Id, uploads.Evidence[index], n.EvidenceExtensions[index], saved, ct);
                project.Images.Add(new ProjectImage
                {
                    ImagePath = path,
                    CaptionEs = plan.CaptionEs,
                    CaptionEn = plan.CaptionEn,
                    SortOrder = i + 1,
                });
            }
        }
    }

    private async Task<string> SaveAsync(
        long projectId, ImageUpload upload, string extension, List<string> saved, CancellationToken ct)
    {
        var path = await images.SaveProjectImageAsync(projectId, upload.Content, extension, ct);
        saved.Add(path);
        return path;
    }

    private async Task DeleteQuietlyAsync(IEnumerable<string> paths)
    {
        foreach (var path in paths)
        {
            try
            {
                await images.DeleteAsync(path, CancellationToken.None);
            }
            catch
            {
                // Un archivo que no se pudo borrar queda huérfano, pero no rompe la operación ya confirmada.
            }
        }
    }

    private static bool IsManaged(string path) => path.StartsWith(ManagedPrefix, StringComparison.Ordinal);
}
