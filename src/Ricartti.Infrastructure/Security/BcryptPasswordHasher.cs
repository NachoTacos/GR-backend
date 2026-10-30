using BCrypt.Net;
using Ricartti.Application.Auth;

namespace Ricartti.Infrastructure.Security;

/// <summary>bcrypt (requisito del proyecto). Los hashes del seed son $2a$ con factor 12.</summary>
public sealed class BcryptPasswordHasher : IPasswordHasher
{
    private const int WorkFactor = 12;

    // Hash falso con el mismo factor de trabajo, para igualar el tiempo cuando no existe la cuenta.
    private static readonly Lazy<string> DecoyHash =
        new(() => BCrypt.Net.BCrypt.HashPassword(Guid.NewGuid().ToString("N"), WorkFactor));

    public bool Verify(string password, string hash)
    {
        try
        {
            return BCrypt.Net.BCrypt.Verify(password, hash);
        }
        catch (SaltParseException)
        {
            return false; // Hash mal formado: nunca coincide.
        }
    }

    public void VerifyDecoy(string password) => _ = Verify(password, DecoyHash.Value);
}
