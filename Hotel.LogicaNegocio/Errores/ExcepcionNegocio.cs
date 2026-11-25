namespace Hotel.LogicaNegocio.Errores;

//Tipo de error que la API traduce a un código HTTP
public enum TipoError
{
    Validacion,          // 400
    NoAutorizado,        // 401
    Prohibido,           // 403
    NoEncontrado,        // 404
    Conflicto,           // 409
    Bloqueado,           // 423
    DemasiadosIntentos   // 429
}

//Regla validada en C# (las de la BD llegan como SqlException); el mensaje se muestra tal cual al usuario
public sealed class ExcepcionNegocio(TipoError tipo, string mensaje) : Exception(mensaje)
{
    public TipoError Tipo { get; } = tipo;
}
