using System.Globalization;
using System.Text;
using System.Text.RegularExpressions;

namespace Ricartti.Application.Common;

public static partial class Slugs
{
    /// <summary>Mismo formato que el CHECK de la BD: minúsculas, números y guiones simples.</summary>
    [GeneratedRegex("^[a-z0-9]+(-[a-z0-9]+)*$")]
    private static partial Regex SlugFormat();

    public static bool IsValid(string? value, int maxLength) =>
        !string.IsNullOrEmpty(value) && value.Length <= maxLength && SlugFormat().IsMatch(value);

    /// <summary>"Clínica Lince!" → "clinica-lince". Sin acentos, minúsculas y guiones simples.</summary>
    public static string From(string? text, int maxLength, string fallback)
    {
        var sb = new StringBuilder();
        foreach (var c in (text ?? "").Normalize(NormalizationForm.FormD))
        {
            if (CharUnicodeInfo.GetUnicodeCategory(c) == UnicodeCategory.NonSpacingMark)
            {
                continue;
            }
            var lower = char.ToLowerInvariant(c);
            if (lower is (>= 'a' and <= 'z') or (>= '0' and <= '9'))
            {
                sb.Append(lower);
            }
            else if (sb.Length > 0 && sb[^1] != '-')
            {
                sb.Append('-');
            }
        }

        var slug = sb.ToString().Trim('-');
        if (slug.Length > maxLength)
        {
            slug = slug[..maxLength].Trim('-');
        }
        return slug.Length == 0 ? fallback : slug;
    }
}
