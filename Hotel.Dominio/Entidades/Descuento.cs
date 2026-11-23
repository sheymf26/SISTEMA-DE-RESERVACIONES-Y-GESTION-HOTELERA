using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Descuento
{
    public int IdDescuento { get; set; }

    public string? Codigo { get; set; }

    public string Nombre { get; set; } = null!;

    public string Clase { get; set; } = null!;

    public string Tipo { get; set; } = null!;

    public decimal Valor { get; set; }

    public string AplicaA { get; set; } = null!;

    public DateOnly? FechaInicio { get; set; }

    public DateOnly? FechaFin { get; set; }

    public int? IdTemporada { get; set; }

    public byte? MinNoches { get; set; }

    public int? UsosMaximos { get; set; }

    public bool Activo { get; set; }

    public DateTime FechaCreacion { get; set; }

    public virtual ICollection<FacturaDetalle> FacturaDetalle { get; set; } = new List<FacturaDetalle>();

    public virtual Temporada? IdTemporadaNavigation { get; set; }

    public virtual ICollection<Reserva> Reserva { get; set; } = new List<Reserva>();
}
