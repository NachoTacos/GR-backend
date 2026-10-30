namespace Ricartti.Domain.Portfolio;

/// <summary>Cifra del detalle. Value es texto de presentación ("+38%", "$84 M").</summary>
public class ProjectResult
{
    public long Id { get; set; }
    public long ProjectId { get; set; }
    public string Value { get; set; } = "";
    public string LabelEs { get; set; } = "";
    public string? LabelEn { get; set; }
    public int SortOrder { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    public Project Project { get; set; } = null!;
}
