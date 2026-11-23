using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class PedidoHistorial
{
    public long IdHistorial { get; set; }

    public int IdPedido { get; set; }

    public string? EstadoAnterior { get; set; }

    public string EstadoNuevo { get; set; } = null!;

    public int? IdUsuario { get; set; }

    public DateTime Fecha { get; set; }

    public virtual Pedido IdPedidoNavigation { get; set; } = null!;
}
