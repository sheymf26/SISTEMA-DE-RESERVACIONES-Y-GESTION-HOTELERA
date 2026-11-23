using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class TipoHabitacionAmenidad
{
    public int IdTipoHabitacionAmenidad { get; set; }

    public int IdTipoHabitacion { get; set; }

    public int IdAmenidad { get; set; }

    public virtual Amenidad IdAmenidadNavigation { get; set; } = null!;

    public virtual TipoHabitacion IdTipoHabitacionNavigation { get; set; } = null!;
}
