using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class RegistroHoras
{
    public int IdRegistro { get; set; }

    public int IdEmpleado { get; set; }

    public DateOnly Fecha { get; set; }

    public decimal HorasOrdinarias { get; set; }

    public decimal HorasExtra { get; set; }

    public bool Aprobado { get; set; }

    public int? AprobadoPor { get; set; }

    public virtual Usuario? AprobadoPorNavigation { get; set; }

    public virtual Empleado IdEmpleadoNavigation { get; set; } = null!;
}
