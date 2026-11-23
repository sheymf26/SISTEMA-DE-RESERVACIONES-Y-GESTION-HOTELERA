using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Usuario
{
    public int IdUsuario { get; set; }

    public string NombreUsuario { get; set; } = null!;

    public string PasswordHash { get; set; } = null!;

    public Guid SecurityStamp { get; set; }

    public byte IntentosFallidos { get; set; }

    public DateTime? BloqueadoHasta { get; set; }

    public bool DebeCambiarPassword { get; set; }

    public DateTime? UltimoAcceso { get; set; }

    public bool Activo { get; set; }

    public DateTime FechaCreacion { get; set; }

    public virtual ICollection<BloqueoHabitacion> BloqueoHabitacion { get; set; } = new List<BloqueoHabitacion>();

    public virtual ICollection<Cancelacion> Cancelacion { get; set; } = new List<Cancelacion>();

    public virtual ICollection<Factura> FacturaAnuladaPorNavigation { get; set; } = new List<Factura>();

    public virtual ICollection<Factura> FacturaEmitidaPorNavigation { get; set; } = new List<Factura>();

    public virtual Persona IdUsuarioNavigation { get; set; } = null!;

    public virtual ICollection<IntentoLogin> IntentoLogin { get; set; } = new List<IntentoLogin>();

    public virtual ICollection<Pago> Pago { get; set; } = new List<Pago>();

    public virtual ICollection<Pedido> PedidoIdUsuarioCocinaNavigation { get; set; } = new List<Pedido>();

    public virtual ICollection<Pedido> PedidoIdUsuarioEntregaNavigation { get; set; } = new List<Pedido>();

    public virtual ICollection<Planilla> PlanillaAprobadaPorNavigation { get; set; } = new List<Planilla>();

    public virtual ICollection<Planilla> PlanillaCreadaPorNavigation { get; set; } = new List<Planilla>();

    public virtual ICollection<RefreshToken> RefreshToken { get; set; } = new List<RefreshToken>();

    public virtual ICollection<RegistroHoras> RegistroHoras { get; set; } = new List<RegistroHoras>();

    public virtual ICollection<Reserva> Reserva { get; set; } = new List<Reserva>();

    public virtual ICollection<TarjetaHabitacion> TarjetaHabitacion { get; set; } = new List<TarjetaHabitacion>();

    public virtual ICollection<UsuarioRol> UsuarioRol { get; set; } = new List<UsuarioRol>();
}
