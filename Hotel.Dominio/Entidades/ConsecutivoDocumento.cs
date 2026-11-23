using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class ConsecutivoDocumento
{
    public string TipoDocumento { get; set; } = null!;

    public long Ultimo { get; set; }
}
