using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class ReservaHabitacionNoche
{
    public long IdNoche { get; set; }

    public int IdReservaHabitacion { get; set; }

    public DateOnly Fecha { get; set; }

    public int? IdTemporada { get; set; }

    public decimal PorcentajeAjuste { get; set; }

    public decimal PrecioNoche { get; set; }

    public decimal PrecioPersonaExtra { get; set; }

    public virtual ReservaHabitacion IdReservaHabitacionNavigation { get; set; } = null!;

    public virtual Temporada? IdTemporadaNavigation { get; set; }
}
