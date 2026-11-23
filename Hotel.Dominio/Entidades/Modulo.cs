using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Modulo
{
    public int IdModulo { get; set; }

    public string Codigo { get; set; } = null!;

    public string Nombre { get; set; } = null!;

    public bool Activo { get; set; }

    public virtual ICollection<RolModulo> RolModulo { get; set; } = new List<RolModulo>();
}
