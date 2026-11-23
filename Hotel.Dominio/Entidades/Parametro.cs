using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Parametro
{
    public string Clave { get; set; } = null!;

    public decimal Valor { get; set; }

    public string Descripcion { get; set; } = null!;
}
