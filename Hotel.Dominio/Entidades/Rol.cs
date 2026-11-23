using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Rol
{
    public int IdRol { get; set; }

    public string Codigo { get; set; } = null!;

    public string Nombre { get; set; } = null!;

    public string Ambito { get; set; } = null!;

    public bool Activo { get; set; }

    public virtual ICollection<Puesto> Puesto { get; set; } = new List<Puesto>();

    public virtual ICollection<RolModulo> RolModulo { get; set; } = new List<RolModulo>();

    public virtual ICollection<UsuarioRol> UsuarioRol { get; set; } = new List<UsuarioRol>();
}
