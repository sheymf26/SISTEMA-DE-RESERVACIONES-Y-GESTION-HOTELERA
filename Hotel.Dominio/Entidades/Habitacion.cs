using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Habitacion
{
    public int IdHabitacion { get; set; }

    public int IdPiso { get; set; }

    public byte NumeroEnPiso { get; set; }

    public string Codigo { get; set; } = null!;

    public int IdTipoHabitacion { get; set; }

    public string Estado { get; set; } = null!;

    public bool Activa { get; set; }

    public byte[] RowVer { get; set; } = null!;

    public virtual ICollection<AccesoHabitacion> AccesoHabitacion { get; set; } = new List<AccesoHabitacion>();

    public virtual ICollection<BloqueoHabitacion> BloqueoHabitacion { get; set; } = new List<BloqueoHabitacion>();

    public virtual ICollection<HabitacionAmenidad> HabitacionAmenidad { get; set; } = new List<HabitacionAmenidad>();

    public virtual Piso IdPisoNavigation { get; set; } = null!;

    public virtual TipoHabitacion IdTipoHabitacionNavigation { get; set; } = null!;

    public virtual ICollection<Pedido> Pedido { get; set; } = new List<Pedido>();

    public virtual ICollection<ReservaHabitacion> ReservaHabitacion { get; set; } = new List<ReservaHabitacion>();

    public virtual ICollection<TarjetaHabitacion> TarjetaHabitacion { get; set; } = new List<TarjetaHabitacion>();
}
