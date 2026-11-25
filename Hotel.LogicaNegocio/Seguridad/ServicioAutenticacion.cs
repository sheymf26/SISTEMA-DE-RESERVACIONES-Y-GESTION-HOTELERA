using Hotel.LogicaNegocio.Errores;
using Microsoft.Extensions.Caching.Memory;

namespace Hotel.LogicaNegocio.Seguridad;

//Login, renovación y cierre de sesión, registro de clientes, cambio de contraseña y arranque del primer ADMIN
public sealed class ServicioAutenticacion(
    IRepositorioSeguridad repo,
    IHasherPassword hasher,
    IGeneradorTokens tokens,
    IMemoryCache cache)
{
    //Hash de relleno para verificar cuando el usuario no existe: la respuesta tarda lo mismo y no revela qué cuentas existen
    private static string? _hashFicticio;
    private string HashFicticio => _hashFicticio ??= hasher.Hashear(Guid.NewGuid().ToString());

    public async Task<ResultadoSesion> IniciarSesionAsync(SolicitudLogin solicitud, string? ip, CancellationToken ct)
    {
        if (ip is not null && cache.TryGetValue(ClaveIp(ip), out _))
            throw new ExcepcionNegocio(TipoError.DemasiadosIntentos,
                "Demasiados intentos fallidos desde esta conexión. Intente de nuevo más tarde.");

        var login = solicitud.Login.Trim();
        var usuario = await repo.ObtenerUsuarioLoginAsync(login, ct);
        if (usuario is { Bloqueado: true })
            throw CuentaBloqueada(usuario.BloqueadoHasta);

        var passwordCorrecta = hasher.Verificar(usuario?.PasswordHash ?? HashFicticio, solicitud.Password);
        var exitoso = usuario is { Activo: true } && passwordCorrecta;

        //Un solo contador para app y web; la BD bloquea la cuenta al llegar a MAX_INTENTOS_LOGIN
        var intento = await repo.RegistrarIntentoAsync(login, exitoso, solicitud.Origen, ip, solicitud.Dispositivo, ct);
        if (intento.IpBloqueada && ip is not null)
        {
            var minutos = await repo.ObtenerParametroAsync("MIN_VENTANA_INTENTOS_IP", ct) ?? 10;
            cache.Set(ClaveIp(ip), true, TimeSpan.FromMinutes((double)minutos));
        }

        if (!exitoso)
        {
            if (intento.BloqueadoHasta > DateTime.Now)
                throw CuentaBloqueada(intento.BloqueadoHasta);
            throw new ExcepcionNegocio(TipoError.NoAutorizado, "Usuario o contraseña incorrectos.");
        }

        //Mismo login para las dos aplicaciones: el origen decide qué ámbito de roles se exige
        var tieneAcceso = solicitud.Origen == Origenes.Web ? usuario!.AccesoSistema : usuario!.AccesoApp;
        if (!tieneAcceso)
            throw new ExcepcionNegocio(TipoError.Prohibido, solicitud.Origen == Origenes.Web
                ? "Su usuario no tiene acceso al sistema de administración."
                : "Su usuario no tiene acceso a la app de clientes.");

        var refresh = tokens.GenerarRefresh();
        var refreshExpira = await repo.GuardarRefreshTokenAsync(usuario.IdUsuario, refresh.Hash, ip, solicitud.Dispositivo, ct);
        return await ArmarSesionAsync(usuario, refresh.Token, refreshExpira, ct);
    }

    //Rotación: el refresh token viejo queda revocado; si alguien reutiliza uno viejo, la BD cierra todas las sesiones
    public async Task<ResultadoSesion> RefrescarAsync(string refreshToken, string? ip, CancellationToken ct)
    {
        var nuevo = tokens.GenerarRefresh();
        var rotado = await repo.RotarRefreshTokenAsync(tokens.HashRefresh(refreshToken), nuevo.Hash, ip, ct);

        var usuario = await repo.ObtenerUsuarioPorIdAsync(rotado.IdUsuario, ct);
        if (usuario is not { Activo: true })
            throw new ExcepcionNegocio(TipoError.NoAutorizado, "Sesión expirada.");

        return await ArmarSesionAsync(usuario, nuevo.Token, rotado.FechaExpiracion, ct);
    }

    public Task CerrarSesionAsync(int idUsuario, CancellationToken ct) => repo.CerrarSesionAsync(idUsuario, ct);

    public async Task<UsuarioSesion> ObtenerUsuarioAsync(int idUsuario, CancellationToken ct)
    {
        var usuario = await repo.ObtenerUsuarioPorIdAsync(idUsuario, ct)
                      ?? throw new ExcepcionNegocio(TipoError.NoEncontrado, "El usuario no existe.");
        return ArmarUsuario(usuario, await repo.ObtenerPermisosAsync(idUsuario, ct));
    }

    //Al cambiar el hash, el trigger de seg.Usuario renueva el SecurityStamp y revoca los refresh tokens:
    //todas las sesiones (incluida la actual) deben iniciar de nuevo
    public async Task CambiarPasswordAsync(int idUsuario, SolicitudCambioPassword solicitud, CancellationToken ct)
    {
        PoliticaPassword.Validar(solicitud.PasswordNueva);
        var hashActual = await repo.ObtenerPasswordHashAsync(idUsuario, ct)
                         ?? throw new ExcepcionNegocio(TipoError.NoEncontrado, "El usuario no existe.");
        if (!hasher.Verificar(hashActual, solicitud.PasswordActual))
            throw new ExcepcionNegocio(TipoError.Validacion, "La contraseña actual no es correcta.");
        if (hasher.Verificar(hashActual, solicitud.PasswordNueva))
            throw new ExcepcionNegocio(TipoError.Validacion, "La contraseña nueva debe ser distinta a la actual.");

        await repo.ActualizarPasswordAsync(idUsuario, hasher.Hashear(solicitud.PasswordNueva), debeCambiar: false, ct);
    }

    public Task<int> RegistrarClienteAsync(SolicitudRegistroCliente solicitud, CancellationToken ct)
    {
        PoliticaPassword.Validar(solicitud.Password);
        return repo.RegistrarClienteAsync(solicitud.Persona, solicitud.NombreUsuario, hasher.Hashear(solicitud.Password), ct);
    }

    //La API ya validó la clave de inicialización; aquí solo se exige que todavía no exista un administrador
    public async Task<int> InicializarAsync(SolicitudInicializacion solicitud, CancellationToken ct)
    {
        if (await repo.ExisteAdministradorAsync(ct))
            throw new ExcepcionNegocio(TipoError.Conflicto, "El sistema ya fue inicializado: ya existe un administrador.");
        PoliticaPassword.Validar(solicitud.Password);
        return await repo.InicializarAdministradorAsync(solicitud.Persona, solicitud.Empleado,
            solicitud.NombreUsuario, hasher.Hashear(solicitud.Password), ct);
    }

    private async Task<ResultadoSesion> ArmarSesionAsync(UsuarioLogin usuario, string refreshToken, DateTime refreshExpira, CancellationToken ct)
    {
        var permisos = await repo.ObtenerPermisosAsync(usuario.IdUsuario, ct);
        var acceso = tokens.GenerarAcceso(usuario);
        return new ResultadoSesion(acceso.Token, acceso.Expira, refreshToken, refreshExpira, ArmarUsuario(usuario, permisos));
    }

    private static UsuarioSesion ArmarUsuario(UsuarioLogin u, IReadOnlyList<PermisoModulo> permisos) =>
        new(u.IdUsuario, u.NombreUsuario, u.Nombre, u.Apellidos, u.Correo,
            u.DebeCambiarPassword, u.AccesoSistema, u.AccesoApp, permisos);

    private static ExcepcionNegocio CuentaBloqueada(DateTime? hasta) =>
        new(TipoError.Bloqueado, hasta is { } h
            ? $"La cuenta está bloqueada por intentos fallidos hasta las {h:HH:mm}."
            : "La cuenta está bloqueada temporalmente por intentos fallidos.");

    private static string ClaveIp(string ip) => $"ip-bloqueada:{ip}";
}
