using System.Net;

namespace Ricartti.Domain.Security;

/// <summary>Administrador del panel. Todos tienen los mismos permisos.</summary>
public class Admin
{
    public long Id { get; set; }
    public string Email { get; set; } = "";
    public string FullName { get; set; } = "";
    public string PasswordHash { get; set; } = "";
    public bool IsActive { get; set; } = true;
    public short FailedLoginCount { get; set; }
    public DateTimeOffset? LockoutUntil { get; set; }
    public DateTimeOffset? LastLoginAt { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}

/// <summary>Sesión de servidor. Solo se guarda el SHA-256 del token, nunca el token.</summary>
public class AdminSession
{
    public long Id { get; set; }
    public long AdminId { get; set; }
    public byte[] TokenHash { get; set; } = [];
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset LastSeenAt { get; set; }

    /// <summary>Expiración deslizante (inactividad).</summary>
    public DateTimeOffset ExpiresAt { get; set; }

    /// <summary>Límite máximo de vida de la sesión.</summary>
    public DateTimeOffset AbsoluteExpiresAt { get; set; }
    public DateTimeOffset? RevokedAt { get; set; }
    public IPAddress? IpAddress { get; set; }
    public string? UserAgent { get; set; }

    public Admin Admin { get; set; } = null!;
}
