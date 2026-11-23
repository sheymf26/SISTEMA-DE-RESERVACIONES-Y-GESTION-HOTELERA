using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Huesped
{
    public int IdHuesped { get; set; }

    public int IdReservaHabitacion { get; set; }

    public string NombreCompleto { get; set; } = null!;

    public string? TipoIdentificacion { get; set; }

    public string? Identificacion { get; set; }

    public bool EsMenor { get; set; }

    public virtual ReservaHabitacion IdReservaHabitacionNavigation { get; set; } = null!;
}
