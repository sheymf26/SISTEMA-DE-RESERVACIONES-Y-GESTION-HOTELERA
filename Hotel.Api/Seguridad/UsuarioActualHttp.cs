using System.Security.Claims;
using Hotel.LogicaNegocio.Abstracciones;

namespace Hotel.Api.Seguridad;

//Lee el IdUsuario del JWT de la petición (claim "sub"; JwtBearer lo mapea a NameIdentifier)
public sealed class UsuarioActualHttp(IHttpContextAccessor accesor) : IUsuarioActual
{
    public int? IdUsuario
    {
        get
        {
            var usuario = accesor.HttpContext?.User;
            if (usuario?.Identity?.IsAuthenticated != true) return null;
            var valor = usuario.FindFirstValue(ClaimTypes.NameIdentifier) ?? usuario.FindFirstValue("sub");
            return int.TryParse(valor, out var id) ? id : null;
        }
    }
}
