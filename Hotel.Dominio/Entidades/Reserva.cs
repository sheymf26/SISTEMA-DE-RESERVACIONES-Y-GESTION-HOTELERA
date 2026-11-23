using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Reserva
{
    public int IdReserva { get; set; }

    public string? CodigoReserva { get; set; }

    public int IdCliente { get; set; }

    public DateOnly FechaEntrada { get; set; }

    public DateOnly FechaSalida { get; set; }

    public string Estado { get; set; } = null!;

    public string Canal { get; set; } = null!;

    public int? IdDescuento { get; set; }

    public decimal Subtotal { get; set; }

    public decimal MontoDescuento { get; set; }

    public decimal MontoImpuesto { get; set; }

    public decimal Total { get; set; }

    public decimal PorcentajeAnticipo { get; set; }

    public decimal AnticipoRequerido { get; set; }

    public decimal MontoPagado { get; set; }

    public decimal? SaldoAnticipo { get; set; }

    public decimal? SaldoTotal { get; set; }

    public DateTime? FechaExpiracion { get; set; }

    public string? Observaciones { get; set; }

    public int? CreadoPor { get; set; }

    public DateTime FechaCreacion { get; set; }

    public DateTime? FechaModificacion { get; set; }

    public byte[] RowVer { get; set; } = null!;

    public virtual ICollection<Abono> Abono { get; set; } = new List<Abono>();

    public virtual Cancelacion? Cancelacion { get; set; }

    public virtual Usuario? CreadoPorNavigation { get; set; }

    public virtual Factura? Factura { get; set; }

    public virtual Cliente IdClienteNavigation { get; set; } = null!;

    public virtual Descuento? IdDescuentoNavigation { get; set; }

    public virtual ICollection<Pago> Pago { get; set; } = new List<Pago>();

    public virtual ICollection<ReservaHabitacion> ReservaHabitacion { get; set; } = new List<ReservaHabitacion>();
}
