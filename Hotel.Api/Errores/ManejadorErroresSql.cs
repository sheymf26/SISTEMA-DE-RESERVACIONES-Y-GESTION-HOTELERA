using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Data.SqlClient;
using Microsoft.EntityFrameworkCore;

namespace Hotel.Api.Errores;

//Traduce los errores de SQL Server a respuestas ProblemDetails (RFC 9457)
//Las reglas de negocio viven en la BD (THROW 50001-50999): su mensaje ya está en español y pensado
//para el usuario, así que se devuelve tal cual en "detail" y el número va en "codigo" para que el front decida
//Cualquier otra excepción no se maneja aquí y termina en un 500 genérico (sin filtrar detalles internos)

public sealed class ManejadorErroresSql(
    IProblemDetailsService problemDetails,
    IHostEnvironment entorno,
    ILogger<ManejadorErroresSql> log) : IExceptionHandler
{
    public async ValueTask<bool> TryHandleAsync(HttpContext http, Exception excepcion, CancellationToken ct)
    {
        var error = excepcion is DbUpdateConcurrencyException
            ? new ErrorTraducido(StatusCodes.Status409Conflict, "Conflicto de concurrencia",
                                 "Otro usuario modificó este registro. Actualice la pantalla e intente de nuevo.", null)
            : BuscarSqlException(excepcion) is { } sql ? Traducir(sql) : null;

        if (error is null) return false;

        if (error.Status >= 500)
            log.LogError(excepcion, "Error de base de datos no controlado");
        else
            log.LogInformation("Regla rechazada por la BD {Codigo}: {Detalle}", error.Codigo, error.Detalle);

        var detalle = new ProblemDetails { Status = error.Status, Title = error.Titulo, Detail = error.Detalle };
        if (error.Codigo is int codigo) detalle.Extensions["codigo"] = codigo;
        // En desarrollo se agrega el mensaje crudo de SQL para depurar (nombre de la restricción, etc.)
        if (entorno.IsDevelopment() && error.Codigo is < 50000 && BuscarSqlException(excepcion) is { } crudo)
            detalle.Extensions["sql"] = crudo.Message;

        http.Response.StatusCode = error.Status;
        return await problemDetails.TryWriteAsync(new ProblemDetailsContext
        {
            HttpContext = http,
            ProblemDetails = detalle,
            Exception = excepcion
        });
    }

    private static SqlException? BuscarSqlException(Exception? ex)
    {
        for (; ex is not null; ex = ex.InnerException)
            if (ex is SqlException sql) return sql;
        return null;
    }

    private static ErrorTraducido? Traducir(SqlException sql)
    {
        //Un THROW dentro de un trigger o SP anidado puede venir acompañado de otros errores: se prioriza el de negocio
        var negocio = sql.Errors.Cast<SqlError>().FirstOrDefault(e => e.Number is >= 50000 and <= 50999);
        if (negocio is not null)
        {
            var (status, titulo) = negocio.Number switch
            {
                50100 or 50101                => (StatusCodes.Status403Forbidden, "Acceso denegado"),
                50110 or 50111 or 50112       => (StatusCodes.Status401Unauthorized, "Sesión no válida"),
                50030 or 50081 or 50177       => (StatusCodes.Status404NotFound, "No encontrado"),
                50006 or 50082                => (StatusCodes.Status409Conflict, "Operación concurrente"),
                >= 50900                      => (StatusCodes.Status409Conflict, "Operación no permitida"),
                _                             => (StatusCodes.Status400BadRequest, "Regla de negocio")
            };
            return new ErrorTraducido(status, titulo, negocio.Message, negocio.Number);
        }

        return sql.Number switch
        {
            2627 or 2601 => new(StatusCodes.Status409Conflict, "Registro duplicado",
                                "Ya existe un registro con esos datos.", sql.Number),
            547          => new(StatusCodes.Status400BadRequest, "Datos inválidos",
                                "Los datos no cumplen una validación o hacen referencia a un registro inexistente.", sql.Number),
            1205         => new(StatusCodes.Status409Conflict, "Operación concurrente",
                                "El sistema estaba ocupado con otra operación. Intente de nuevo.", sql.Number),
            _ => null // fallas de conexión, timeouts, etc.: 500
        };
    }

    private sealed record ErrorTraducido(int Status, string Titulo, string Detalle, int? Codigo);
}
