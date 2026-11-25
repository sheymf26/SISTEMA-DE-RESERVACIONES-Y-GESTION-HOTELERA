namespace Hotel.LogicaNegocio.Seguridad;

//Implementado en AccesoDatos (procedimientos seg.* y consultas EF)
public interface IRepositorioSeguridad
{
    // Login y sesión
    Task<UsuarioLogin?> ObtenerUsuarioLoginAsync(string login, CancellationToken ct);
    Task<UsuarioLogin?> ObtenerUsuarioPorIdAsync(int idUsuario, CancellationToken ct);
    Task<ResultadoIntento> RegistrarIntentoAsync(string login, bool exitoso, string origen, string? ip, string? dispositivo, CancellationToken ct);
    Task<IReadOnlyList<PermisoModulo>> ObtenerPermisosAsync(int idUsuario, CancellationToken ct);
    Task<DateTime> GuardarRefreshTokenAsync(int idUsuario, byte[] tokenHash, string? ip, string? dispositivo, CancellationToken ct);
    Task<TokenRotado> RotarRefreshTokenAsync(byte[] hashActual, byte[] hashNuevo, string? ip, CancellationToken ct);
    Task CerrarSesionAsync(int idUsuario, CancellationToken ct);
    Task<EstadoSesion?> ObtenerEstadoSesionAsync(int idUsuario, CancellationToken ct);
    Task<decimal?> ObtenerParametroAsync(string clave, CancellationToken ct);

    // Contraseña
    Task<string?> ObtenerPasswordHashAsync(int idUsuario, CancellationToken ct);
    Task ActualizarPasswordAsync(int idUsuario, string passwordHash, bool debeCambiar, CancellationToken ct);

    // Altas
    Task<int> RegistrarClienteAsync(DatosPersona persona, string nombreUsuario, string passwordHash, CancellationToken ct);
    Task<bool> ExisteAdministradorAsync(CancellationToken ct);
    Task<int> InicializarAdministradorAsync(DatosPersona persona, DatosEmpleado empleado, string nombreUsuario, string passwordHash, CancellationToken ct);
    Task<int> CrearUsuarioAsync(int idPersona, string nombreUsuario, string passwordHash, string codigoRol, int idUsuarioAdmin, CancellationToken ct);

    // Administración
    Task<bool> ExisteRolAsync(string codigoRol, CancellationToken ct);
    Task AsignarRolAsync(int idUsuarioAdmin, int idUsuario, string codigoRol, CancellationToken ct);
    Task QuitarRolAsync(int idUsuarioAdmin, int idUsuario, string codigoRol, CancellationToken ct);
    Task<bool> CambiarEstadoUsuarioAsync(int idUsuario, bool activo, CancellationToken ct);
    Task<List<UsuarioResumen>> ListarUsuariosAsync(CancellationToken ct);
    Task<List<RolResumen>> ListarRolesAsync(CancellationToken ct);
}

//Implementado en la API (ASP.NET Identity PasswordHasher: PBKDF2, el formato "AQAAAA..." que acepta CK_Usuario_Hash)
public interface IHasherPassword
{
    string Hashear(string password);
    bool Verificar(string passwordHash, string password);
}

//Implementado en la API (JWT firmado + refresh token aleatorio)
public interface IGeneradorTokens
{
    TokenAcceso GenerarAcceso(UsuarioLogin usuario);
    TokenRefresh GenerarRefresh();
    byte[] HashRefresh(string refreshToken);
}
