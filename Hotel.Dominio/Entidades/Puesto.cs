using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Puesto
{
    public int IdPuesto { get; set; }

    public string Nombre { get; set; } = null!;

    public int? IdRol { get; set; }

    public bool Activo { get; set; }

    public virtual ICollection<Empleado> Empleado { get; set; } = new List<Empleado>();

    public virtual Rol? IdRolNavigation { get; set; }
}
