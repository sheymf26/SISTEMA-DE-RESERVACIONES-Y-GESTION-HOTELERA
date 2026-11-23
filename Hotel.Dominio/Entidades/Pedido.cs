using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Pedido
{
    public int IdPedido { get; set; }

    public int IdReservaHabitacion { get; set; }

    public int IdHabitacion { get; set; }

    public string Estado { get; set; } = null!;

    public decimal Subtotal { get; set; }

    public decimal CargoServicio { get; set; }

    public decimal Impuesto { get; set; }

    public decimal? Total { get; set; }

    public short MinPreparacionEst { get; set; }

    public short MinEmpaqueEst { get; set; }

    public short MinEntregaEst { get; set; }

    public string? Notas { get; set; }

    public DateTime FechaPedido { get; set; }

    public DateTime? FechaConfirmado { get; set; }

    public DateTime? FechaPreparacion { get; set; }

    public DateTime? FechaEmpaquetado { get; set; }

    public DateTime? FechaEnCamino { get; set; }

    public DateTime? FechaEntregado { get; set; }

    public DateTime? FechaCancelado { get; set; }

    public string? MotivoCancelacion { get; set; }

    public int? IdUsuarioCocina { get; set; }

    public int? IdUsuarioEntrega { get; set; }

    public bool Facturado { get; set; }

    public byte[] RowVer { get; set; } = null!;

    public virtual ICollection<FacturaDetalle> FacturaDetalle { get; set; } = new List<FacturaDetalle>();

    public virtual Habitacion IdHabitacionNavigation { get; set; } = null!;

    public virtual ReservaHabitacion IdReservaHabitacionNavigation { get; set; } = null!;

    public virtual Usuario? IdUsuarioCocinaNavigation { get; set; }

    public virtual Usuario? IdUsuarioEntregaNavigation { get; set; }

    public virtual ICollection<PedidoDetalle> PedidoDetalle { get; set; } = new List<PedidoDetalle>();

    public virtual ICollection<PedidoHistorial> PedidoHistorial { get; set; } = new List<PedidoHistorial>();
}
