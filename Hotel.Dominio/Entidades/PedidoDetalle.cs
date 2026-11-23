using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class PedidoDetalle
{
    public int IdPedidoDetalle { get; set; }

    public int IdPedido { get; set; }

    public int IdProducto { get; set; }

    public short Cantidad { get; set; }

    public decimal PrecioUnitario { get; set; }

    public decimal? Subtotal { get; set; }

    public string? Notas { get; set; }

    public virtual Pedido IdPedidoNavigation { get; set; } = null!;

    public virtual ProductoMenu IdProductoNavigation { get; set; } = null!;
}
