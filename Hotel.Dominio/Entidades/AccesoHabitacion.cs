using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class AccesoHabitacion
{
    public long IdAcceso { get; set; }

    public int? IdTarjeta { get; set; }

    public int IdHabitacion { get; set; }

    public string Medio { get; set; } = null!;

    public bool Permitido { get; set; }

    public string? Motivo { get; set; }

    public DateTime Fecha { get; set; }

    public virtual Habitacion IdHabitacionNavigation { get; set; } = null!;

    public virtual TarjetaHabitacion? IdTarjetaNavigation { get; set; }
}
