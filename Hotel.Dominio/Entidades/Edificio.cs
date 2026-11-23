using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Edificio
{
    public int IdEdificio { get; set; }

    public byte Numero { get; set; }

    public string Codigo { get; set; } = null!;

    public string Nombre { get; set; } = null!;

    public virtual ICollection<Piso> Piso { get; set; } = new List<Piso>();
}
