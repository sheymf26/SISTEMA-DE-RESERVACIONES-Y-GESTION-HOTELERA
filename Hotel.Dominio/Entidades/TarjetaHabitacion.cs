using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class TarjetaHabitacion
{
    public int IdTarjeta { get; set; }

    public int IdReservaHabitacion { get; set; }

    public int IdHabitacion { get; set; }

    public string CodigoTarjeta { get; set; } = null!;

    public byte[] TokenQRHash { get; set; } = null!;

    public DateTime ValidaDesde { get; set; }

    public DateTime ValidaHasta { get; set; }

    public string Estado { get; set; } = null!;

    public int? EmitidaPor { get; set; }

    public DateTime FechaEmision { get; set; }

    public DateTime? FechaRevocacion { get; set; }

    public virtual ICollection<AccesoHabitacion> AccesoHabitacion { get; set; } = new List<AccesoHabitacion>();

    public virtual Usuario? EmitidaPorNavigation { get; set; }

    public virtual Habitacion IdHabitacionNavigation { get; set; } = null!;

    public virtual ReservaHabitacion IdReservaHabitacionNavigation { get; set; } = null!;
}
