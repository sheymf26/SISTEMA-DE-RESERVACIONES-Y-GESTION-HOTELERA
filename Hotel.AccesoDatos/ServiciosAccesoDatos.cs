using Hotel.AccesoDatos.Contexto;
using Hotel.AccesoDatos.Procedimientos;
using Hotel.AccesoDatos.Repositorios;
using Hotel.LogicaNegocio.Seguridad;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace Hotel.AccesoDatos;

public static class ServiciosAccesoDatos
{
    public static IServiceCollection AddAccesoDatos(this IServiceCollection services, string cadenaConexion)
    {
        services.AddScoped<SesionUsuarioInterceptor>();
        services.AddDbContext<HotelDbContext>((sp, opciones) => opciones
            .UseSqlServer(cadenaConexion)
            .AddInterceptors(sp.GetRequiredService<SesionUsuarioInterceptor>()));
        services.AddScoped<EjecutorSp>();
        services.AddScoped<IRepositorioSeguridad, RepositorioSeguridad>();
        return services;
    }
}
