using Ricartti.Domain.Security;

namespace Ricartti.Application.Auth;

public sealed record LoginInput(string? Email, string? Password);

/// <summary>Token en claro: solo existe aquí y en la cookie. En la BD solo queda su hash.</summary>
public sealed record LoginResult(string Token, DateTimeOffset AbsoluteExpiresAt);

/// <summary>Administrador autenticado en la petición actual.</summary>
public sealed record AdminIdentity(long AdminId, string Email, string FullName, long SessionId);

public sealed record AuthOptions(int IdleMinutes, int AbsoluteHours, int MaxFailedAttempts, int LockoutMinutes);

public interface IPasswordHasher
{
    bool Verify(string password, string hash);

    /// <summary>Gasta el mismo tiempo que una verificación real, para que el tiempo de respuesta no revele qué correos existen.</summary>
    void VerifyDecoy(string password);
}

public interface IAuthRepository
{
    Task<Admin?> FindAdminByEmailAsync(string email, CancellationToken ct);
    Task AddSessionAsync(AdminSession session, CancellationToken ct);

    /// <summary>Sesión vigente (no revocada, no expirada) de un administrador activo. Entidad con seguimiento.</summary>
    Task<AdminSession?> FindActiveSessionAsync(byte[] tokenHash, DateTimeOffset now, CancellationToken ct);

    Task<AdminSession?> FindSessionAsync(byte[] tokenHash, CancellationToken ct);
    Task SaveChangesAsync(CancellationToken ct);
}
