namespace Ricartti.Domain.Portfolio;

/// <summary>Evidencia en imagen. El pie de foto también es el texto alternativo.</summary>
public class ProjectImage
{
    public long Id { get; set; }
    public long ProjectId { get; set; }
    public string ImagePath { get; set; } = "";
    public string CaptionEs { get; set; } = "";
    public string? CaptionEn { get; set; }
    public int SortOrder { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    public Project Project { get; set; } = null!;
}
