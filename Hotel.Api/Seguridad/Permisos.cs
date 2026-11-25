using System.Security.Claims;
using Hotel.LogicaNegocio.Seguridad;
using Microsoft.AspNetCore.Authorization;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.IdentityModel.JsonWebTokens;

namespace Hotel.Api.Seguridad;

//Uso: [Permiso(Modulos.Seguridad, AccionPermiso.Crear)] sobre un controlador o acción
[AttributeUsage(AttributeTargets.Class | AttributeTargets.Method, AllowMultiple = true)]
public sealed class PermisoAttribute(string modulo, AccionPermiso accion) : AuthorizeAttribute, IAuthorizationRequirementData
{
    public IEnumerable<IAuthorizationRequirement> GetRequirements()
    {
        yield return new RequisitoPermiso(modulo, accion);
    }
}

public sealed record RequisitoPermiso(string Modulo, AccionPermiso Accion) : IAuthorizationRequirement;

//Revisa seg.RolModulo (vía seg.sp_ObtenerPermisos). Se cachea por usuario + SecurityStamp:
//asignar o quitar un rol cambia el sello, así que la caché vieja deja de usarse sola
public sealed class ManejadorPermiso(IRepositorioSeguridad repo, IMemoryCache cache) : AuthorizationHandler<RequisitoPermiso>
{
    private static readonly TimeSpan Vigencia = TimeSpan.FromMinutes(5);

    protected override async Task HandleRequirementAsync(AuthorizationHandlerContext contexto, RequisitoPermiso requisito)
    {
        if (!int.TryParse(contexto.User.FindFirstValue(JwtRegisteredClaimNames.Sub), out var idUsuario)) return;
        var sello = contexto.User.FindFirstValue(ClaimsHotel.Sello);

        var permisos = await cache.GetOrCreateAsync($"permisos:{idUsuario}:{sello}", entrada =>
        {
            entrada.AbsoluteExpirationRelativeToNow = Vigencia;
            return repo.ObtenerPermisosAsync(idUsuario, CancellationToken.None);
        }) ?? [];

        var modulo = permisos.FirstOrDefault(p => p.Modulo == requisito.Modulo);
        var permitido = requisito.Accion switch
        {
            AccionPermiso.Ver => modulo?.PuedeVer,
            AccionPermiso.Crear => modulo?.PuedeCrear,
            AccionPermiso.Editar => modulo?.PuedeEditar,
            AccionPermiso.Anular => modulo?.PuedeAnular,
            _ => false
        };
        if (permitido == true) contexto.Succeed(requisito);
    }
}
