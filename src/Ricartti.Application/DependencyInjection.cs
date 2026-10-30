using Microsoft.Extensions.DependencyInjection;
using Ricartti.Application.Auth;
using Ricartti.Application.Leads;
using Ricartti.Application.Portfolio;
using Ricartti.Application.Portfolio.Admin;

namespace Ricartti.Application;

public static class DependencyInjection
{
    /// <summary>El CV del formulario de talento pesa como máximo 5 MB (handoff §6.12).</summary>
    public const long CvMaxBytes = 5 * 1024 * 1024;

    public static IServiceCollection AddApplication(
        this IServiceCollection services, long imageMaxBytes, AuthOptions auth)
    {
        services.AddSingleton(TimeProvider.System);
        services.AddSingleton(new LeadOptions(CvMaxBytes));
        services.AddSingleton(new ImageOptions(imageMaxBytes));
        services.AddSingleton(auth);

        services.AddScoped<GalleryService>();
        services.AddScoped<LeadService>();
        services.AddScoped<AuthService>();
        services.AddScoped<AdminProjectService>();
        services.AddScoped<AdminLeadService>();
        return services;
    }
}
