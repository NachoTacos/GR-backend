namespace Ricartti.Application.Portfolio;

/// <summary>Lecturas públicas del portafolio. Solo devuelve proyectos visibles.</summary>
public interface IPortfolioReadRepository
{
    Task<IReadOnlyList<CategoryDto>> ListActiveCategoriesAsync(CancellationToken ct);

    /// <param name="categorySlug">Filtro opcional por categoría activa.</param>
    Task<IReadOnlyList<ProjectDto>> ListVisibleProjectsAsync(string? categorySlug, CancellationToken ct);

    Task<ProjectDto?> GetVisibleProjectAsync(string slug, CancellationToken ct);
}
