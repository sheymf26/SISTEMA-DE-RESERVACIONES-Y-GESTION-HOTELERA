using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Factura
{
    public int IdFactura { get; set; }

    public string? NumeroFactura { get; set; }

    public string TipoDocumento { get; set; } = null!;

    public string Consecutivo { get; set; } = null!;

    public string Clave { get; set; } = null!;

    public string CodigoActividad { get; set; } = null!;

    public string CondicionVenta { get; set; } = null!;

    public string? MedioPago { get; set; }

    public string Moneda { get; set; } = null!;

    public decimal TipoCambio { get; set; }

    public int IdReserva { get; set; }

    public int IdCliente { get; set; }

    public string ReceptorNombre { get; set; } = null!;

    public string ReceptorTipoId { get; set; } = null!;

    public string ReceptorIdentificacion { get; set; } = null!;

    public string ReceptorCorreo { get; set; } = null!;

    public string TipoFactura { get; set; } = null!;

    public int? IdFacturaReferencia { get; set; }

    public string? CodigoReferencia { get; set; }

    public string? RazonReferencia { get; set; }

    public DateTime FechaEmision { get; set; }

    public decimal Subtotal { get; set; }

    public decimal Descuento { get; set; }

    public decimal Impuesto { get; set; }

    public decimal Total { get; set; }

    public string Estado { get; set; } = null!;

    public int? EmitidaPor { get; set; }

    public string? MotivoAnulacion { get; set; }

    public DateTime? FechaAnulacion { get; set; }

    public int? AnuladaPor { get; set; }

    public string EstadoHacienda { get; set; } = null!;

    public byte[]? XmlComprobante { get; set; }

    public byte[]? XmlRespuesta { get; set; }

    public string? MensajeHacienda { get; set; }

    public DateTime? FechaEnvioHacienda { get; set; }

    public DateTime? FechaRespuestaHacienda { get; set; }

    public virtual Usuario? AnuladaPorNavigation { get; set; }

    public virtual Usuario? EmitidaPorNavigation { get; set; }

    public virtual ICollection<FacturaDetalle> FacturaDetalle { get; set; } = new List<FacturaDetalle>();

    public virtual Cliente IdClienteNavigation { get; set; } = null!;

    public virtual Factura? IdFacturaReferenciaNavigation { get; set; }

    public virtual Reserva IdReservaNavigation { get; set; } = null!;

    public virtual Factura? InverseIdFacturaReferenciaNavigation { get; set; }

    public virtual ICollection<Pago> Pago { get; set; } = new List<Pago>();
}
