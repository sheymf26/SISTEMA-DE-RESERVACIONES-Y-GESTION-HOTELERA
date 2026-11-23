using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class BloqueoHabitacion
{
    public int IdBloqueo { get; set; }

    public int IdHabitacion { get; set; }

    public DateOnly FechaDesde { get; set; }

    public DateOnly FechaHasta { get; set; }

    public string Motivo { get; set; } = null!;

    public bool Activo { get; set; }

    public int? CreadoPor { get; set; }

    public DateTime FechaCreacion { get; set; }

    public virtual Usuario? CreadoPorNavigation { get; set; }

    public virtual Habitacion IdHabitacionNavigation { get; set; } = null!;
}
