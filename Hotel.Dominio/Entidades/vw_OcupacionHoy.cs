using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class vw_OcupacionHoy
{
    public string Edificio { get; set; } = null!;

    public int? TotalHabitaciones { get; set; }

    public int? Ocupadas { get; set; }

    public int? EnLimpieza { get; set; }

    public int? FueraDeServicio { get; set; }

    public int? ReservadasHoy { get; set; }

    public decimal? PorcentajeOcupacion { get; set; }
}
