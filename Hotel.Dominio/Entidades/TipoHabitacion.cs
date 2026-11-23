using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class TipoHabitacion
{
    public int IdTipoHabitacion { get; set; }

    public string Nombre { get; set; } = null!;

    public byte CapacidadBase { get; set; }

    public byte CapacidadMaxima { get; set; }

    public byte CantidadCamas { get; set; }

    public string TipoCama { get; set; } = null!;

    public decimal? MetrosCuadrados { get; set; }

    public decimal PrecioNoche { get; set; }

    public decimal PrecioPersonaExtra { get; set; }

    public string? CodigoCabys { get; set; }

    public string? Descripcion { get; set; }

    public bool Activo { get; set; }

    public virtual ICollection<Habitacion> Habitacion { get; set; } = new List<Habitacion>();

    public virtual ICollection<TipoHabitacionAmenidad> TipoHabitacionAmenidad { get; set; } = new List<TipoHabitacionAmenidad>();
}
