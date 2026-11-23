using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Piso
{
    public int IdPiso { get; set; }

    public int IdEdificio { get; set; }

    public byte Numero { get; set; }

    public virtual ICollection<Habitacion> Habitacion { get; set; } = new List<Habitacion>();

    public virtual Edificio IdEdificioNavigation { get; set; } = null!;
}
