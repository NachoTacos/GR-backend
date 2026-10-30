using Microsoft.EntityFrameworkCore;
using Ricartti.Application.Auth;
using Ricartti.Domain.Security;

namespace Ricartti.Infrastructure.Persistence;

public sealed class AuthRepository(RicarttiDbContext db) : IAuthRepository
{
    public Task<Admin?> FindAdminByEmailAsync(string email, CancellationToken ct) =>
        db.Admins.FirstOrDefaultAsync(a => a.Email == email, ct);

    public async Task AddSessionAsync(AdminSession session, CancellationToken ct)
    {
        db.AdminSessions.Add(session);
        await db.SaveChangesAsync(ct);
    }

    public Task<AdminSession?> FindActiveSessionAsync(byte[] tokenHash, DateTimeOffset now, CancellationToken ct) =>
        db.AdminSessions
            .Include(s => s.Admin)
            .FirstOrDefaultAsync(s =>
                s.TokenHash == tokenHash &&
                s.RevokedAt == null &&
                s.ExpiresAt > now &&
                s.AbsoluteExpiresAt > now &&
                s.Admin.IsActive, ct);

    public Task<AdminSession?> FindSessionAsync(byte[] tokenHash, CancellationToken ct) =>
        db.AdminSessions.FirstOrDefaultAsync(s => s.TokenHash == tokenHash, ct);

    public Task SaveChangesAsync(CancellationToken ct) => db.SaveChangesAsync(ct);
}
