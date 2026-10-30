using System.Threading.RateLimiting;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.StaticFiles;
using Microsoft.Extensions.FileProviders;
using Ricartti.Api.Configuration;
using Ricartti.Api.Infrastructure;
using Ricartti.Application;
using Ricartti.Infrastructure;
using Ricartti.Infrastructure.Persistence;
using Ricartti.Infrastructure.Storage;

// 1. Configuración: .env (local) o variables de Docker. Se valida antes de arrancar.
var repoRoot = EnvFile.FindRepoRoot();
EnvFile.Load(repoRoot);

AppSettings settings;
try
{
    settings = AppSettings.Load(repoRoot);
}
catch (ConfigurationException ex)
{
    Console.Error.WriteLine();
    Console.Error.WriteLine(ex.Message);
    Console.Error.WriteLine();
    return 1;
}

var builder = WebApplication.CreateBuilder(args);

// En local escucha en API_PORT; en Docker, ASPNETCORE_URLS define el puerto interno.
if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("ASPNETCORE_URLS")))
{
    builder.WebHost.UseUrls($"http://localhost:{settings.ApiPort}");
}

// 2. Servicios por capa.
builder.Services.AddSingleton(settings);
builder.Services.AddApplication();
builder.Services.AddInfrastructure(settings.ConnectionString, new StorageOptions(settings.PrivateFilesPath));

builder.Services.AddControllers();
builder.Services.AddProblemDetails();
builder.Services.AddHealthChecks().AddDbContextCheck<RicarttiDbContext>("database");

builder.Services.AddAntiforgery(options =>
{
    options.HeaderName = "X-XSRF-TOKEN";
    options.Cookie.Name = "ricartti_af";
    options.Cookie.HttpOnly = true;
    options.Cookie.SameSite = SameSiteMode.Strict;
    // ASP.NET rechaza "Always" en peticiones HTTP, y el proyecto corre en
    // http://localhost. SameAsRequest la marca Secure en cuanto haya HTTPS.
    options.Cookie.SecurePolicy = CookieSecurePolicy.SameAsRequest;
});

// Sin cabecera "Server: Kestrel" (no revelar tecnología ni versión).
builder.WebHost.ConfigureKestrel(options => options.AddServerHeader = false);

// IP real detrás de Nginx: solo se confía en X-Forwarded-For si viene del
// contenedor web (IP fija). Sin TRUSTED_PROXY_IP (local), no se confía en nadie.
builder.Services.Configure<ForwardedHeadersOptions>(options =>
{
    options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
    options.KnownIPNetworks.Clear();
    options.KnownProxies.Clear();
    if (settings.TrustedProxyIp is { } proxy)
    {
        options.KnownProxies.Add(proxy);
    }
});

// Límite global de peticiones por IP (los de login y formularios llegan en los lotes 3 y 4).
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.GlobalLimiter = PartitionedRateLimiter.Create<HttpContext, string>(context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = settings.GlobalPermitsPerMinute,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
            }));

    // Formularios públicos: límite estricto por IP, además del global.
    options.AddPolicy(RateLimitPolicies.Forms, context =>
        RateLimitPartition.GetFixedWindowLimiter(
            context.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = settings.FormsPermits,
                Window = TimeSpan.FromSeconds(settings.FormsWindowSeconds),
                QueueLimit = 0,
            }));

    options.OnRejected = (context, _) =>
    {
        if (context.Lease.TryGetMetadata(MetadataName.RetryAfter, out var retryAfter))
        {
            context.HttpContext.Response.Headers.RetryAfter = ((int)retryAfter.TotalSeconds).ToString();
        }
        return ValueTask.CompletedTask;
    };
});

var app = builder.Build();

// 3. Canalización HTTP.
app.UseForwardedHeaders();
app.UseExceptionHandler(); // ProblemDetails, sin stack traces fuera de Development.
app.UseMiddleware<SecurityHeadersMiddleware>();

// Imágenes públicas: solo formatos raster permitidos (nunca SVG ni otros tipos).
Directory.CreateDirectory(settings.UploadsPath);
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(settings.UploadsPath),
    RequestPath = "/uploads",
    ServeUnknownFileTypes = false,
    ContentTypeProvider = new FileExtensionContentTypeProvider(new Dictionary<string, string>
    {
        [".jpg"] = "image/jpeg",
        [".jpeg"] = "image/jpeg",
        [".png"] = "image/png",
        [".webp"] = "image/webp",
    }),
    OnPrepareResponse = ctx => ctx.Context.Response.Headers.CacheControl = "public, max-age=3600",
});

app.UseRateLimiter();

app.MapHealthChecks("/api/health");
app.MapControllers();

app.Logger.LogInformation("Imágenes servidas desde {UploadsPath}", settings.UploadsPath);
app.Run();
return 0;
