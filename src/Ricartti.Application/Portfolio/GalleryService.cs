using Ricartti.Application.Common;

namespace Ricartti.Application.Portfolio;

/// <summary>Casos de uso de la galería pública.</summary>
public sealed class GalleryService(IPortfolioReadRepository repository)
{
    public const int CategorySlugMaxLength = 40;
    public const int ProjectSlugMaxLength = 80;

    public Task<IReadOnlyList<CategoryDto>> ListCategoriesAsync(CancellationToken ct) =>
        repository.ListActiveCategoriesAsync(ct);

    /// <summary>Filtro resuelto en el servidor. Un valor con formato inválido es un error de validación.</summary>
    public async Task<Result<IReadOnlyList<ProjectDto>>> ListProjectsAsync(string? category, CancellationToken ct)
    {
        var slug = string.IsNullOrWhiteSpace(category) ? null : category.Trim();
        if (slug is not null && !Slugs.IsValid(slug, CategorySlugMaxLength))
        {
            return Error.Validation("category", "invalid");
        }

        return Result<IReadOnlyList<ProjectDto>>.Success(await repository.ListVisibleProjectsAsync(slug, ct));
    }

    /// <summary>404 si el slug no existe, está oculto o no tiene un formato válido.</summary>
    public async Task<Result<ProjectDto>> GetProjectAsync(string slug, CancellationToken ct)
    {
        if (!Slugs.IsValid(slug, ProjectSlugMaxLength))
        {
            return Error.NotFound();
        }

        var project = await repository.GetVisibleProjectAsync(slug, ct);
        return project is null ? Error.NotFound() : project;
    }
}
