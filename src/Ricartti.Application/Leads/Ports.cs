using Ricartti.Domain.Leads;

namespace Ricartti.Application.Leads;

public interface ILeadRepository
{
    Task<long> AddClientLeadAsync(ClientLead lead, CancellationToken ct);
    Task<long> AddTalentApplicationAsync(TalentApplication application, CancellationToken ct);

    // Bandejas del panel
    Task<IReadOnlyList<ClientLead>> ListClientLeadsAsync(int max, CancellationToken ct);
    Task<IReadOnlyList<TalentApplication>> ListTalentApplicationsAsync(int max, CancellationToken ct);
    Task<TalentApplication?> GetTalentApplicationAsync(long id, CancellationToken ct);
}

/// <summary>
/// Almacenamiento PRIVADO (fuera de /uploads). Los archivos no tienen URL
/// pública: solo se leen desde el panel, con sesión.
/// </summary>
public interface IPrivateFileStorage
{
    /// <summary>Guarda el CV con un nombre generado por el servidor y devuelve su clave ("cv/&lt;guid&gt;.pdf").</summary>
    Task<string> SaveCvAsync(Stream content, CancellationToken ct);

    Task DeleteAsync(string key, CancellationToken ct);

    /// <summary>Abre un archivo para descargarlo desde el panel, o devuelve null si no existe.</summary>
    Stream? OpenRead(string key);
}
