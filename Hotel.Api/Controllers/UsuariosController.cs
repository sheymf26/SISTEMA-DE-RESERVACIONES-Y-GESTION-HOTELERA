using Hotel.Api.Seguridad;
using Hotel.LogicaNegocio.Seguridad;
using Microsoft.AspNetCore.Mvc;

namespace Hotel.Api.Controllers;

//Administración de usuarios del módulo SEGURIDAD
[ApiController]
[Route("api/usuarios")]
public sealed class UsuariosController(ServicioUsuarios usuarios) : ControllerBase
{
    [HttpGet]
    [Permiso(Modulos.Seguridad, AccionPermiso.Ver)]
    public Task<List<UsuarioResumen>> Listar(CancellationToken ct) => usuarios.ListarAsync(ct);

    //Crea el usuario de una persona que ya existe (empleado para roles SISTEMA, cliente para CLIENTE)
    [HttpPost]
    [Permiso(Modulos.Seguridad, AccionPermiso.Crear)]
    public async Task<IActionResult> Crear(SolicitudCrearUsuario solicitud, CancellationToken ct)
    {
        var idUsuario = await usuarios.CrearAsync(solicitud, ct);
        return StatusCode(StatusCodes.Status201Created, new { idUsuario });
    }

    [HttpPut("{idUsuario:int}/roles/{codigoRol}")]
    [Permiso(Modulos.Seguridad, AccionPermiso.Editar)]
    public async Task<IActionResult> AsignarRol(int idUsuario, string codigoRol, CancellationToken ct)
    {
        await usuarios.AsignarRolAsync(idUsuario, codigoRol.ToUpperInvariant(), ct);
        return NoContent();
    }

    [HttpDelete("{idUsuario:int}/roles/{codigoRol}")]
    [Permiso(Modulos.Seguridad, AccionPermiso.Editar)]
    public async Task<IActionResult> QuitarRol(int idUsuario, string codigoRol, CancellationToken ct)
    {
        await usuarios.QuitarRolAsync(idUsuario, codigoRol.ToUpperInvariant(), ct);
        return NoContent();
    }

    [HttpPatch("{idUsuario:int}/estado")]
    [Permiso(Modulos.Seguridad, AccionPermiso.Editar)]
    public async Task<IActionResult> CambiarEstado(int idUsuario, SolicitudEstadoUsuario solicitud, CancellationToken ct)
    {
        await usuarios.CambiarEstadoAsync(idUsuario, solicitud.Activo, ct);
        return NoContent();
    }
}

[ApiController]
[Route("api/roles")]
public sealed class RolesController(ServicioUsuarios usuarios) : ControllerBase
{
    [HttpGet]
    [Permiso(Modulos.Seguridad, AccionPermiso.Ver)]
    public Task<List<RolResumen>> Listar(CancellationToken ct) => usuarios.ListarRolesAsync(ct);
}
