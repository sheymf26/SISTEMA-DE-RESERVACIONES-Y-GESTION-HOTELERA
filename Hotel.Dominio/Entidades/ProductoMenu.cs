using System;
using System.Collections.Generic;

namespace Hotel.Dominio.Entidades;

public partial class ProductoMenu
{
    public int IdProducto { get; set; }

    public int IdCategoria { get; set; }

    public string Nombre { get; set; } = null!;

    public string? Descripcion { get; set; }

    public decimal Precio { get; set; }

    public byte MinutosPreparacion { get; set; }

    public int? Stock { get; set; }

    public string? CodigoCabys { get; set; }

    public bool Disponible { get; set; }

    public byte[] RowVer { get; set; } = null!;

    public virtual CategoriaMenu IdCategoriaNavigation { get; set; } = null!;

    public virtual ICollection<PedidoDetalle> PedidoDetalle { get; set; } = new List<PedidoDetalle>();
}
