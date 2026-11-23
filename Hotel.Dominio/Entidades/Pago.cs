using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Pago
{
    public int IdPago { get; set; }

    public int IdReserva { get; set; }

    public int? IdFactura { get; set; }

    public string TipoMovimiento { get; set; } = null!;

    public string Metodo { get; set; } = null!;

    public decimal Monto { get; set; }

    public string? Referencia { get; set; }

    public bool Anulado { get; set; }

    public int? RegistradoPor { get; set; }

    public DateTime Fecha { get; set; }

    public virtual Factura? IdFacturaNavigation { get; set; }

    public virtual Reserva IdReservaNavigation { get; set; } = null!;

    public virtual Usuario? RegistradoPorNavigation { get; set; }
}
