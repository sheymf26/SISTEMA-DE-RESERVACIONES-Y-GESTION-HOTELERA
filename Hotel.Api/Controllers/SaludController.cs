using Hotel.AccesoDatos.Contexto;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Hotel.Api.Controllers;

//Verifica que la API esté arriba y llegue a la base de datos
[ApiController]
[AllowAnonymous]
[Route("api/salud")]
public sealed class SaludController(HotelDbContext db) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> Get(CancellationToken ct)
    {
        var fechaServidor = await db.Database
            .SqlQueryRaw<DateTime>("SELECT SYSDATETIME() AS Value")
            .SingleAsync(ct);
        return Ok(new { estado = "ok", baseDatos = db.Database.GetDbConnection().Database, fechaServidor });
    }
}
