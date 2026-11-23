using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Abono
{
    public int IdAbono { get; set; }

    public int IdReserva { get; set; }

    public byte Numero { get; set; }

    public string Concepto { get; set; } = null!;

    public decimal MontoProgramado { get; set; }

    public decimal MontoPagado { get; set; }

    public decimal? SaldoPendiente { get; set; }

    public DateTime FechaLimite { get; set; }

    public string Estado { get; set; } = null!;

    public DateTime? FechaPago { get; set; }

    public virtual Reserva IdReservaNavigation { get; set; } = null!;
}
