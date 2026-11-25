namespace Hotel.LogicaNegocio.Seguridad;

//Códigos de seg.Modulo
public static class Modulos
{
    public const string Seguridad = "SEGURIDAD";
    public const string Reservas = "RESERVAS";
    public const string Recepcion = "RECEPCION";
    public const string Habitaciones = "HABITACIONES";
    public const string Cocina = "COCINA";
    public const string ServicioHabitacion = "SERVICIO_HABITACION";
    public const string Facturacion = "FACTURACION";
    public const string Planilla = "PLANILLA";
    public const string Reportes = "REPORTES";
}

//Acciones de seg.RolModulo (mismas letras que usa seg.fn_TienePermiso)
public enum AccionPermiso
{
    Ver = 'V',
    Crear = 'C',
    Editar = 'E',
    Anular = 'A'
}

//Origen del login: WEB = sistema de administración (roles SISTEMA), APP = app de clientes (rol CLIENTE)
public static class Origenes
{
    public const string Web = "WEB";
    public const string App = "APP";
}
