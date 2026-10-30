using Ricartti.Domain.Portfolio;

namespace Ricartti.Application.Portfolio.Admin;

// Cuerpo del campo "data" (JSON) de POST/PUT /api/admin/projects. El handoff (§9)
// define el multipart: los campos como JSON en "data", más "cover" y "evidence[]".

public sealed record LocalizedInput(string? Es, string? En);

public sealed record ResultInput(string? Value, LocalizedInput? Label);

/// <summary>
/// Una evidencia del proyecto, en orden. Con Src se conserva una imagen que ya
/// existe; con FileIndex se usa el archivo número N de "evidence[]" (nueva).
/// </summary>
public sealed record EvidenceInput(string? Src, int? FileIndex, LocalizedInput? Caption);

public sealed record ProjectWriteData(
    string? Slug,
    string? Name,
    string? Category,
    string? Stage,
    int? Year,
    LocalizedInput? Summary,
    LocalizedInput? Description,
    List<ResultInput>? Results,
    List<string>? Support,
    List<EvidenceInput>? Evidence,
    uint? Version);

public sealed record VisibilityInput(bool? Visible);

public sealed record ImageUpload(Stream Content, long Length);

public sealed record ProjectUploads(ImageUpload? Cover, IReadOnlyList<ImageUpload> Evidence)
{
    public static ProjectUploads None { get; } = new(null, []);
}

public sealed record ImageOptions(long MaxBytes);

/// <summary>Categoría tal como la ve el panel: incluye las inactivas.</summary>
public sealed record AdminCategoryDto(string Id, Common.Localized Name, int Order, bool Active);

public sealed record SupportAreaDto(string Id, Common.Localized Name);

/// <summary>Otro administrador modificó el proyecto mientras se editaba.</summary>
public sealed class ConcurrencyException(Exception? inner = null)
    : Exception("El registro fue modificado por otra persona.", inner);

public interface IAdminProjectRepository
{
    Task<IReadOnlyList<Project>> ListAllAsync(CancellationToken ct);

    /// <summary>Proyecto con sus hijos. Con tracking=true se puede modificar y guardar.</summary>
    Task<Project?> GetAsync(long id, bool tracking, CancellationToken ct);

    void Add(Project project);

    /// <summary>Fuerza el UPDATE de la fila del proyecto (para renovar xmin) aunque solo cambien los hijos.</summary>
    void Touch(Project project);

    /// <exception cref="ConcurrencyException">Si otra persona modificó el proyecto desde que se cargó.</exception>
    Task SaveChangesAsync(CancellationToken ct);

    Task<bool> SlugExistsAsync(string slug, long? exceptId, CancellationToken ct);
    Task<Category?> FindCategoryAsync(string slug, CancellationToken ct);
    Task<IReadOnlyList<SupportArea>> FindSupportAreasAsync(IReadOnlyCollection<string> codes, CancellationToken ct);
    Task<IReadOnlyList<Category>> ListCategoriesAsync(CancellationToken ct);
    Task<IReadOnlyList<SupportArea>> ListSupportAreasAsync(CancellationToken ct);
}

public interface IUnitOfWork
{
    /// <summary>Ejecuta el trabajo en una transacción: confirma si termina bien y revierte si lanza una excepción.</summary>
    Task ExecuteAsync(Func<Task> work, CancellationToken ct);
}

/// <summary>Imágenes públicas, servidas bajo /uploads. Los nombres los genera el servidor.</summary>
public interface IPublicImageStorage
{
    /// <summary>Guarda en "projects/{id}" y devuelve la ruta pública ("/uploads/projects/1/&lt;guid&gt;.webp").</summary>
    Task<string> SaveProjectImageAsync(long projectId, Stream content, string extension, CancellationToken ct);

    /// <summary>Borra una imagen subida desde el panel. Ignora cualquier ruta que no sea de /uploads/projects (nunca toca las del seed).</summary>
    Task DeleteAsync(string publicPath, CancellationToken ct);
}
