using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Bitacora
{
    public long IdBitacora { get; set; }

    public string Tabla { get; set; } = null!;

    public string Operacion { get; set; } = null!;

    public int IdRegistro { get; set; }

    public string? DatosAnteriores { get; set; }

    public string? DatosNuevos { get; set; }

    public int? IdUsuario { get; set; }

    public string UsuarioBD { get; set; } = null!;

    public DateTime Fecha { get; set; }
}
