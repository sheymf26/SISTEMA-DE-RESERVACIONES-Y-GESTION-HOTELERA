using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Empleado
{
    public int IdEmpleado { get; set; }

    public int IdPuesto { get; set; }

    public string TipoSalario { get; set; } = null!;

    public decimal MontoSalario { get; set; }

    public string? CuentaIBAN { get; set; }

    public DateOnly FechaIngreso { get; set; }

    public DateOnly? FechaSalida { get; set; }

    public bool Activo { get; set; }

    public virtual Persona IdEmpleadoNavigation { get; set; } = null!;

    public virtual Puesto IdPuestoNavigation { get; set; } = null!;

    public virtual ICollection<PlanillaDetalle> PlanillaDetalle { get; set; } = new List<PlanillaDetalle>();

    public virtual ICollection<RegistroHoras> RegistroHoras { get; set; } = new List<RegistroHoras>();
}
