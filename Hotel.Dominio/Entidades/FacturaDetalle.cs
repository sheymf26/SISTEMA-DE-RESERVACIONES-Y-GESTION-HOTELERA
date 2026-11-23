using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class FacturaDetalle
{
    public int IdFacturaDetalle { get; set; }

    public int IdFactura { get; set; }

    public short NumeroLinea { get; set; }

    public string TipoLinea { get; set; } = null!;

    public string? CodigoCabys { get; set; }

    public string Descripcion { get; set; } = null!;

    public decimal Cantidad { get; set; }

    public string UnidadMedida { get; set; } = null!;

    public decimal PrecioUnitario { get; set; }

    public decimal? MontoTotal { get; set; }

    public int? IdDescuento { get; set; }

    public decimal PorcentajeDescuento { get; set; }

    public decimal MontoDescuento { get; set; }

    public string? NaturalezaDescuento { get; set; }

    public decimal? SubTotal { get; set; }

    public decimal PorcentajeImpuesto { get; set; }

    public decimal? MontoImpuesto { get; set; }

    public decimal? TotalLinea { get; set; }

    public int? IdReservaHabitacion { get; set; }

    public int? IdPedido { get; set; }

    public virtual Descuento? IdDescuentoNavigation { get; set; }

    public virtual Factura IdFacturaNavigation { get; set; } = null!;

    public virtual Pedido? IdPedidoNavigation { get; set; }

    public virtual ReservaHabitacion? IdReservaHabitacionNavigation { get; set; }
}
