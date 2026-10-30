using System.Text;
using Ricartti.Application.Common;
using Ricartti.Domain.Leads;

namespace Ricartti.Application.Leads;

/// <summary>Casos de uso de los dos formularios públicos.</summary>
public sealed class LeadService(
    ILeadRepository repository,
    IPrivateFileStorage files,
    TimeProvider clock,
    LeadOptions options)
{
    private static readonly byte[] PdfSignature = "%PDF-"u8.ToArray();

    public async Task<Result<LeadReceipt>> SubmitClientAsync(
        ClientLeadInput input, LeadRequestContext context, CancellationToken ct)
    {
        // Honeypot: un humano nunca ve este campo. Si llega con contenido, se
        // responde como si todo hubiera ido bien, sin guardar nada ni dar pistas.
        if (!string.IsNullOrWhiteSpace(input.Website))
        {
            return FakeReceipt();
        }

        var v = new FieldValidator();
        var name = v.Line(input.Name, "name", required: true, min: 2, max: 120);
        var company = v.Line(input.Company, "company", required: true, min: 1, max: 120);
        var email = v.Email(input.Email, "email");
        var phone = v.Phone(input.Phone, "phone");
        var interest = v.OneOf(input.Interest, "interest", LeadValues.Interests);
        var message = v.Text(input.Message, "message", required: true, max: 2000);
        var lang = v.Lang(input.Lang, "lang", LeadValues.Languages);
        v.Consent(input.Consent, "consent");

        if (!v.IsValid)
        {
            return Error.Validation(v.Errors);
        }

        var id = await repository.AddClientLeadAsync(new ClientLead
        {
            FullName = name!,
            Company = company!,
            Email = email!,
            Phone = phone,
            Interest = interest!,
            Message = message!,
            Lang = lang,
            PrivacyAcceptedAt = clock.GetUtcNow(),
            IpAddress = context.Ip,
            UserAgent = Truncate(context.UserAgent, 512),
        }, ct);

        return new LeadReceipt(id);
    }

    public async Task<Result<LeadReceipt>> SubmitTalentAsync(
        TalentLeadInput input, CvUpload? cv, LeadRequestContext context, CancellationToken ct)
    {
        if (!string.IsNullOrWhiteSpace(input.Website))
        {
            return FakeReceipt();
        }

        // Un CV demasiado grande es un 413 (handoff §9), antes de validar el resto.
        if (cv is not null && cv.Length > options.CvMaxBytes)
        {
            return Error.PayloadTooLarge("cv", "file_size");
        }

        var v = new FieldValidator();
        var name = v.Line(input.Name, "name", required: true, min: 2, max: 120);
        var email = v.Email(input.Email, "email");
        var area = v.OneOf(input.Area, "area", LeadValues.Areas);
        var link = v.Url(input.Link, "link");
        var message = v.Text(input.Message, "message", required: false, max: 2000);
        var lang = v.Lang(input.Lang, "lang", LeadValues.Languages);
        v.Consent(input.Consent, "consent");

        var cvIsValid = cv is null || await IsPdfAsync(cv, ct);
        if (!cvIsValid)
        {
            v.Fail("cv", "file_type");
        }

        if (!v.IsValid)
        {
            return Error.Validation(v.Errors);
        }

        var application = new TalentApplication
        {
            FullName = name!,
            Email = email!,
            Area = area!,
            ProfileUrl = link,
            Message = message,
            Lang = lang,
            PrivacyAcceptedAt = clock.GetUtcNow(),
            IpAddress = context.Ip,
            UserAgent = Truncate(context.UserAgent, 512),
        };

        // Primero el archivo, después la fila. Si la inserción falla, se borra el
        // archivo para no dejar CV huérfanos (ARCHITECTURE.md §11).
        string? storedKey = null;
        if (cv is not null)
        {
            storedKey = await files.SaveCvAsync(cv.Content, ct);
            application.CvStorageKey = storedKey;
            application.CvOriginalName = SanitizeFileName(cv.FileName);
            application.CvSizeBytes = checked((int)cv.Length);
        }

        try
        {
            return new LeadReceipt(await repository.AddTalentApplicationAsync(application, ct));
        }
        catch
        {
            if (storedKey is not null)
            {
                await files.DeleteAsync(storedKey, CancellationToken.None);
            }
            throw;
        }
    }

    /// <summary>
    /// Valida tipo, extensión y firma binaria. No basta con confiar en la
    /// extensión ni en el Content-Type: el archivo debe empezar con "%PDF-".
    /// </summary>
    private static async Task<bool> IsPdfAsync(CvUpload cv, CancellationToken ct)
    {
        if (cv.Length <= 0 ||
            !cv.FileName.EndsWith(".pdf", StringComparison.OrdinalIgnoreCase) ||
            !string.Equals(cv.ContentType, "application/pdf", StringComparison.OrdinalIgnoreCase))
        {
            return false;
        }

        var header = new byte[PdfSignature.Length];
        var read = 0;
        while (read < header.Length)
        {
            var n = await cv.Content.ReadAsync(header.AsMemory(read), ct);
            if (n == 0) break;
            read += n;
        }

        if (read != header.Length || !header.AsSpan().SequenceEqual(PdfSignature))
        {
            return false;
        }

        if (!cv.Content.CanSeek)
        {
            throw new InvalidOperationException("El flujo del CV debe poder reposicionarse.");
        }
        cv.Content.Position = 0;
        return true;
    }

    /// <summary>El nombre original solo se muestra en el panel: sin rutas ni caracteres peligrosos.</summary>
    internal static string SanitizeFileName(string? name)
    {
        var leaf = Path.GetFileName((name ?? "").Replace('\\', '/'));
        var sb = new StringBuilder(leaf.Length);
        foreach (var c in leaf)
        {
            if (!char.IsControl(c) && "<>:\"/\\|?*".IndexOf(c) < 0)
            {
                sb.Append(c);
            }
        }
        var clean = sb.ToString().Trim();
        if (clean.Length > 255)
        {
            clean = clean[^255..];
        }
        return clean.Length == 0 ? "cv.pdf" : clean;
    }

    private static string? Truncate(string? value, int max) =>
        value is null ? null : value.Length <= max ? value : value[..max];

    private static LeadReceipt FakeReceipt() => new(Random.Shared.NextInt64(1_000, 100_000));
}
