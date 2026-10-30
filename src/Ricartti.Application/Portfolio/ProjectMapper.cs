using Ricartti.Application.Common;
using Ricartti.Domain.Portfolio;

namespace Ricartti.Application.Portfolio;

public static class ProjectMapper
{
    /// <summary>
    /// Entidad → contrato del handoff. La versión (token de concurrencia) solo se
    /// incluye en las respuestas del panel, que la necesita para editar.
    /// </summary>
    public static ProjectDto ToDto(Project p, bool includeVersion = false) => new(
        Id: p.Id,
        Slug: p.Slug,
        Category: p.Category.Slug,
        Stage: p.Stage.ToString().ToLowerInvariant(),
        Year: p.Year,
        Name: p.Name,
        Visible: p.IsVisible,
        Summary: Localized.From(p.SummaryEs ?? "", p.SummaryEn),
        Description: Localized.From(p.DescriptionEs ?? "", p.DescriptionEn),
        Cover: p.CoverImagePath ?? "",
        Evidence: p.Images
            .OrderBy(i => i.SortOrder).ThenBy(i => i.Id)
            .Select(i => new EvidenceDto(i.ImagePath, Localized.From(i.CaptionEs, i.CaptionEn)))
            .ToList(),
        Results: p.Results
            .OrderBy(r => r.SortOrder).ThenBy(r => r.Id)
            .Select(r => new ResultDto(r.Value, Localized.From(r.LabelEs, r.LabelEn)))
            .ToList(),
        Support: p.SupportAreas
            .OrderBy(a => a.SortOrder)
            .Select(a => a.Code)
            .ToList(),
        UpdatedAt: p.UpdatedAt,
        Version: includeVersion ? p.Version : null);
}
