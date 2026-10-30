namespace Ricartti.Application.Common;

/// <summary>Texto bilingüe del contrato: { "es": "...", "en": "..." }.</summary>
public sealed record Localized(string Es, string En)
{
    /// <summary>Si falta el inglés (solo posible en borradores), se usa el español.</summary>
    public static Localized From(string es, string? en) => new(es, en ?? es);
}
