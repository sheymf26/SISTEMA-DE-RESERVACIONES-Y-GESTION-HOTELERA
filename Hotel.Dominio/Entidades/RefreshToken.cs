using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class RefreshToken
{
    public long IdRefreshToken { get; set; }

    public int IdUsuario { get; set; }

    public byte[] TokenHash { get; set; } = null!;

    public byte[]? ReemplazadoPor { get; set; }

    public string? Dispositivo { get; set; }

    public string? IpOrigen { get; set; }

    public DateTime FechaCreacion { get; set; }

    public DateTime FechaExpiracion { get; set; }

    public DateTime? FechaRevocacion { get; set; }

    public virtual Usuario IdUsuarioNavigation { get; set; } = null!;
}
