using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class vw_SeguimientoPedido
{
    public int IdPedido { get; set; }

    public int IdReservaHabitacion { get; set; }

    public int IdCliente { get; set; }

    public string Habitacion { get; set; } = null!;

    public string Estado { get; set; } = null!;

    public int Etapa { get; set; }

    public DateTime FechaPedido { get; set; }

    public decimal Subtotal { get; set; }

    public decimal CargoServicio { get; set; }

    public decimal Impuesto { get; set; }

    public decimal? Total { get; set; }

    public short MinPreparacionEst { get; set; }

    public short MinEmpaqueEst { get; set; }

    public short MinEntregaEst { get; set; }

    public int? MinutosRestantes { get; set; }

    public DateTime? HoraEstimadaEntrega { get; set; }

    public int? Progreso { get; set; }

    public bool? PuedeCancelarse { get; set; }
}
