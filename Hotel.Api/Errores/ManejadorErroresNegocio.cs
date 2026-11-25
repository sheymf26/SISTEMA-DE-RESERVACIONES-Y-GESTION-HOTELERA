using Hotel.LogicaNegocio.Errores;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;

namespace Hotel.Api.Errores;

//Traduce las ExcepcionNegocio (reglas validadas en C#) a ProblemDetails, igual que ManejadorErroresSql hace con la BD
public sealed class ManejadorErroresNegocio(IProblemDetailsService problemDetails) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext http, Exception excepcion, CancellationToken ct)
    {
        if (excepcion is not ExcepcionNegocio negocio) return false;

        var (status, titulo) = negocio.Tipo switch
        {
            TipoError.NoAutorizado       => (StatusCodes.Status401Unauthorized, "No autorizado"),
            TipoError.Prohibido          => (StatusCodes.Status403Forbidden, "Acceso denegado"),
            TipoError.NoEncontrado       => (StatusCodes.Status404NotFound, "No encontrado"),
            TipoError.Conflicto          => (StatusCodes.Status409Conflict, "Conflicto"),
            TipoError.Bloqueado          => (StatusCodes.Status423Locked, "Cuenta bloqueada"),
            TipoError.DemasiadosIntentos => (StatusCodes.Status429TooManyRequests, "Demasiados intentos"),
            _                            => (StatusCodes.Status400BadRequest, "Datos inválidos")
        };

        http.Response.StatusCode = status;
        return await problemDetails.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = http,
            ProblemDetails = new ProblemDetails { Status = status, Title = titulo, Detail = negocio.Message },
            Exception = excepcion
        });
    }
}
