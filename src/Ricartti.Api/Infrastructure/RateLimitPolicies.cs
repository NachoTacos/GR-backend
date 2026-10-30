namespace Ricartti.Api.Infrastructure;

public static class RateLimitPolicies
{
    /// <summary>Formularios públicos: 5 envíos por IP cada 15 minutos (configurable).</summary>
    public const string Forms = "forms";
}
