using System.Text.RegularExpressions;

namespace Ricartti.Application.Leads;

/// <summary>
/// Validación de campos en el servidor. Cada regla refleja un CHECK de la base
/// de datos (la BD es la última barrera) y produce un código del contrato del
/// handoff: required, email, consent, url, invalid.
/// </summary>
internal sealed partial class FieldValidator
{
    // Mismas expresiones que los CHECK de 01_schema.sql.
    [GeneratedRegex(@"^[^@\s]+@[^@\s]+\.[^@\s]+$")]
    private static partial Regex EmailFormat();

    [GeneratedRegex(@"^\+?[0-9][0-9 ()-]{6,19}$")]
    private static partial Regex PhoneFormat();

    [GeneratedRegex(@"^https?://[^\s/]+\.[^\s/]+(/\S*)?$", RegexOptions.IgnoreCase)]
    private static partial Regex UrlFormat();

    private readonly Dictionary<string, string> _errors = new();

    public bool IsValid => _errors.Count == 0;
    public IReadOnlyDictionary<string, string> Errors => _errors;

    /// <summary>Texto de una línea: recortado, sin caracteres de control.</summary>
    public string? Line(string? raw, string field, bool required, int min, int max)
    {
        var value = raw?.Trim();
        if (string.IsNullOrEmpty(value))
        {
            if (required) Fail(field, "required");
            return null;
        }
        if (value.Length < min || value.Length > max || value.Any(char.IsControl))
        {
            Fail(field, "invalid");
            return null;
        }
        return value;
    }

    /// <summary>Texto multilínea: se permiten saltos de línea y tabuladores, no otros caracteres de control.</summary>
    public string? Text(string? raw, string field, bool required, int max)
    {
        var value = raw?.Trim();
        if (string.IsNullOrEmpty(value))
        {
            if (required) Fail(field, "required");
            return null;
        }
        if (value.Length > max || value.Any(c => char.IsControl(c) && c is not ('\n' or '\r' or '\t')))
        {
            Fail(field, "invalid");
            return null;
        }
        return value;
    }

    /// <summary>Correo normalizado en minúsculas (lo exige el CHECK de la BD).</summary>
    public string? Email(string? raw, string field)
    {
        var value = raw?.Trim();
        if (string.IsNullOrEmpty(value))
        {
            Fail(field, "required");
            return null;
        }
        if (value.Length > 254 || value.Any(char.IsControl) || !EmailFormat().IsMatch(value))
        {
            Fail(field, "email");
            return null;
        }
        return value.ToLowerInvariant();
    }

    public string? Phone(string? raw, string field)
    {
        var value = raw?.Trim();
        if (string.IsNullOrEmpty(value))
        {
            return null;
        }
        if (!PhoneFormat().IsMatch(value))
        {
            Fail(field, "invalid");
            return null;
        }
        return value;
    }

    /// <summary>URL http(s) opcional, de hasta 300 caracteres.</summary>
    public string? Url(string? raw, string field)
    {
        var value = raw?.Trim();
        if (string.IsNullOrEmpty(value))
        {
            return null;
        }
        if (value.Length > 300 || !UrlFormat().IsMatch(value) || !Uri.TryCreate(value, UriKind.Absolute, out _))
        {
            Fail(field, "url");
            return null;
        }
        return value;
    }

    /// <summary>Valor de una lista cerrada (los códigos estables del handoff).</summary>
    public string? OneOf(string? raw, string field, IReadOnlyList<string> allowed)
    {
        var value = raw?.Trim();
        if (string.IsNullOrEmpty(value))
        {
            Fail(field, "required");
            return null;
        }
        if (!allowed.Contains(value))
        {
            Fail(field, "invalid");
            return null;
        }
        return value;
    }

    /// <summary>Idioma opcional ("es" por defecto). Un valor distinto de es/en es un error.</summary>
    public string Lang(string? raw, string field, IReadOnlyList<string> allowed)
    {
        var value = raw?.Trim().ToLowerInvariant();
        if (string.IsNullOrEmpty(value))
        {
            return "es";
        }
        if (!allowed.Contains(value))
        {
            Fail(field, "invalid");
            return "es";
        }
        return value;
    }

    /// <summary>El aviso de privacidad debe aceptarse de forma explícita (consent: true).</summary>
    public void Consent(bool? value, string field)
    {
        if (value is not true)
        {
            Fail(field, "consent");
        }
    }

    public void Fail(string field, string code) => _errors.TryAdd(field, code);
}
