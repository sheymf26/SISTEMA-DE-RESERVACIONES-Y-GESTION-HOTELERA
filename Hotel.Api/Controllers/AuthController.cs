using System.Security.Cryptography;
using System.Text;
using Hotel.LogicaNegocio.Abstracciones;
using Hotel.LogicaNegocio.Errores;
using Hotel.LogicaNegocio.Seguridad;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.ModelBinding;

namespace Hotel.Api.Controllers;

//Respuesta de login/refrescar. RefreshToken solo viene en el cuerpo para la APP; la WEB lo recibe en una cookie HttpOnly
public sealed record RespuestaSesion(
    string AccessToken, DateTime ExpiraEn, string? RefreshToken, DateTime RefreshExpiraEn, UsuarioSesion Usuario);

[ApiController]
[Route("api/auth")]
public sealed class AuthController(
    ServicioAutenticacion autenticacion,
    IUsuarioActual usuarioActual,
    IConfiguration configuracion) : ControllerBase
{
    private const string CookieRefresh = "hotel_refresh";
    private const string RutaCookie = "/api/auth";

    private string? Ip => HttpContext.Connection.RemoteIpAddress?.ToString();
    private int IdUsuario => usuarioActual.IdUsuario
                             ?? throw new ExcepcionNegocio(TipoError.NoAutorizado, "Debe iniciar sesión.");

    [AllowAnonymous]
    [HttpPost("login")]
    public async Task<ActionResult<RespuestaSesion>> Login(SolicitudLogin solicitud, CancellationToken ct)
    {
        var sesion = await autenticacion.IniciarSesionAsync(solicitud, Ip, ct);
        return Responder(sesion, refreshEnCuerpo: solicitud.Origen == Origenes.App);
    }

    //La web no manda cuerpo (usa la cookie); la app manda { "refreshToken": "..." }
    [AllowAnonymous]
    [HttpPost("refrescar")]
    public async Task<ActionResult<RespuestaSesion>> Refrescar(
        [FromBody(EmptyBodyBehavior = EmptyBodyBehavior.Allow)] SolicitudRefresco? solicitud, CancellationToken ct)
    {
        var enCuerpo = !string.IsNullOrWhiteSpace(solicitud?.RefreshToken);
        var token = enCuerpo ? solicitud!.RefreshToken : Request.Cookies[CookieRefresh];
        if (string.IsNullOrWhiteSpace(token))
            throw new ExcepcionNegocio(TipoError.NoAutorizado, "No hay una sesión que renovar.");

        var sesion = await autenticacion.RefrescarAsync(token, Ip, ct);
        return Responder(sesion, refreshEnCuerpo: enCuerpo);
    }

    //Revoca todos los refresh tokens del usuario (todas sus sesiones)
    [HttpPost("cerrar-sesion")]
    public async Task<IActionResult> CerrarSesion(CancellationToken ct)
    {
        await autenticacion.CerrarSesionAsync(IdUsuario, ct);
        BorrarCookie();
        return NoContent();
    }

    [HttpGet("yo")]
    public Task<UsuarioSesion> Yo(CancellationToken ct) => autenticacion.ObtenerUsuarioAsync(IdUsuario, ct);

    //Después del cambio todas las sesiones quedan revocadas: el front debe pedir login de nuevo
    [HttpPost("cambiar-password")]
    public async Task<IActionResult> CambiarPassword(SolicitudCambioPassword solicitud, CancellationToken ct)
    {
        await autenticacion.CambiarPasswordAsync(IdUsuario, solicitud, ct);
        BorrarCookie();
        return NoContent();
    }

    //Autorregistro de clientes desde la app; después se hace login con origen APP
    [AllowAnonymous]
    [HttpPost("registro")]
    public async Task<IActionResult> Registro(SolicitudRegistroCliente solicitud, CancellationToken ct)
    {
        var idCliente = await autenticacion.RegistrarClienteAsync(solicitud, ct);
        return StatusCode(StatusCodes.Status201Created, new { idCliente });
    }

    //Arranque del sistema: crea el primer administrador. Exige Inicializacion:Clave (user secrets);
    //sin esa configuración el endpoint no existe
    [AllowAnonymous]
    [HttpPost("inicializar")]
    public async Task<IActionResult> Inicializar(SolicitudInicializacion solicitud, CancellationToken ct)
    {
        var clave = configuracion["Inicializacion:Clave"];
        if (string.IsNullOrWhiteSpace(clave)) return NotFound();
        if (!CryptographicOperations.FixedTimeEquals(Encoding.UTF8.GetBytes(clave), Encoding.UTF8.GetBytes(solicitud.Clave)))
            throw new ExcepcionNegocio(TipoError.Prohibido, "La clave de inicialización no es correcta.");

        var idUsuario = await autenticacion.InicializarAsync(solicitud, ct);
        return StatusCode(StatusCodes.Status201Created, new { idUsuario });
    }

    private RespuestaSesion Responder(ResultadoSesion sesion, bool refreshEnCuerpo)
    {
        if (!refreshEnCuerpo)
            Response.Cookies.Append(CookieRefresh, sesion.RefreshToken, OpcionesCookie(
                new DateTimeOffset(DateTime.SpecifyKind(sesion.RefreshExpira, DateTimeKind.Local))));

        return new RespuestaSesion(sesion.AccessToken, sesion.AccessExpira,
            refreshEnCuerpo ? sesion.RefreshToken : null, sesion.RefreshExpira, sesion.Usuario);
    }

    private void BorrarCookie() => Response.Cookies.Delete(CookieRefresh, OpcionesCookie(null));

    //HttpOnly: el JavaScript del front no puede leerla. Path /api/auth: solo viaja a estos endpoints
    private static CookieOptions OpcionesCookie(DateTimeOffset? expira) => new()
    {
        HttpOnly = true,
        Secure = true,
        SameSite = SameSiteMode.Strict,
        Path = RutaCookie,
        Expires = expira
    };
}
