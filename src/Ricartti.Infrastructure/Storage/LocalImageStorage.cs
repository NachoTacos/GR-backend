using System.Globalization;
using System.Text.RegularExpressions;
using Ricartti.Application.Portfolio.Admin;

namespace Ricartti.Infrastructure.Storage;

/// <summary>
/// Imágenes públicas subidas desde el panel, en UPLOADS_PATH/projects/{id}/. El
/// nombre es un GUID generado aquí: nunca se usa el nombre del archivo del cliente.
/// </summary>
public sealed partial class LocalImageStorage : IPublicImageStorage
{
    // Solo se borran archivos que subió el panel; las imágenes del seed (/uploads/seed) no se tocan.
    [GeneratedRegex(@"^/uploads/projects/\d+/[0-9a-f]{32}\.(jpg|png|webp)$")]
    private static partial Regex ManagedPath();

    private static readonly string[] AllowedExtensions = [".jpg", ".png", ".webp"];

    private readonly string _root;

    public LocalImageStorage(StorageOptions options)
    {
        _root = Path.GetFullPath(options.UploadsPath);
    }

    public async Task<string> SaveProjectImageAsync(long projectId, Stream content, string extension, CancellationToken ct)
    {
        if (!AllowedExtensions.Contains(extension))
        {
            throw new ArgumentException("Extensión de imagen no permitida.", nameof(extension));
        }

        var id = projectId.ToString(CultureInfo.InvariantCulture);
        var name = $"{Guid.NewGuid():N}{extension}";
        var directory = Path.Combine(_root, "projects", id);
        Directory.CreateDirectory(directory);

        // CreateNew: nunca sobrescribe un archivo existente.
        await using var file = new FileStream(Path.Combine(directory, name), FileMode.CreateNew, FileAccess.Write, FileShare.None);
        await content.CopyToAsync(file, ct);
        return $"/uploads/projects/{id}/{name}";
    }

    public Task DeleteAsync(string publicPath, CancellationToken ct)
    {
        if (!ManagedPath().IsMatch(publicPath))
        {
            return Task.CompletedTask;
        }

        var full = Path.GetFullPath(Path.Combine(_root, publicPath["/uploads/".Length..]));
        if (full.StartsWith(_root + Path.DirectorySeparatorChar, StringComparison.Ordinal) && File.Exists(full))
        {
            File.Delete(full);
        }
        return Task.CompletedTask;
    }
}
