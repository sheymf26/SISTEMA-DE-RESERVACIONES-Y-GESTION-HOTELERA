using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Temporada
{
    public int IdTemporada { get; set; }

    public string Nombre { get; set; } = null!;

    public string Tipo { get; set; } = null!;

    public DateOnly FechaInicio { get; set; }

    public DateOnly FechaFin { get; set; }

    public decimal PorcentajeAjuste { get; set; }

    public bool Activa { get; set; }

    public virtual ICollection<Descuento> Descuento { get; set; } = new List<Descuento>();

    public virtual ICollection<ReservaHabitacionNoche> ReservaHabitacionNoche { get; set; } = new List<ReservaHabitacionNoche>();
}
