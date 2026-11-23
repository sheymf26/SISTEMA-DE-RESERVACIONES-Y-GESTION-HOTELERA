using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Planilla
{
    public int IdPlanilla { get; set; }

    public string TipoPeriodo { get; set; } = null!;

    public DateOnly FechaInicio { get; set; }

    public DateOnly FechaFin { get; set; }

    public DateOnly FechaPago { get; set; }

    public string Estado { get; set; } = null!;

    public int CreadaPor { get; set; }

    public int? AprobadaPor { get; set; }

    public DateTime? FechaAprobacion { get; set; }

    public DateTime FechaCreacion { get; set; }

    public virtual Usuario? AprobadaPorNavigation { get; set; }

    public virtual Usuario CreadaPorNavigation { get; set; } = null!;

    public virtual ICollection<PlanillaDetalle> PlanillaDetalle { get; set; } = new List<PlanillaDetalle>();
}
