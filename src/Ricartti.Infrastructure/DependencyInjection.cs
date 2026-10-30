using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Ricartti.Application.Leads;
using Ricartti.Application.Portfolio;
using Ricartti.Infrastructure.Persistence;
using Ricartti.Infrastructure.Storage;

namespace Ricartti.Infrastructure;

public static class DependencyInjection
{
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services, string connectionString, StorageOptions storage)
    {
        services.AddDbContext<RicarttiDbContext>(options => options.UseNpgsql(connectionString));
        services.AddScoped<IPortfolioReadRepository, PortfolioReadRepository>();
        services.AddScoped<ILeadRepository, LeadRepository>();

        services.AddSingleton(storage);
        services.AddSingleton<IPrivateFileStorage, LocalPrivateFileStorage>();
        return services;
    }
}
