using System.Net;

namespace Ricartti.Domain.Leads;

/// <summary>Valores estables del handoff (§6.11 y §6.12). Los mismos que validan los CHECK de la BD.</summary>
public static class LeadValues
{
    public static readonly IReadOnlyList<string> Interests = ["acquire", "coinvest", "incubate", "services"];
    public static readonly IReadOnlyList<string> Areas = ["engineering", "brand", "legal", "tax", "commercial"];
    public static readonly IReadOnlyList<string> Languages = ["es", "en"];

    public const string StatusNew = "new";
}

/// <summary>Formulario "Soy cliente o inversionista".</summary>
public class ClientLead
{
    public long Id { get; set; }
    public string FullName { get; set; } = "";
    public string Company { get; set; } = "";
    public string Email { get; set; } = "";
    public string? Phone { get; set; }
    public string Interest { get; set; } = "";
    public string Message { get; set; } = "";
    public string Lang { get; set; } = "es";
    public DateTimeOffset PrivacyAcceptedAt { get; set; }
    public string Status { get; set; } = LeadValues.StatusNew;
    public IPAddress? IpAddress { get; set; }
    public string? UserAgent { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}
