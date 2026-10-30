namespace Ricartti.Domain.Portfolio;

public class Project
{
    public long Id { get; set; }
    public short CategoryId { get; set; }
    public string Slug { get; set; } = "";
    public string Name { get; set; } = "";
    public ProjectStage Stage { get; set; }
    public short Year { get; set; }
    public string? SummaryEs { get; set; }
    public string? SummaryEn { get; set; }
    public string? DescriptionEs { get; set; }
    public string? DescriptionEn { get; set; }
    public string? CoverImagePath { get; set; }
    public bool IsVisible { get; set; }
    public int SortOrder { get; set; }
    public long? CreatedBy { get; set; }
    public long? UpdatedBy { get; set; }
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    /// <summary>Token de concurrencia optimista (columna de sistema xmin).</summary>
    public uint Version { get; set; }

    public Category Category { get; set; } = null!;
    public List<ProjectImage> Images { get; set; } = [];
    public List<ProjectResult> Results { get; set; } = [];
    public List<SupportArea> SupportAreas { get; set; } = [];
}
