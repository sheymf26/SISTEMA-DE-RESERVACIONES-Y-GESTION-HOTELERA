using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class Persona
{
    public int IdPersona { get; set; }

    public string TipoIdentificacion { get; set; } = null!;

    public string Identificacion { get; set; } = null!;

    public string Nombre { get; set; } = null!;

    public string Apellidos { get; set; } = null!;

    public string Correo { get; set; } = null!;

    public string? Telefono { get; set; }

    public DateTime FechaRegistro { get; set; }

    public virtual Cliente? Cliente { get; set; }

    public virtual Empleado? Empleado { get; set; }

    public virtual Usuario? Usuario { get; set; }
}
