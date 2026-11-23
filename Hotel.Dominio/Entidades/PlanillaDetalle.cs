using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class PlanillaDetalle
{
    public int IdPlanillaDetalle { get; set; }

    public int IdPlanilla { get; set; }

    public int IdEmpleado { get; set; }

    public decimal SalarioBase { get; set; }

    public decimal HorasOrdinarias { get; set; }

    public decimal HorasExtra { get; set; }

    public decimal MontoHorasExtra { get; set; }

    public decimal Bonificaciones { get; set; }

    public decimal PorcentajeCCSS { get; set; }

    public decimal ImpuestoRenta { get; set; }

    public decimal OtrasDeducciones { get; set; }

    public decimal? SalarioBruto { get; set; }

    public decimal? DeduccionCCSS { get; set; }

    public decimal? SalarioNeto { get; set; }

    public virtual Empleado IdEmpleadoNavigation { get; set; } = null!;

    public virtual Planilla IdPlanillaNavigation { get; set; } = null!;
}
