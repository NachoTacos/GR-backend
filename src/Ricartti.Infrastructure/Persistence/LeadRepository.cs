using Microsoft.EntityFrameworkCore;
using Ricartti.Application.Leads;
using Ricartti.Domain.Leads;

namespace Ricartti.Infrastructure.Persistence;

public sealed class LeadRepository(RicarttiDbContext db) : ILeadRepository
{
    public async Task<long> AddClientLeadAsync(ClientLead lead, CancellationToken ct)
    {
        db.ClientLeads.Add(lead);
        await db.SaveChangesAsync(ct);
        return lead.Id;
    }

    public async Task<long> AddTalentApplicationAsync(TalentApplication application, CancellationToken ct)
    {
        db.TalentApplications.Add(application);
        await db.SaveChangesAsync(ct);
        return application.Id;
    }

    public async Task<IReadOnlyList<ClientLead>> ListClientLeadsAsync(int max, CancellationToken ct) =>
        await db.ClientLeads.AsNoTracking()
            .OrderByDescending(l => l.CreatedAt).ThenByDescending(l => l.Id)
            .Take(max).ToListAsync(ct);

    public async Task<IReadOnlyList<TalentApplication>> ListTalentApplicationsAsync(int max, CancellationToken ct) =>
        await db.TalentApplications.AsNoTracking()
            .OrderByDescending(a => a.CreatedAt).ThenByDescending(a => a.Id)
            .Take(max).ToListAsync(ct);

    public Task<TalentApplication?> GetTalentApplicationAsync(long id, CancellationToken ct) =>
        db.TalentApplications.AsNoTracking().FirstOrDefaultAsync(a => a.Id == id, ct);
}
