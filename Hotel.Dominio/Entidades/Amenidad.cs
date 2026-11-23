using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Amenidad
{
    public int IdAmenidad { get; set; }

    public string Codigo { get; set; } = null!;

    public string Nombre { get; set; } = null!;

    public string? Descripcion { get; set; }

    public bool Activa { get; set; }

    public virtual ICollection<HabitacionAmenidad> HabitacionAmenidad { get; set; } = new List<HabitacionAmenidad>();

    public virtual ICollection<TipoHabitacionAmenidad> TipoHabitacionAmenidad { get; set; } = new List<TipoHabitacionAmenidad>();
}
