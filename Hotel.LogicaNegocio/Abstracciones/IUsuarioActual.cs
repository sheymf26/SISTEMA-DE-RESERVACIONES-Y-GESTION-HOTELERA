namespace Hotel.LogicaNegocio.Abstracciones;


//Usuario autenticado en la petición actual. La API lo resuelve desde el JWT;
//la capa de datos lo usa para fijar SESSION_CONTEXT('IdUsuario') y que la bitácora sepa quién hizo cada cambio
public interface IUsuarioActual
{
    //Null cuando la petición es anónima (login, registro, disponibilidad pública)
    int? IdUsuario { get; }
}
