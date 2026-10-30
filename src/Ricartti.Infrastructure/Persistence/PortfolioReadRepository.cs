using Microsoft.EntityFrameworkCore;
using Ricartti.Application.Common;
using Ricartti.Application.Portfolio;
using Ricartti.Domain.Portfolio;

namespace Ricartti.Infrastructure.Persistence;

/// <summary>
/// Lecturas públicas. Todas las consultas son LINQ (parametrizadas por EF Core)
/// y siempre filtran is_visible, sin importar los parámetros recibidos.
/// </summary>
public sealed class PortfolioReadRepository(RicarttiDbContext db) : IPortfolioReadRepository
{
    public async Task<IReadOnlyList<CategoryDto>> ListActiveCategoriesAsync(CancellationToken ct)
    {
        var rows = await db.Categories
            .AsNoTracking()
            .Where(c => c.IsActive)
            .OrderBy(c => c.SortOrder).ThenBy(c => c.Id)
            .Select(c => new
            {
                c.Slug,
                c.NameEs,
                c.NameEn,
                c.SortOrder,
                Count = c.Projects.Count(p => p.IsVisible),
            })
            .ToListAsync(ct);

        return rows
            .Select(c => new CategoryDto(c.Slug, new Localized(c.NameEs, c.NameEn), c.SortOrder, c.Count))
            .ToList();
    }

    public async Task<IReadOnlyList<ProjectDto>> ListVisibleProjectsAsync(string? categorySlug, CancellationToken ct)
    {
        var query = VisibleProjects();
        if (categorySlug is not null)
        {
            query = query.Where(p => p.Category.Slug == categorySlug && p.Category.IsActive);
        }

        var projects = await query
            .OrderBy(p => p.SortOrder).ThenByDescending(p => p.Year).ThenBy(p => p.Id)
            .ToListAsync(ct);

        return projects.Select(p => ProjectMapper.ToDto(p)).ToList();
    }

    public async Task<ProjectDto?> GetVisibleProjectAsync(string slug, CancellationToken ct)
    {
        var project = await VisibleProjects().FirstOrDefaultAsync(p => p.Slug == slug, ct);
        return project is null ? null : ProjectMapper.ToDto(project);
    }

    private IQueryable<Project> VisibleProjects() =>
        db.Projects
            .AsNoTracking()
            .AsSplitQuery()
            .Include(p => p.Category)
            .Include(p => p.Images)
            .Include(p => p.Results)
            .Include(p => p.SupportAreas)
            .Where(p => p.IsVisible);
}
