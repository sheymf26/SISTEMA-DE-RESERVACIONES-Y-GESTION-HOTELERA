using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class PoliticaCancelacion
{
    public int IdPolitica { get; set; }

    public string Nombre { get; set; } = null!;

    public int HorasMinimas { get; set; }

    public decimal PorcentajePenalizacion { get; set; }

    public bool Activa { get; set; }

    public virtual ICollection<Cancelacion> Cancelacion { get; set; } = new List<Cancelacion>();
}
