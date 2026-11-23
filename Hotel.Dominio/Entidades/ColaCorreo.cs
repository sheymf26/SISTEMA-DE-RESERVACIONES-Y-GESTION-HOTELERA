using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class ColaCorreo
{
    public long IdCorreo { get; set; }

    public string Destinatario { get; set; } = null!;

    public string Asunto { get; set; } = null!;

    public string Cuerpo { get; set; } = null!;

    public string Tipo { get; set; } = null!;

    public int? IdReferencia { get; set; }

    public string Estado { get; set; } = null!;

    public byte Intentos { get; set; }

    public DateTime FechaCreacion { get; set; }

    public DateTime? FechaEnvio { get; set; }

    public string? UltimoError { get; set; }
}
