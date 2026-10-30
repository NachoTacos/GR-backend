using System.IO;
using Microsoft.AspNetCore.Http.Features;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Ricartti.Api.Infrastructure;
using Ricartti.Application;
using Ricartti.Application.Common;
using Ricartti.Application.Leads;

namespace Ricartti.Api.Controllers;

/// <summary>
/// Formularios públicos (handoff §9). Respuestas: 201 { id }, 422 { errors },
/// 413 (CV demasiado grande) y 429 (límite de peticiones, política "forms").
/// </summary>
[ApiController]
[Route("api/leads")]
[EnableRateLimiting(RateLimitPolicies.Forms)]
public sealed class LeadsController(LeadService leads) : ControllerBase
{
    /// <summary>Cuerpo máximo de la parte multipart: el CV (5 MB) más los campos de texto.</summary>
    private const long TalentRequestLimit = DependencyInjection.CvMaxBytes + 512 * 1024;

    [HttpPost("client")]
    [RequestSizeLimit(64 * 1024)]
    public async Task<IActionResult> Client([FromBody] ClientLeadInput input, CancellationToken ct) =>
        ToCreated(await leads.SubmitClientAsync(input, RequestContext(), ct));

    [HttpPost("talent")]
    [Consumes("multipart/form-data")]
    [DisableFormValueBinding]
    [RequestSizeLimit(TalentRequestLimit)]
    [RequestFormLimits(MultipartBodyLengthLimit = TalentRequestLimit)]
    public async Task<IActionResult> Talent(CancellationToken ct)
    {
        IFormCollection form;
        try
        {
            form = await Request.ReadFormAsync(ct);
        }
        catch (Exception ex) when (ex is BadHttpRequestException { StatusCode: StatusCodes.Status413PayloadTooLarge }
                                       or InvalidDataException)
        {
            return Error.PayloadTooLarge("cv", "file_size").ToActionResult(this);
        }

        var input = new TalentLeadInput(
            Name: form["name"],
            Email: form["email"],
            Area: form["area"],
            Link: form["link"],
            Message: form["message"],
            Consent: ParseConsent(form["consent"]),
            Website: form["website"],
            Lang: form["lang"]);

        var file = form.Files.GetFile("cv");
        if (file is null || file.Length == 0 && string.IsNullOrEmpty(file.FileName))
        {
            return ToCreated(await leads.SubmitTalentAsync(input, null, RequestContext(), ct));
        }

        await using var stream = file.OpenReadStream();
        var cv = new CvUpload(stream, file.Length, file.FileName, file.ContentType);
        return ToCreated(await leads.SubmitTalentAsync(input, cv, RequestContext(), ct));
    }

    private IActionResult ToCreated(Result<LeadReceipt> result) =>
        result.IsSuccess
            ? StatusCode(StatusCodes.Status201Created, new { id = result.Value!.Id })
            : result.Error!.ToActionResult(this);

    private LeadRequestContext RequestContext()
    {
        var ip = HttpContext.Connection.RemoteIpAddress;
        if (ip is { IsIPv4MappedToIPv6: true })
        {
            ip = ip.MapToIPv4();
        }
        return new LeadRequestContext(ip, Request.Headers.UserAgent.ToString());
    }

    /// <summary>En multipart el checkbox llega como texto: solo "true" (o "on") cuenta como aceptado.</summary>
    private static bool? ParseConsent(string? raw) =>
        string.IsNullOrWhiteSpace(raw)
            ? null
            : raw.Trim().Equals("true", StringComparison.OrdinalIgnoreCase) ||
              raw.Trim().Equals("on", StringComparison.OrdinalIgnoreCase);
}
