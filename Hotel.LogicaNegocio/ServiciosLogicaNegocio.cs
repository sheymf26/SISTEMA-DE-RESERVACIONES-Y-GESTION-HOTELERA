using Hotel.LogicaNegocio.Seguridad;
using Microsoft.Extensions.DependencyInjection;

namespace Hotel.LogicaNegocio;

public static class ServiciosLogicaNegocio
{
    public static IServiceCollection AddLogicaNegocio(this IServiceCollection services)
    {
        services.AddScoped<ServicioAutenticacion>();
        services.AddScoped<ServicioUsuarios>();
        return services;
    }
}
