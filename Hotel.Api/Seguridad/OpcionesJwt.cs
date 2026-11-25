using System.ComponentModel.DataAnnotations;

namespace Hotel.Api.Seguridad;

//Sección "Jwt" de la configuración. La Clave va en user secrets, nunca en appsettings
public sealed class OpcionesJwt
{
    public const string Seccion = "Jwt";

    [Required] public string Emisor { get; init; } = "";
    [Required] public string Audiencia { get; init; } = "";

    [Required(ErrorMessage = "Falta Jwt:Clave (user secrets).")]
    [MinLength(32, ErrorMessage = "Jwt:Clave debe tener al menos 32 caracteres.")]
    public string Clave { get; init; } = "";

    [Range(1, 120)] public int MinutosVigencia { get; init; } = 15;
}

//Nombres de los claims propios del JWT
public static class ClaimsHotel
{
    public const string Sello = "stamp";      // SecurityStamp de seg.Usuario
    public const string Sistema = "sistema";  // tiene roles de ámbito SISTEMA
    public const string App = "app";          // tiene roles de ámbito APP
}
