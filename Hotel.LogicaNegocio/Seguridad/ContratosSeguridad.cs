using System.ComponentModel.DataAnnotations;

namespace Hotel.LogicaNegocio.Seguridad;

//Formato de entrada; las reglas de fondo (unicidad, roles por ámbito, etc.) las valida la BD
internal static class FormatoSeguridad
{
    public const string NombreUsuario = "^[A-Za-z0-9._-]{4,50}$";
    public const string MensajeNombreUsuario =
        "El nombre de usuario debe tener de 4 a 50 caracteres: letras, números, punto, guion o guion bajo.";
}

//Entrada

public sealed record SolicitudLogin(
    [Required(ErrorMessage = "Indique el usuario o el correo."), StringLength(150)] string Login,
    [Required(ErrorMessage = "Indique la contraseña."), StringLength(128)] string Password,
    [Required, RegularExpression("^(WEB|APP)$", ErrorMessage = "El origen debe ser WEB o APP.")] string Origen,
    [StringLength(100)] string? Dispositivo = null);

//Solo la app envía el refresh token en el cuerpo; la web lo manda en la cookie
public sealed record SolicitudRefresco(string? RefreshToken);

public sealed record DatosPersona(
    [Required, RegularExpression("^(CEDULA|DIMEX|PASAPORTE)$", ErrorMessage = "El tipo de identificación debe ser CEDULA, DIMEX o PASAPORTE.")]
    string TipoIdentificacion,
    [Required(ErrorMessage = "Indique la identificación."), StringLength(30)] string Identificacion,
    [Required(ErrorMessage = "Indique el nombre."), StringLength(60)] string Nombre,
    [Required(ErrorMessage = "Indique los apellidos."), StringLength(100)] string Apellidos,
    [Required(ErrorMessage = "Indique el correo."), EmailAddress(ErrorMessage = "El correo no es válido."), StringLength(150)] string Correo,
    [StringLength(20)] string? Telefono = null);

public sealed record DatosEmpleado(
    [Range(1, int.MaxValue, ErrorMessage = "Indique el puesto.")] int IdPuesto,
    [Required, RegularExpression("^(MENSUAL|POR_HORA)$", ErrorMessage = "El tipo de salario debe ser MENSUAL o POR_HORA.")] string TipoSalario,
    //Invariant: en una PC con cultura es-CR "0.01" no se interpreta bien (la coma es el separador decimal)
    [Range(typeof(decimal), "0.01", "9999999999", ParseLimitsInInvariantCulture = true, ConvertValueInInvariantCulture = true,
           ErrorMessage = "El salario debe ser mayor a cero.")] decimal MontoSalario,
    DateOnly FechaIngreso,
    [StringLength(22)] string? CuentaIBAN = null);

//Autorregistro de un cliente desde la app (Persona + Cliente + Usuario con rol CLIENTE)
public sealed record SolicitudRegistroCliente(
    [Required] DatosPersona Persona,
    [Required, RegularExpression(FormatoSeguridad.NombreUsuario, ErrorMessage = FormatoSeguridad.MensajeNombreUsuario)] string NombreUsuario,
    [Required(ErrorMessage = "Indique la contraseña.")] string Password);

//Arranque: crea el primer empleado con rol ADMIN (solo funciona mientras no exista un administrador)
public sealed record SolicitudInicializacion(
    [Required(ErrorMessage = "Indique la clave de inicialización.")] string Clave,
    [Required] DatosPersona Persona,
    [Required] DatosEmpleado Empleado,
    [Required, RegularExpression(FormatoSeguridad.NombreUsuario, ErrorMessage = FormatoSeguridad.MensajeNombreUsuario)] string NombreUsuario,
    [Required(ErrorMessage = "Indique la contraseña.")] string Password);

//Un administrador crea el usuario de una persona existente; la contraseña es temporal (debe cambiarla al entrar)
public sealed record SolicitudCrearUsuario(
    [Range(1, int.MaxValue, ErrorMessage = "Indique la persona.")] int IdPersona,
    [Required, RegularExpression(FormatoSeguridad.NombreUsuario, ErrorMessage = FormatoSeguridad.MensajeNombreUsuario)] string NombreUsuario,
    [Required(ErrorMessage = "Indique la contraseña temporal.")] string PasswordTemporal,
    [Required(ErrorMessage = "Indique el rol."), StringLength(30)] string CodigoRol);

public sealed record SolicitudCambioPassword(
    [Required(ErrorMessage = "Indique la contraseña actual.")] string PasswordActual,
    [Required(ErrorMessage = "Indique la contraseña nueva.")] string PasswordNueva);

public sealed record SolicitudEstadoUsuario(bool Activo);

//Salida

//Columnas de seg.sp_ObtenerPermisos
public sealed record PermisoModulo(string Modulo, string Nombre, bool PuedeVer, bool PuedeCrear, bool PuedeEditar, bool PuedeAnular);

public sealed record UsuarioSesion(
    int IdUsuario, string NombreUsuario, string Nombre, string Apellidos, string Correo,
    bool DebeCambiarPassword, bool AccesoSistema, bool AccesoApp, IReadOnlyList<PermisoModulo> Permisos);

public sealed record ResultadoSesion(
    string AccessToken, DateTime AccessExpira, string RefreshToken, DateTime RefreshExpira, UsuarioSesion Usuario);

public sealed record UsuarioResumen(
    int IdUsuario, string NombreUsuario, string NombreCompleto, string Correo, bool Activo,
    bool DebeCambiarPassword, DateTime? BloqueadoHasta, DateTime? UltimoAcceso, List<string> Roles);

public sealed record RolResumen(string Codigo, string Nombre, string Ambito, bool Activo, List<PermisoModulo> Permisos);
