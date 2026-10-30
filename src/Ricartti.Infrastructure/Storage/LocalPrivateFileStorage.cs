using System.Text.RegularExpressions;
using Ricartti.Application.Leads;

namespace Ricartti.Infrastructure.Storage;

public sealed record StorageOptions(string PrivateFilesPath, string UploadsPath);

/// <summary>
/// Archivos privados en disco (PRIVATE_FILES_PATH), fuera de /uploads. El nombre
/// lo genera el servidor (GUID): nunca se usa ningún dato del usuario en la ruta.
/// </summary>
public sealed partial class LocalPrivateFileStorage : IPrivateFileStorage
{
    // Misma forma que el CHECK ck_talent_applications_cv_key de la BD.
    [GeneratedRegex(@"^cv/[0-9a-f]{32}\.pdf$")]
    private static partial Regex KeyFormat();

    private readonly string _root;

    public LocalPrivateFileStorage(StorageOptions options)
    {
        _root = Path.GetFullPath(options.PrivateFilesPath);
    }

    public async Task<string> SaveCvAsync(Stream content, CancellationToken ct)
    {
        var key = $"cv/{Guid.NewGuid():N}.pdf";
        var path = Resolve(key);
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);

        // CreateNew: nunca sobrescribe un archivo existente.
        await using var file = new FileStream(path, FileMode.CreateNew, FileAccess.Write, FileShare.None);
        await content.CopyToAsync(file, ct);
        return key;
    }

    public Task DeleteAsync(string key, CancellationToken ct)
    {
        var path = Resolve(key);
        if (File.Exists(path))
        {
            File.Delete(path);
        }
        return Task.CompletedTask;
    }

    public Stream? OpenRead(string key)
    {
        string path;
        try
        {
            path = Resolve(key);
        }
        catch (ArgumentException)
        {
            return null; // Clave con formato inválido: no existe.
        }

        return File.Exists(path)
            ? new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.Read, 4096, FileOptions.Asynchronous | FileOptions.SequentialScan)
            : null;
    }

    /// <summary>Convierte una clave en ruta, rechazando cualquier cosa que no sea "cv/&lt;32 hex&gt;.pdf".</summary>
    private string Resolve(string key)
    {
        if (!KeyFormat().IsMatch(key))
        {
            throw new ArgumentException("Clave de archivo no válida.", nameof(key));
        }

        var path = Path.GetFullPath(Path.Combine(_root, key));
        if (!path.StartsWith(_root + Path.DirectorySeparatorChar, StringComparison.Ordinal))
        {
            throw new ArgumentException("La ruta sale del almacenamiento privado.", nameof(key));
        }
        return path;
    }
}
