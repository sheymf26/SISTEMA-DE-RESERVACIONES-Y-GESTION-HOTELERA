using System.Data;
using Dapper;
using Hotel.AccesoDatos.Contexto;
using Hotel.AccesoDatos.Procedimientos;
using Hotel.LogicaNegocio.Seguridad;
using Microsoft.EntityFrameworkCore;

namespace Hotel.AccesoDatos.Repositorios;

//Las operaciones con reglas van por los procedimientos seg.*; las lecturas simples, con EF
public sealed class RepositorioSeguridad(HotelDbContext db, EjecutorSp sp) : IRepositorioSeguridad
{
    //Login y sesión

    public Task<UsuarioLogin?> ObtenerUsuarioLoginAsync(string login, CancellationToken ct) =>
        sp.ConsultarUnoAsync<UsuarioLogin>("seg.sp_ObtenerUsuarioLogin", new { Login = login }, ct);

    //Se reutiliza sp_ObtenerUsuarioLogin para que AccesoSistema/AccesoApp se calculen en un solo lugar
    public async Task<UsuarioLogin?> ObtenerUsuarioPorIdAsync(int idUsuario, CancellationToken ct)
    {
        var nombreUsuario = await db.Usuario.AsNoTracking()
            .Where(u => u.IdUsuario == idUsuario)
            .Select(u => u.NombreUsuario)
            .FirstOrDefaultAsync(ct);
        return nombreUsuario is null ? null : await ObtenerUsuarioLoginAsync(nombreUsuario, ct);
    }

    public async Task<ResultadoIntento> RegistrarIntentoAsync(string login, bool exitoso, string origen, string? ip,
                                                             string? dispositivo, CancellationToken ct) =>
        await sp.ConsultarUnoAsync<ResultadoIntento>("seg.sp_RegistrarIntentoLogin",
            new { Login = login, Exitoso = exitoso, Origen = origen, Ip = ip, Dispositivo = dispositivo }, ct)
        ?? new ResultadoIntento();

    public Task<IReadOnlyList<PermisoModulo>> ObtenerPermisosAsync(int idUsuario, CancellationToken ct) =>
        sp.ConsultarAsync<PermisoModulo>("seg.sp_ObtenerPermisos", new { IdUsuario = idUsuario }, ct);

    public Task<DateTime> GuardarRefreshTokenAsync(int idUsuario, byte[] tokenHash, string? ip, string? dispositivo,
                                                   CancellationToken ct) =>
        sp.ConsultarUnoAsync<DateTime>("seg.sp_GuardarRefreshToken",
            new { IdUsuario = idUsuario, TokenHash = tokenHash, Ip = ip, Dispositivo = dispositivo }, ct);

    //Token inválido, reutilizado o vencido: el SP lanza 50110-50112 y la API responde 401
    public async Task<TokenRotado> RotarRefreshTokenAsync(byte[] hashActual, byte[] hashNuevo, string? ip, CancellationToken ct) =>
        await sp.ConsultarUnoAsync<TokenRotado>("seg.sp_RotarRefreshToken",
            new { TokenHashActual = hashActual, TokenHashNuevo = hashNuevo, Ip = ip }, ct)
        ?? throw new InvalidOperationException("seg.sp_RotarRefreshToken no devolvió el usuario.");

    public Task CerrarSesionAsync(int idUsuario, CancellationToken ct) =>
        sp.EjecutarAsync("seg.sp_CerrarSesion", new { IdUsuario = idUsuario }, ct);

    public Task<EstadoSesion?> ObtenerEstadoSesionAsync(int idUsuario, CancellationToken ct) =>
        db.Usuario.AsNoTracking()
            .Where(u => u.IdUsuario == idUsuario)
            .Select(u => new EstadoSesion(u.SecurityStamp, u.Activo))
            .FirstOrDefaultAsync(ct);

    public Task<decimal?> ObtenerParametroAsync(string clave, CancellationToken ct) =>
        db.Parametro.AsNoTracking()
            .Where(p => p.Clave == clave)
            .Select(p => (decimal?)p.Valor)
            .FirstOrDefaultAsync(ct);

    //Contraseña

    public Task<string?> ObtenerPasswordHashAsync(int idUsuario, CancellationToken ct) =>
        db.Usuario.AsNoTracking()
            .Where(u => u.IdUsuario == idUsuario && u.Activo)
            .Select(u => u.PasswordHash)
            .FirstOrDefaultAsync(ct);

    public Task ActualizarPasswordAsync(int idUsuario, string passwordHash, bool debeCambiar, CancellationToken ct) =>
        db.Usuario
            .Where(u => u.IdUsuario == idUsuario)
            .ExecuteUpdateAsync(s => s
                .SetProperty(u => u.PasswordHash, passwordHash)
                .SetProperty(u => u.DebeCambiarPassword, debeCambiar), ct);

    //Altas

    public async Task<int> RegistrarClienteAsync(DatosPersona persona, string nombreUsuario, string passwordHash,
                                                 CancellationToken ct)
    {
        var parametros = ParametrosPersona(persona);
        parametros.Add("NombreUsuario", nombreUsuario);
        parametros.Add("PasswordHash", passwordHash);
        parametros.Add("IdCliente", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await sp.EjecutarAsync("res.sp_RegistrarCliente", parametros, ct);
        return parametros.Get<int>("IdCliente");
    }

    public Task<bool> ExisteAdministradorAsync(CancellationToken ct) =>
        db.UsuarioRol.AnyAsync(ur => ur.IdRolNavigation.Codigo == "ADMIN" && ur.IdUsuarioNavigation.Activo, ct);

    //Empleado + usuario ADMIN en una sola transacción: si falla el usuario, no queda un empleado suelto
    public async Task<int> InicializarAdministradorAsync(DatosPersona persona, DatosEmpleado empleado, string nombreUsuario,
                                                         string passwordHash, CancellationToken ct)
    {
        await using var transaccion = await db.Database.BeginTransactionAsync(ct);

        var parametros = ParametrosPersona(persona);
        parametros.Add("IdPuesto", empleado.IdPuesto);
        parametros.Add("TipoSalario", empleado.TipoSalario);
        parametros.Add("MontoSalario", empleado.MontoSalario);
        parametros.Add("CuentaIBAN", empleado.CuentaIBAN);
        parametros.Add("FechaIngreso", empleado.FechaIngreso);
        parametros.Add("IdEmpleado", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await sp.EjecutarAsync("rh.sp_RegistrarEmpleado", parametros, ct);

        var idUsuario = await CrearUsuarioSpAsync(parametros.Get<int>("IdEmpleado"), nombreUsuario, passwordHash, "ADMIN", null, ct);
        await transaccion.CommitAsync(ct);
        return idUsuario;
    }

    //Usuario creado por un administrador: la contraseña es temporal, así que se marca DebeCambiarPassword
    public async Task<int> CrearUsuarioAsync(int idPersona, string nombreUsuario, string passwordHash, string codigoRol,
                                             int idUsuarioAdmin, CancellationToken ct)
    {
        await using var transaccion = await db.Database.BeginTransactionAsync(ct);
        var idUsuario = await CrearUsuarioSpAsync(idPersona, nombreUsuario, passwordHash, codigoRol, idUsuarioAdmin, ct);
        await db.Usuario
            .Where(u => u.IdUsuario == idUsuario)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.DebeCambiarPassword, true), ct);
        await transaccion.CommitAsync(ct);
        return idUsuario;
    }

    //Administración

    public Task<bool> ExisteRolAsync(string codigoRol, CancellationToken ct) =>
        db.Rol.AnyAsync(r => r.Codigo == codigoRol && r.Activo, ct);

    public Task AsignarRolAsync(int idUsuarioAdmin, int idUsuario, string codigoRol, CancellationToken ct) =>
        sp.EjecutarAsync("seg.sp_AsignarRol",
            new { IdUsuarioAdmin = idUsuarioAdmin, IdUsuario = idUsuario, CodigoRol = codigoRol }, ct);

    public Task QuitarRolAsync(int idUsuarioAdmin, int idUsuario, string codigoRol, CancellationToken ct) =>
        sp.EjecutarAsync("seg.sp_QuitarRol",
            new { IdUsuarioAdmin = idUsuarioAdmin, IdUsuario = idUsuario, CodigoRol = codigoRol }, ct);

    public async Task<bool> CambiarEstadoUsuarioAsync(int idUsuario, bool activo, CancellationToken ct) =>
        await db.Usuario
            .Where(u => u.IdUsuario == idUsuario)
            .ExecuteUpdateAsync(s => s.SetProperty(u => u.Activo, activo), ct) > 0;

    public Task<List<UsuarioResumen>> ListarUsuariosAsync(CancellationToken ct) =>
        db.Usuario.AsNoTracking()
            .OrderBy(u => u.NombreUsuario)
            .Select(u => new UsuarioResumen(
                u.IdUsuario,
                u.NombreUsuario,
                u.IdUsuarioNavigation.Nombre + " " + u.IdUsuarioNavigation.Apellidos,
                u.IdUsuarioNavigation.Correo,
                u.Activo,
                u.DebeCambiarPassword,
                u.BloqueadoHasta,
                u.UltimoAcceso,
                u.UsuarioRol.Select(ur => ur.IdRolNavigation.Codigo).ToList()))
            .ToListAsync(ct);

    public Task<List<RolResumen>> ListarRolesAsync(CancellationToken ct) =>
        db.Rol.AsNoTracking()
            .OrderBy(r => r.Ambito).ThenBy(r => r.Nombre)
            .Select(r => new RolResumen(
                r.Codigo,
                r.Nombre,
                r.Ambito,
                r.Activo,
                r.RolModulo
                    .OrderBy(rm => rm.IdModuloNavigation.Nombre)
                    .Select(rm => new PermisoModulo(rm.IdModuloNavigation.Codigo, rm.IdModuloNavigation.Nombre,
                                                    rm.PuedeVer, rm.PuedeCrear, rm.PuedeEditar, rm.PuedeAnular))
                    .ToList()))
            .ToListAsync(ct);

    //Apoyo

    private async Task<int> CrearUsuarioSpAsync(int idPersona, string nombreUsuario, string passwordHash, string codigoRol,
                                                int? idUsuarioAdmin, CancellationToken ct)
    {
        var parametros = new DynamicParameters(new
        {
            IdPersona = idPersona,
            NombreUsuario = nombreUsuario,
            PasswordHash = passwordHash,
            CodigoRol = codigoRol,
            IdUsuarioAdmin = idUsuarioAdmin
        });
        parametros.Add("IdUsuario", dbType: DbType.Int32, direction: ParameterDirection.Output);
        await sp.EjecutarAsync("seg.sp_CrearUsuario", parametros, ct);
        return parametros.Get<int>("IdUsuario");
    }

    private static DynamicParameters ParametrosPersona(DatosPersona p) => new(new
    {
        p.TipoIdentificacion,
        Identificacion = p.Identificacion.Trim().ToUpperInvariant(),
        Nombre = p.Nombre.Trim(),
        Apellidos = p.Apellidos.Trim(),
        Correo = p.Correo.Trim().ToLowerInvariant(),
        Telefono = p.Telefono?.Trim()
    });
}
