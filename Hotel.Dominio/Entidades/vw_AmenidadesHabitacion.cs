using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class vw_AmenidadesHabitacion
{
    public int IdHabitacion { get; set; }

    public string Habitacion { get; set; } = null!;

    public int IdAmenidad { get; set; }

    public string Codigo { get; set; } = null!;

    public string Nombre { get; set; } = null!;

    public string? Descripcion { get; set; }

    public bool? EsExtra { get; set; }
}
