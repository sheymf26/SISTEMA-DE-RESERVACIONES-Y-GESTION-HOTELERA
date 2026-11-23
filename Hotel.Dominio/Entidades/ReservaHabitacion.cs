using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class ReservaHabitacion
{
    public int IdReservaHabitacion { get; set; }

    public int IdReserva { get; set; }

    public int IdHabitacion { get; set; }

    public DateOnly FechaDesde { get; set; }

    public DateOnly FechaHasta { get; set; }

    public byte Adultos { get; set; }

    public byte Ninos { get; set; }

    public byte CapacidadBase { get; set; }

    public decimal PrecioNoche { get; set; }

    public decimal PrecioPersonaExtra { get; set; }

    public int? Noches { get; set; }

    public int? PersonasExtra { get; set; }

    public decimal MontoTotal { get; set; }

    public string Estado { get; set; } = null!;

    public int? IdReservaHabitacionOrigen { get; set; }

    public string? MotivoCambio { get; set; }

    public DateTime FechaCreacion { get; set; }

    public virtual ICollection<FacturaDetalle> FacturaDetalle { get; set; } = new List<FacturaDetalle>();

    public virtual ICollection<Huesped> Huesped { get; set; } = new List<Huesped>();

    public virtual Habitacion IdHabitacionNavigation { get; set; } = null!;

    public virtual ReservaHabitacion? IdReservaHabitacionOrigenNavigation { get; set; }

    public virtual Reserva IdReservaNavigation { get; set; } = null!;

    public virtual ICollection<ReservaHabitacion> InverseIdReservaHabitacionOrigenNavigation { get; set; } = new List<ReservaHabitacion>();

    public virtual ICollection<Pedido> Pedido { get; set; } = new List<Pedido>();

    public virtual ICollection<ReservaHabitacionNoche> ReservaHabitacionNoche { get; set; } = new List<ReservaHabitacionNoche>();

    public virtual ICollection<TarjetaHabitacion> TarjetaHabitacion { get; set; } = new List<TarjetaHabitacion>();
}
