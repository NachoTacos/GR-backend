namespace Ricartti.Api.Infrastructure;

/// <summary>
/// Cabeceras de seguridad en todas las respuestas de la API. La CSP del sitio
/// (HTML) la añade Nginx; aquí la API solo sirve JSON e imágenes, así que su
/// CSP es la más restrictiva posible.
/// </summary>
public sealed class SecurityHeadersMiddleware(RequestDelegate next)
{
    public Task InvokeAsync(HttpContext context)
    {
        context.Response.OnStarting(() =>
        {
            var headers = context.Response.Headers;
            headers["X-Content-Type-Options"] = "nosniff";
            headers["X-Frame-Options"] = "DENY";
            headers["Referrer-Policy"] = "strict-origin-when-cross-origin";
            headers["Permissions-Policy"] = "camera=(), microphone=(), geolocation=()";
            headers["Content-Security-Policy"] = "default-src 'none'; frame-ancestors 'none'";
            headers["Cross-Origin-Resource-Policy"] = "same-origin";
            headers.Remove("Server");
            return Task.CompletedTask;
        });
        return next(context);
    }
}
