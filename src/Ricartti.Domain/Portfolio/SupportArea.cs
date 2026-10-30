namespace Ricartti.Domain.Portfolio;

/// <summary>Área de respaldo del grupo. El código es el valor estable del contrato.</summary>
public class SupportArea
{
    public string Code { get; set; } = "";
    public string NameEs { get; set; } = "";
    public string NameEn { get; set; } = "";
    public short SortOrder { get; set; }

    public List<Project> Projects { get; set; } = [];
}
