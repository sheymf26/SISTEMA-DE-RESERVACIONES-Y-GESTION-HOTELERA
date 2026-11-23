using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class RolModulo
{
    public int IdRolModulo { get; set; }

    public int IdRol { get; set; }

    public int IdModulo { get; set; }

    public bool PuedeVer { get; set; }

    public bool PuedeCrear { get; set; }

    public bool PuedeEditar { get; set; }

    public bool PuedeAnular { get; set; }

    public virtual Modulo IdModuloNavigation { get; set; } = null!;

    public virtual Rol IdRolNavigation { get; set; } = null!;
}
