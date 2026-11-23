using System.Data.Common;
using Hotel.LogicaNegocio.Abstracciones;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace Hotel.AccesoDatos.Contexto;

//Cada vez que EF abre una conexión, fija SESSION_CONTEXT('IdUsuario') con el usuario del JWT.
//Los triggers de la BD lo leen para llenar aud.Bitacora.IdUsuario.
//Al devolver la conexión al pool, SQL Server limpia el SESSION_CONTEXT (sp_reset_connection),
//así que un valor nunca "se filtra" a la petición de otro usuario

public sealed class SesionUsuarioInterceptor(IUsuarioActual usuarioActual) : DbConnectionInterceptor
{
    private const string Sql = "EXEC sys.sp_set_session_context @key = N'IdUsuario', @value = @IdUsuario;";

    public override void ConnectionOpened(DbConnection connection, ConnectionEndEventData eventData)
    {
        using var comando = CrearComando(connection);
        comando?.ExecuteNonQuery();
    }

    public override async Task ConnectionOpenedAsync(DbConnection connection, ConnectionEndEventData eventData,
                                                     CancellationToken cancellationToken = default)
    {
        await using var comando = CrearComando(connection);
        if (comando is not null)
            await comando.ExecuteNonQueryAsync(cancellationToken);
    }

    private DbCommand? CrearComando(DbConnection connection)
    {
        if (usuarioActual.IdUsuario is not int idUsuario)
            return null; // una petición anónima: no hay nada que fijar

        var comando = connection.CreateCommand();
        comando.CommandText = Sql;
        var parametro = comando.CreateParameter();
        parametro.ParameterName = "@IdUsuario";
        parametro.Value = idUsuario;
        comando.Parameters.Add(parametro);
        return comando;
    }
}
