using System.Buffers.Text;
using System.Security.Cryptography;
using System.Text;
using Ricartti.Application.Common;
using Ricartti.Application.Leads;
using Ricartti.Domain.Security;

namespace Ricartti.Application.Auth;

/// <summary>
/// Sesiones de servidor (no JWT): se pueden revocar al instante al cerrar sesión
/// o desactivar una cuenta. El token viaja en una cookie HttpOnly y en la base de
/// datos solo se guarda su SHA-256.
/// </summary>
public sealed class AuthService(
    IAuthRepository repository,
    IPasswordHasher hasher,
    TimeProvider clock,
    AuthOptions options)
{
    private const int TokenBytes = 32;
    private const int MaxPasswordLength = 128;
    private static readonly TimeSpan TouchInterval = TimeSpan.FromMinutes(1);

    /// <summary>
    /// Cualquier fallo (correo inexistente, contraseña incorrecta, cuenta inactiva
    /// o bloqueada) devuelve el mismo Unauthorized, y la contraseña se verifica
    /// siempre, para no revelar qué cuentas existen ni por el mensaje ni por el tiempo.
    /// </summary>
    public async Task<Result<LoginResult>> LoginAsync(
        LoginInput input, LeadRequestContext context, CancellationToken ct)
    {
        var email = input.Email?.Trim().ToLowerInvariant();
        var password = input.Password ?? "";

        if (string.IsNullOrEmpty(email) || email.Length > 254 || password.Length is 0 or > MaxPasswordLength)
        {
            hasher.VerifyDecoy(password.Length > MaxPasswordLength ? "" : password);
            return Error.Unauthorized();
        }

        var admin = await repository.FindAdminByEmailAsync(email, ct);
        if (admin is null)
        {
            hasher.VerifyDecoy(password);
            return Error.Unauthorized();
        }

        var now = clock.GetUtcNow();
        var passwordMatches = hasher.Verify(password, admin.PasswordHash);

        // Cuenta inactiva o bloqueada: se rechaza sin tocar los contadores.
        if (!admin.IsActive || admin.LockoutUntil > now)
        {
            return Error.Unauthorized();
        }

        if (!passwordMatches)
        {
            admin.FailedLoginCount++;
            if (admin.FailedLoginCount >= options.MaxFailedAttempts)
            {
                admin.LockoutUntil = now.AddMinutes(options.LockoutMinutes);
                admin.FailedLoginCount = 0;
            }
            await repository.SaveChangesAsync(ct);
            return Error.Unauthorized();
        }

        admin.FailedLoginCount = 0;
        admin.LockoutUntil = null;
        admin.LastLoginAt = now;

        // Cada inicio de sesión crea un token nuevo (sin fijación de sesión).
        var token = Base64Url.EncodeToString(RandomNumberGenerator.GetBytes(TokenBytes));
        var absolute = now.AddHours(options.AbsoluteHours);
        await repository.AddSessionAsync(new AdminSession
        {
            AdminId = admin.Id,
            TokenHash = Hash(token),
            CreatedAt = now,
            LastSeenAt = now,
            ExpiresAt = Min(now.AddMinutes(options.IdleMinutes), absolute),
            AbsoluteExpiresAt = absolute,
            IpAddress = context.Ip,
            UserAgent = context.UserAgent is { Length: > 512 } ua ? ua[..512] : context.UserAgent,
        }, ct);

        return new LoginResult(token, absolute);
    }

    /// <summary>
    /// Valida el token de la cookie en cada petición: no revocada, no expirada
    /// (deslizante y absoluta) y administrador activo. Renueva la expiración
    /// deslizante, como máximo una vez por minuto, para no escribir en cada petición.
    /// </summary>
    public async Task<AdminIdentity?> ValidateSessionAsync(string? token, CancellationToken ct)
    {
        if (!LooksLikeToken(token))
        {
            return null;
        }

        var now = clock.GetUtcNow();
        var session = await repository.FindActiveSessionAsync(Hash(token!), now, ct);
        if (session is null)
        {
            return null;
        }

        if (now - session.LastSeenAt > TouchInterval)
        {
            session.LastSeenAt = now;
            session.ExpiresAt = Min(now.AddMinutes(options.IdleMinutes), session.AbsoluteExpiresAt);
            await repository.SaveChangesAsync(ct);
        }

        return new AdminIdentity(session.AdminId, session.Admin.Email, session.Admin.FullName, session.Id);
    }

    public async Task LogoutAsync(string? token, CancellationToken ct)
    {
        if (!LooksLikeToken(token))
        {
            return;
        }

        var session = await repository.FindSessionAsync(Hash(token!), ct);
        if (session is { RevokedAt: null })
        {
            session.RevokedAt = clock.GetUtcNow();
            await repository.SaveChangesAsync(ct);
        }
    }

    // 32 bytes en Base64Url = 43 caracteres. Descarta basura antes de ir a la BD.
    private static bool LooksLikeToken(string? token) =>
        token is { Length: 43 } && Base64Url.IsValid(token);

    private static byte[] Hash(string token) => SHA256.HashData(Encoding.ASCII.GetBytes(token));

    private static DateTimeOffset Min(DateTimeOffset a, DateTimeOffset b) => a <= b ? a : b;
}
