namespace Hotel.LogicaNegocio.Seguridad;

//Fila de seg.sp_ObtenerUsuarioLogin (incluye el hash: nunca sale de la API)
public sealed class UsuarioLogin
{
    public int IdUsuario { get; init; }
    public string NombreUsuario { get; init; } = "";
    public string Correo { get; init; } = "";
    public string Nombre { get; init; } = "";
    public string Apellidos { get; init; } = "";
    public string PasswordHash { get; init; } = "";
    public Guid SecurityStamp { get; init; }
    public bool Activo { get; init; }
    public bool DebeCambiarPassword { get; init; }
    public bool Bloqueado { get; init; }
    public DateTime? BloqueadoHasta { get; init; }
    public bool AccesoSistema { get; init; }
    public bool AccesoApp { get; init; }
}

//Fila de seg.sp_RegistrarIntentoLogin
public sealed class ResultadoIntento
{
    public byte? IntentosFallidos { get; init; }
    public DateTime? BloqueadoHasta { get; init; }
    public bool IpBloqueada { get; init; }
}

//Fila de seg.sp_RotarRefreshToken
public sealed class TokenRotado
{
    public int IdUsuario { get; init; }
    public Guid SecurityStamp { get; init; }
    public DateTime FechaExpiracion { get; init; }
}

//Lo que se revisa en cada petición autenticada: si el sello cambió o el usuario se desactivó, el JWT ya no sirve
public sealed record EstadoSesion(Guid SecurityStamp, bool Activo);

public sealed record TokenAcceso(string Token, DateTime Expira);

//El token va al cliente; en la BD solo se guarda su hash SHA-256
public sealed record TokenRefresh(string Token, byte[] Hash);
