using System.Text.Json.Serialization;
using Ricartti.Application.Common;

namespace Ricartti.Application.Portfolio;

// Formas del contrato del handoff (§9). Se serializan en camelCase.

/// <summary>Category del contrato. Id es el slug. Count es una extensión para los chips del filtro.</summary>
public sealed record CategoryDto(string Id, Localized Name, int Order, int Count);

public sealed record EvidenceDto(string Src, Localized Caption);

public sealed record ResultDto(string Value, Localized Label);

public sealed record ProjectDto(
    long Id,
    string Slug,
    string Category,
    string Stage,
    int Year,
    string Name,
    bool Visible,
    Localized Summary,
    Localized Description,
    string Cover,
    IReadOnlyList<EvidenceDto> Evidence,
    IReadOnlyList<ResultDto> Results,
    IReadOnlyList<string> Support,
    DateTimeOffset UpdatedAt,
    [property: JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)] uint? Version = null);
