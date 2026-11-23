using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class IntentoLogin
{
    public long IdIntento { get; set; }

    public string LoginIngresado { get; set; } = null!;

    public int? IdUsuario { get; set; }

    public string Origen { get; set; } = null!;

    public bool Exitoso { get; set; }

    public string? IpOrigen { get; set; }

    public string? Dispositivo { get; set; }

    public DateTime Fecha { get; set; }

    public virtual Usuario? IdUsuarioNavigation { get; set; }
}
