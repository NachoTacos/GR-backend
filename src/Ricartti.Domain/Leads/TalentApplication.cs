using System.Net;

namespace Ricartti.Domain.Leads;

/// <summary>Formulario "Quiero trabajar en Grupo Ricartti". El CV vive en almacenamiento privado.</summary>
public class TalentApplication
{
    public long Id { get; set; }
    public string FullName { get; set; } = "";
    public string Email { get; set; } = "";
    public string Area { get; set; } = "";
    public string? ProfileUrl { get; set; }

    /// <summary>Ruta relativa en el almacenamiento privado ("cv/&lt;guid&gt;.pdf"). Nunca se sirve públicamente.</summary>
    public string? CvStorageKey { get; set; }
    public string? CvOriginalName { get; set; }
    public int? CvSizeBytes { get; set; }

    public string? Message { get; set; }
    public string Lang { get; set; } = "es";
    public DateTimeOffset PrivacyAcceptedAt { get; set; }
    public string Status { get; set; } = LeadValues.StatusNew;
    public IPAddress? IpAddress { get; set; }
    public string? UserAgent { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }
}
