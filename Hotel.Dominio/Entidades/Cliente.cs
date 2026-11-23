using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Cliente
{
    public int IdCliente { get; set; }

    public int EstadiasCompletadas { get; set; }

    public bool EsFrecuente { get; set; }

    public bool Activo { get; set; }

    public DateTime FechaRegistro { get; set; }

    public virtual ICollection<Factura> Factura { get; set; } = new List<Factura>();

    public virtual Persona IdClienteNavigation { get; set; } = null!;

    public virtual ICollection<Reserva> Reserva { get; set; } = new List<Reserva>();
}
