using System.Net;

namespace Ricartti.Application.Leads;

/// <summary>
/// Cuerpo de POST /api/leads/client (handoff §9). Todo es opcional a nivel de
/// tipo para que la validación devuelva los códigos del contrato (required,
/// email, consent…) en lugar de un 400 genérico. Website es el honeypot.
/// </summary>
public sealed record ClientLeadInput(
    string? Name,
    string? Company,
    string? Email,
    string? Phone,
    string? Interest,
    string? Message,
    bool? Consent,
    string? Website,
    string? Lang);

/// <summary>Campos de POST /api/leads/talent (multipart). Link es el campo "LinkedIn o portafolio".</summary>
public sealed record TalentLeadInput(
    string? Name,
    string? Email,
    string? Area,
    string? Link,
    string? Message,
    bool? Consent,
    string? Website,
    string? Lang);

/// <summary>CV recibido. El flujo es de solo lectura y no se asume que sea seekable.</summary>
public sealed record CvUpload(Stream Content, long Length, string FileName, string? ContentType);

/// <summary>Datos de la petición que se guardan para trazabilidad ante abuso.</summary>
public sealed record LeadRequestContext(IPAddress? Ip, string? UserAgent);

public sealed record LeadReceipt(long Id);

public sealed record LeadOptions(long CvMaxBytes);
