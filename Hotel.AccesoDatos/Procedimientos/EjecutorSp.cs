using System.Data;
using System.Data.Common;
using Dapper;
using Hotel.AccesoDatos.Contexto;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Storage;

namespace Hotel.AccesoDatos.Procedimientos;

///Ejecuta procedimientos almacenados con Dapper sobre la MISMA conexión y transacción del DbContext:
///así pasa por <see cref="SesionUsuarioInterceptor"/> (bitácora) y puede combinarse con EF en una transacción
///Los parámetros se envían como objeto anónimo (new { IdReserva = 5 }) o como <see cref="DynamicParameters"/>
///cuando el procedimiento tiene parámetros OUTPUT.
///Los errores de negocio (THROW 50xxx) se propagan como SqlException y la API los traduce a HTTP

public sealed class EjecutorSp(HotelDbContext db)
{
    //Procedimiento que devuelve filas (SELECT final)
    public Task<IReadOnlyList<T>> ConsultarAsync<T>(string procedimiento, object? parametros = null,
                                                    CancellationToken ct = default)
        => ConConexionAsync(async conexion =>
            (IReadOnlyList<T>)(await conexion.QueryAsync<T>(Comando(procedimiento, parametros, ct))).AsList(), ct);

    //Procedimiento que devuelve una sola fila (o ninguna)
    public Task<T?> ConsultarUnoAsync<T>(string procedimiento, object? parametros = null,
                                         CancellationToken ct = default)
        => ConConexionAsync(conexion => conexion.QueryFirstOrDefaultAsync<T>(Comando(procedimiento, parametros, ct)), ct);

    //Procedimiento sin filas de resultado; los OUTPUT se leen después desde <see cref="DynamicParameters"/>
    public Task EjecutarAsync(string procedimiento, object? parametros = null, CancellationToken ct = default)
        => ConConexionAsync(conexion => conexion.ExecuteAsync(Comando(procedimiento, parametros, ct)), ct);

    private CommandDefinition Comando(string procedimiento, object? parametros, CancellationToken ct)
        => new(procedimiento, parametros,
               transaction: db.Database.CurrentTransaction?.GetDbTransaction(),
               commandType: CommandType.StoredProcedure,
               cancellationToken: ct);

    //Abrir la conexión a través de EF dispara el interceptor; EF lleva la cuenta de aperturas,
    //por lo que dentro de una transacción la conexión sigue abierta al terminar
    private async Task<T> ConConexionAsync<T>(Func<DbConnection, Task<T>> accion, CancellationToken ct)
    {
        await db.Database.OpenConnectionAsync(ct);
        try
        {
            return await accion(db.Database.GetDbConnection());
        }
        finally
        {
            await db.Database.CloseConnectionAsync();
        }
    }
}
