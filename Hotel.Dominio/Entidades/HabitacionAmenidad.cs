using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class HabitacionAmenidad
{
    public int IdHabitacionAmenidad { get; set; }

    public int IdHabitacion { get; set; }

    public int IdAmenidad { get; set; }

    public virtual Amenidad IdAmenidadNavigation { get; set; } = null!;

    public virtual Habitacion IdHabitacionNavigation { get; set; } = null!;
}
