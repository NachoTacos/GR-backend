namespace Ricartti.Domain.Portfolio;

public class Category
{
    public short Id { get; set; }
    public string Slug { get; set; } = "";
    public string NameEs { get; set; } = "";
    public string NameEn { get; set; } = "";
    public short SortOrder { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTimeOffset CreatedAt { get; set; }
    public DateTimeOffset UpdatedAt { get; set; }

    public List<Project> Projects { get; set; } = [];
}
