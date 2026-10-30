using Microsoft.EntityFrameworkCore;
using Ricartti.Application.Portfolio.Admin;
using Ricartti.Domain.Portfolio;

namespace Ricartti.Infrastructure.Persistence;

public sealed class AdminProjectRepository(RicarttiDbContext db) : IAdminProjectRepository
{
    public async Task<IReadOnlyList<Project>> ListAllAsync(CancellationToken ct) =>
        await WithChildren(db.Projects.AsNoTracking())
            .OrderBy(p => p.SortOrder).ThenByDescending(p => p.Year).ThenBy(p => p.Id)
            .ToListAsync(ct);

    public Task<Project?> GetAsync(long id, bool tracking, CancellationToken ct)
    {
        var query = tracking ? db.Projects : db.Projects.AsNoTracking();
        return WithChildren(query).FirstOrDefaultAsync(p => p.Id == id, ct);
    }

    public void Add(Project project) => db.Projects.Add(project);

    public void Touch(Project project) =>
        db.Entry(project).Property(p => p.UpdatedBy).IsModified = true;

    public async Task SaveChangesAsync(CancellationToken ct)
    {
        try
        {
            await db.SaveChangesAsync(ct);
        }
        catch (DbUpdateConcurrencyException ex)
        {
            throw new ConcurrencyException(ex);
        }
    }

    public Task<bool> SlugExistsAsync(string slug, long? exceptId, CancellationToken ct) =>
        db.Projects.AnyAsync(p => p.Slug == slug && (exceptId == null || p.Id != exceptId), ct);

    public Task<Category?> FindCategoryAsync(string slug, CancellationToken ct) =>
        db.Categories.FirstOrDefaultAsync(c => c.Slug == slug, ct);

    public async Task<IReadOnlyList<SupportArea>> FindSupportAreasAsync(IReadOnlyCollection<string> codes, CancellationToken ct) =>
        await db.SupportAreas.Where(a => codes.Contains(a.Code)).ToListAsync(ct);

    public async Task<IReadOnlyList<Category>> ListCategoriesAsync(CancellationToken ct) =>
        await db.Categories.AsNoTracking().OrderBy(c => c.SortOrder).ThenBy(c => c.Id).ToListAsync(ct);

    public async Task<IReadOnlyList<SupportArea>> ListSupportAreasAsync(CancellationToken ct) =>
        await db.SupportAreas.AsNoTracking().OrderBy(a => a.SortOrder).ToListAsync(ct);

    private static IQueryable<Project> WithChildren(IQueryable<Project> query) =>
        query.AsSplitQuery()
            .Include(p => p.Category)
            .Include(p => p.Images)
            .Include(p => p.Results)
            .Include(p => p.SupportAreas);
}

/// <summary>Una transacción de base de datos alrededor de varios pasos (fila + archivos).</summary>
public sealed class EfUnitOfWork(RicarttiDbContext db) : IUnitOfWork
{
    public async Task ExecuteAsync(Func<Task> work, CancellationToken ct)
    {
        await using var transaction = await db.Database.BeginTransactionAsync(ct);
        await work();
        await transaction.CommitAsync(ct);
    }
}
