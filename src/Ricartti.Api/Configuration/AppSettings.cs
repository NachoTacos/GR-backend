using System.Net;
using Npgsql;

namespace Ricartti.Api.Configuration;

/// <summary>
/// Configuración leída de variables de entorno (archivo .env en local, o
/// las que inyecta Docker Compose). Se valida al arrancar: si falta algo, la
/// API se detiene con un mensaje claro en lugar de fallar más tarde.
/// </summary>
public sealed class AppSettings
{
    public required string ConnectionString { get; init; }
    public required string UploadsPath { get; init; }
    public required string PrivateFilesPath { get; init; }
    public required long UploadMaxBytes { get; init; }
    public required int ApiPort { get; init; }
    public required int GlobalPermitsPerMinute { get; init; }
    public required int FormsPermits { get; init; }
    public required int FormsWindowSeconds { get; init; }
    public required bool CookieSecure { get; init; }
    public IPAddress? TrustedProxyIp { get; init; }

    /// <summary>Carpeta raíz de GR-backend (donde está .env o Ricartti.sln).</summary>
    public required string RepoRoot { get; init; }

    public static AppSettings Load(string repoRoot)
    {
        var missing = new List<string>();
        var invalid = new List<string>();

        string Required(string key)
        {
            var value = Environment.GetEnvironmentVariable(key);
            if (string.IsNullOrWhiteSpace(value))
            {
                missing.Add(key);
                return "";
            }
            return value.Trim();
        }

        string Optional(string key, string fallback)
        {
            var value = Environment.GetEnvironmentVariable(key);
            return string.IsNullOrWhiteSpace(value) ? fallback : value.Trim();
        }

        int Int(string key, int fallback, int min, int max)
        {
            var raw = Optional(key, fallback.ToString());
            if (int.TryParse(raw, out var value) && value >= min && value <= max)
            {
                return value;
            }
            invalid.Add($"{key} (debe ser un número entre {min} y {max})");
            return fallback;
        }

        var host = Required("DB_HOST");
        var port = Int("DB_PORT", 5432, 1, 65535);
        var database = Required("DB_NAME");
        var user = Required("DB_USER");
        var password = Required("DB_PASSWORD");

        var cookieSecureRaw = Optional("AUTH_COOKIE_SECURE", "true");
        if (!bool.TryParse(cookieSecureRaw, out var cookieSecure))
        {
            invalid.Add("AUTH_COOKIE_SECURE (debe ser true o false)");
            cookieSecure = true;
        }

        IPAddress? trustedProxy = null;
        var proxyRaw = Optional("TRUSTED_PROXY_IP", "");
        if (proxyRaw.Length > 0 && !IPAddress.TryParse(proxyRaw, out trustedProxy))
        {
            invalid.Add("TRUSTED_PROXY_IP (debe ser una dirección IP)");
        }

        var settings = new AppSettings
        {
            ConnectionString = new NpgsqlConnectionStringBuilder
            {
                Host = host,
                Port = port,
                Database = database,
                Username = user,
                Password = password,
            }.ConnectionString,
            UploadsPath = ResolvePath(repoRoot, Optional("UPLOADS_PATH", "uploads")),
            PrivateFilesPath = ResolvePath(repoRoot, Optional("PRIVATE_FILES_PATH", "private")),
            UploadMaxBytes = Int("UPLOAD_MAX_BYTES", 5 * 1024 * 1024, 1024, 50 * 1024 * 1024),
            ApiPort = Int("API_PORT", 5080, 1, 65535),
            GlobalPermitsPerMinute = Int("RATE_LIMIT_GLOBAL_PERMITS_PER_MINUTE", 120, 1, 100_000),
            FormsPermits = Int("RATE_LIMIT_FORMS_PERMITS", 5, 1, 100_000),
            FormsWindowSeconds = Int("RATE_LIMIT_FORMS_WINDOW_SECONDS", 900, 1, 86_400),
            CookieSecure = cookieSecure,
            TrustedProxyIp = trustedProxy,
            RepoRoot = repoRoot,
        };

        if (missing.Count > 0 || invalid.Count > 0)
        {
            var lines = missing.Select(k => $"  - Falta la variable {k} en .env")
                .Concat(invalid.Select(k => $"  - Valor inválido: {k}"));
            throw new ConfigurationException(
                "La configuración no es válida:\n" + string.Join('\n', lines) +
                "\nCopia .env.example como .env en la carpeta GR-backend y completa los valores.");
        }

        return settings;
    }

    /// <summary>Las rutas relativas se resuelven desde la raíz de GR-backend.</summary>
    private static string ResolvePath(string repoRoot, string path) =>
        Path.GetFullPath(Path.IsPathRooted(path) ? path : Path.Combine(repoRoot, path));
}

public sealed class ConfigurationException(string message) : Exception(message);
