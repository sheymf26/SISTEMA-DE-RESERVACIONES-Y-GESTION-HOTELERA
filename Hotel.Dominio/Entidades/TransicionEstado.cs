using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class TransicionEstado
{
    public string Entidad { get; set; } = null!;

    public string EstadoOrigen { get; set; } = null!;

    public string EstadoDestino { get; set; } = null!;
}
