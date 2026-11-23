using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class CategoriaMenu
{
    public int IdCategoria { get; set; }

    public string Nombre { get; set; } = null!;

    public bool Activa { get; set; }

    public virtual ICollection<ProductoMenu> ProductoMenu { get; set; } = new List<ProductoMenu>();
}
