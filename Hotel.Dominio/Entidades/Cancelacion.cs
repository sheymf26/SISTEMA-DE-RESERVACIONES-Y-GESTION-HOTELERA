using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Cancelacion
{
    public int IdCancelacion { get; set; }

    public int IdReserva { get; set; }

    public DateTime FechaCancelacion { get; set; }

    public int HorasAntelacion { get; set; }

    public int? IdPolitica { get; set; }

    public decimal PorcentajePolitica { get; set; }

    public bool EraClienteFrecuente { get; set; }

    public decimal PorcentajeAplicado { get; set; }

    public decimal MontoPagado { get; set; }

    public decimal MontoRetenido { get; set; }

    public decimal MontoReembolso { get; set; }

    public string Motivo { get; set; } = null!;

    public int? CanceladoPor { get; set; }

    public virtual Usuario? CanceladoPorNavigation { get; set; }

    public virtual PoliticaCancelacion? IdPoliticaNavigation { get; set; }

    public virtual Reserva IdReservaNavigation { get; set; } = null!;
}
