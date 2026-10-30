using Microsoft.AspNetCore.Antiforgery;
using Microsoft.AspNetCore.Mvc;
using Ricartti.Api.Configuration;

namespace Ricartti.Api.Controllers;

[ApiController]
[Route("api/antiforgery")]
public sealed class AntiforgeryController(IAntiforgery antiforgery, AppSettings settings) : ControllerBase
{
    /// <summary>
    /// Emite la cookie legible XSRF-TOKEN. Angular HttpClient la lee y la envía
    /// como cabecera X-XSRF-TOKEN en cada POST/PUT/PATCH/DELETE.
    /// </summary>
    [HttpGet("token")]
    public IActionResult Token()
    {
        var tokens = antiforgery.GetAndStoreTokens(HttpContext);
        Response.Cookies.Append("XSRF-TOKEN", tokens.RequestToken!, new CookieOptions
        {
            HttpOnly = false, // Debe ser legible por el frontend (patrón double-submit).
            SameSite = SameSiteMode.Strict,
            Secure = settings.CookieSecure,
            Path = "/",
        });
        return NoContent();
    }
}
