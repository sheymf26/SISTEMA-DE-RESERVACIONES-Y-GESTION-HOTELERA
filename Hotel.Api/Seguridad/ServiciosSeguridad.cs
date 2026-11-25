using System.Security.Claims;
using System.Text;
using Hotel.LogicaNegocio.Abstracciones;
using Hotel.LogicaNegocio.Seguridad;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Options;
using Microsoft.IdentityModel.JsonWebTokens;
using Microsoft.IdentityModel.Tokens;

namespace Hotel.Api.Seguridad;

public static class ServiciosSeguridad
{
    public static IServiceCollection AddSeguridad(this IServiceCollection services, IConfiguration configuracion)
    {
        services.AddOptions<OpcionesJwt>()
            .Bind(configuracion.GetSection(OpcionesJwt.Seccion))
            .ValidateDataAnnotations()
            .ValidateOnStart();

        services.AddHttpContextAccessor();
        services.AddMemoryCache();
        services.AddScoped<IUsuarioActual, UsuarioActualHttp>();
        services.AddSingleton<IHasherPassword, HasherPasswordIdentity>();
        services.AddSingleton<IGeneradorTokens, GeneradorTokensJwt>();
        services.AddScoped<IAuthorizationHandler, ManejadorPermiso>();

        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme).AddJwtBearer();
        services.AddOptions<JwtBearerOptions>(JwtBearerDefaults.AuthenticationScheme)
            .Configure<IOptions<OpcionesJwt>>((opciones, jwt) =>
            {
                opciones.MapInboundClaims = false; // "sub" se queda como "sub"
                opciones.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidIssuer = jwt.Value.Emisor,
                    ValidAudience = jwt.Value.Audiencia,
                    IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwt.Value.Clave)),
                    ValidAlgorithms = [SecurityAlgorithms.HmacSha256],
                    ClockSkew = TimeSpan.FromSeconds(30),
                    NameClaimType = JwtRegisteredClaimNames.Name
                };
                opciones.Events = new JwtBearerEvents { OnTokenValidated = ValidarSelloAsync };
            });

        //Seguro por defecto: todo endpoint exige sesión salvo los marcados con [AllowAnonymous]
        services.AddAuthorizationBuilder()
            .SetFallbackPolicy(new AuthorizationPolicyBuilder().RequireAuthenticatedUser().Build());

        return services;
    }

    //El JWT lleva el SecurityStamp: si cambió (contraseña, roles, robo de refresh token) o el usuario
    //se desactivó, el token se rechaza aunque no haya vencido
    private static async Task ValidarSelloAsync(TokenValidatedContext contexto)
    {
        var principal = contexto.Principal;
        var sello = principal?.FindFirstValue(ClaimsHotel.Sello);
        if (!int.TryParse(principal?.FindFirstValue(JwtRegisteredClaimNames.Sub), out var idUsuario) || sello is null)
        {
            contexto.Fail("Token incompleto.");
            return;
        }

        var repo = contexto.HttpContext.RequestServices.GetRequiredService<IRepositorioSeguridad>();
        var estado = await repo.ObtenerEstadoSesionAsync(idUsuario, contexto.HttpContext.RequestAborted);
        if (estado is not { Activo: true } || !string.Equals(estado.SecurityStamp.ToString(), sello, StringComparison.OrdinalIgnoreCase))
            contexto.Fail("La sesión fue revocada.");
    }
}
