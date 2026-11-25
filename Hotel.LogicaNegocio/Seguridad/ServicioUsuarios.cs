using Hotel.LogicaNegocio.Abstracciones;
using Hotel.LogicaNegocio.Errores;

namespace Hotel.LogicaNegocio.Seguridad;

//Administración de usuarios y roles (módulo SEGURIDAD). Los SP vuelven a exigir el permiso con @IdUsuarioAdmin
public sealed class ServicioUsuarios(IRepositorioSeguridad repo, IHasherPassword hasher, IUsuarioActual usuarioActual)
{
    private int IdAdmin => usuarioActual.IdUsuario
                           ?? throw new ExcepcionNegocio(TipoError.NoAutorizado, "Debe iniciar sesión.");

    public Task<List<UsuarioResumen>> ListarAsync(CancellationToken ct) => repo.ListarUsuariosAsync(ct);

    public Task<List<RolResumen>> ListarRolesAsync(CancellationToken ct) => repo.ListarRolesAsync(ct);

    public async Task<int> CrearAsync(SolicitudCrearUsuario solicitud, CancellationToken ct)
    {
        PoliticaPassword.Validar(solicitud.PasswordTemporal);
        await ExigirRolAsync(solicitud.CodigoRol, ct);
        return await repo.CrearUsuarioAsync(solicitud.IdPersona, solicitud.NombreUsuario,
            hasher.Hashear(solicitud.PasswordTemporal), solicitud.CodigoRol, IdAdmin, ct);
    }

    public async Task AsignarRolAsync(int idUsuario, string codigoRol, CancellationToken ct)
    {
        await ExigirRolAsync(codigoRol, ct);
        await repo.AsignarRolAsync(IdAdmin, idUsuario, codigoRol, ct);
    }

    public Task QuitarRolAsync(int idUsuario, string codigoRol, CancellationToken ct) =>
        repo.QuitarRolAsync(IdAdmin, idUsuario, codigoRol, ct);

    //Desactivar dispara el trigger de seg.Usuario: renueva el SecurityStamp y revoca sus sesiones
    public async Task CambiarEstadoAsync(int idUsuario, bool activo, CancellationToken ct)
    {
        if (idUsuario == IdAdmin && !activo)
            throw new ExcepcionNegocio(TipoError.Validacion, "No puede desactivar su propio usuario.");
        if (!await repo.CambiarEstadoUsuarioAsync(idUsuario, activo, ct))
            throw new ExcepcionNegocio(TipoError.NoEncontrado, "El usuario no existe.");
    }

    //seg.sp_AsignarRol no avisa si el código no existe: se valida antes para no responder "éxito" sin hacer nada
    private async Task ExigirRolAsync(string codigoRol, CancellationToken ct)
    {
        if (!await repo.ExisteRolAsync(codigoRol, ct))
            throw new ExcepcionNegocio(TipoError.NoEncontrado, $"El rol {codigoRol} no existe o está inactivo.");
    }
}
