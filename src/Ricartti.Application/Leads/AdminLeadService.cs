using Ricartti.Application.Common;
using Ricartti.Domain.Leads;

namespace Ricartti.Application.Leads;

public sealed record ClientLeadDto(
    long Id, string Name, string Company, string Email, string? Phone, string Interest,
    string Message, string Lang, string Status, DateTimeOffset CreatedAt);

public sealed record TalentApplicationDto(
    long Id, string Name, string Email, string Area, string? Link, bool HasCv, string? CvFileName,
    int? CvSizeBytes, string? Message, string Lang, string Status, DateTimeOffset CreatedAt);

/// <summary>CV listo para descargar. El nombre es solo para mostrarlo al guardar el archivo.</summary>
public sealed record CvDownload(Stream Content, string FileName);

/// <summary>Bandejas del panel: lectura de los formularios y descarga de CV.</summary>
public sealed class AdminLeadService(ILeadRepository repository, IPrivateFileStorage files)
{
    /// <summary>Máximo de filas por bandeja. Las más recientes primero.</summary>
    public const int MaxRows = 200;

    public async Task<IReadOnlyList<ClientLeadDto>> ListClientLeadsAsync(CancellationToken ct) =>
        (await repository.ListClientLeadsAsync(MaxRows, ct))
        .Select(l => new ClientLeadDto(l.Id, l.FullName, l.Company, l.Email, l.Phone, l.Interest,
            l.Message, l.Lang, l.Status, l.CreatedAt))
        .ToList();

    public async Task<IReadOnlyList<TalentApplicationDto>> ListTalentApplicationsAsync(CancellationToken ct) =>
        (await repository.ListTalentApplicationsAsync(MaxRows, ct))
        .Select(a => new TalentApplicationDto(a.Id, a.FullName, a.Email, a.Area, a.ProfileUrl,
            a.CvStorageKey is not null, a.CvOriginalName, a.CvSizeBytes, a.Message, a.Lang, a.Status, a.CreatedAt))
        .ToList();

    /// <summary>404 si la postulación no existe, no tiene CV o el archivo ya no está en disco.</summary>
    public async Task<Result<CvDownload>> OpenCvAsync(long id, CancellationToken ct)
    {
        var application = await repository.GetTalentApplicationAsync(id, ct);
        if (application?.CvStorageKey is not { } key)
        {
            return Error.NotFound();
        }

        var stream = files.OpenRead(key);
        if (stream is null)
        {
            return Error.NotFound();
        }

        return new CvDownload(stream, application.CvOriginalName ?? $"cv-{id}.pdf");
    }
}
