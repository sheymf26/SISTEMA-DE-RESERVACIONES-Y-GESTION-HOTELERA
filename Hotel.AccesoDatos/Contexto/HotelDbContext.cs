using System;
using System.Collections.Generic;
using Hotel.Dominio.Entidades;
using Microsoft.EntityFrameworkCore;

namespace Hotel.AccesoDatos.Contexto;

public partial class HotelDbContext : DbContext
{
    public HotelDbContext(DbContextOptions<HotelDbContext> options)
        : base(options)
    {
    }

    public virtual DbSet<Abono> Abono { get; set; }

    public virtual DbSet<AccesoHabitacion> AccesoHabitacion { get; set; }

    public virtual DbSet<Amenidad> Amenidad { get; set; }

    public virtual DbSet<Bitacora> Bitacora { get; set; }

    public virtual DbSet<BloqueoHabitacion> BloqueoHabitacion { get; set; }

    public virtual DbSet<Cancelacion> Cancelacion { get; set; }

    public virtual DbSet<CategoriaMenu> CategoriaMenu { get; set; }

    public virtual DbSet<Cliente> Cliente { get; set; }

    public virtual DbSet<ColaCorreo> ColaCorreo { get; set; }

    public virtual DbSet<ConsecutivoDocumento> ConsecutivoDocumento { get; set; }

    public virtual DbSet<Descuento> Descuento { get; set; }

    public virtual DbSet<Edificio> Edificio { get; set; }

    public virtual DbSet<Empleado> Empleado { get; set; }

    public virtual DbSet<Factura> Factura { get; set; }

    public virtual DbSet<FacturaDetalle> FacturaDetalle { get; set; }

    public virtual DbSet<Habitacion> Habitacion { get; set; }

    public virtual DbSet<HabitacionAmenidad> HabitacionAmenidad { get; set; }

    public virtual DbSet<Huesped> Huesped { get; set; }

    public virtual DbSet<IntentoLogin> IntentoLogin { get; set; }

    public virtual DbSet<Modulo> Modulo { get; set; }

    public virtual DbSet<Pago> Pago { get; set; }

    public virtual DbSet<Parametro> Parametro { get; set; }

    public virtual DbSet<Pedido> Pedido { get; set; }

    public virtual DbSet<PedidoDetalle> PedidoDetalle { get; set; }

    public virtual DbSet<PedidoHistorial> PedidoHistorial { get; set; }

    public virtual DbSet<Persona> Persona { get; set; }

    public virtual DbSet<Piso> Piso { get; set; }

    public virtual DbSet<Planilla> Planilla { get; set; }

    public virtual DbSet<PlanillaDetalle> PlanillaDetalle { get; set; }

    public virtual DbSet<PoliticaCancelacion> PoliticaCancelacion { get; set; }

    public virtual DbSet<ProductoMenu> ProductoMenu { get; set; }

    public virtual DbSet<Puesto> Puesto { get; set; }

    public virtual DbSet<RefreshToken> RefreshToken { get; set; }

    public virtual DbSet<RegistroHoras> RegistroHoras { get; set; }

    public virtual DbSet<Reserva> Reserva { get; set; }

    public virtual DbSet<ReservaHabitacion> ReservaHabitacion { get; set; }

    public virtual DbSet<ReservaHabitacionNoche> ReservaHabitacionNoche { get; set; }

    public virtual DbSet<Rol> Rol { get; set; }

    public virtual DbSet<RolModulo> RolModulo { get; set; }

    public virtual DbSet<TarjetaHabitacion> TarjetaHabitacion { get; set; }

    public virtual DbSet<Temporada> Temporada { get; set; }

    public virtual DbSet<TipoHabitacion> TipoHabitacion { get; set; }

    public virtual DbSet<TipoHabitacionAmenidad> TipoHabitacionAmenidad { get; set; }

    public virtual DbSet<TransicionEstado> TransicionEstado { get; set; }

    public virtual DbSet<Usuario> Usuario { get; set; }

    public virtual DbSet<UsuarioRol> UsuarioRol { get; set; }

    public virtual DbSet<vw_AmenidadesHabitacion> vw_AmenidadesHabitacion { get; set; }

    public virtual DbSet<vw_OcupacionHoy> vw_OcupacionHoy { get; set; }

    public virtual DbSet<vw_SeguimientoPedido> vw_SeguimientoPedido { get; set; }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        modelBuilder.UseCollation("Modern_Spanish_CI_AS");

        modelBuilder.Entity<Abono>(entity =>
        {
            entity.HasKey(e => e.IdAbono);

            entity.ToTable("Abono", "res");

            entity.HasIndex(e => new { e.Estado, e.FechaLimite }, "IX_Abono_Vencimiento");

            entity.HasIndex(e => new { e.IdReserva, e.Numero }, "UQ_Abono_Numero").IsUnique();

            entity.Property(e => e.Concepto)
                .HasMaxLength(8)
                .IsUnicode(false);
            entity.Property(e => e.Estado)
                .HasMaxLength(9)
                .IsUnicode(false)
                .HasDefaultValue("PENDIENTE");
            entity.Property(e => e.FechaLimite).HasPrecision(0);
            entity.Property(e => e.FechaPago).HasPrecision(0);
            entity.Property(e => e.MontoPagado).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.MontoProgramado).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.SaldoPendiente)
                .HasComputedColumnSql("(CONVERT([decimal](12,2),[MontoProgramado]-[MontoPagado]))", false)
                .HasColumnType("decimal(12, 2)");

            entity.HasOne(d => d.IdReservaNavigation).WithMany(p => p.Abono)
                .HasForeignKey(d => d.IdReserva)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Abono_Reserva");
        });

        modelBuilder.Entity<AccesoHabitacion>(entity =>
        {
            entity.HasKey(e => e.IdAcceso).HasName("PK_Acceso");

            entity.ToTable("AccesoHabitacion", "hab");

            entity.Property(e => e.Fecha)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.Medio)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.Motivo)
                .HasMaxLength(100)
                .IsUnicode(false);

            entity.HasOne(d => d.IdHabitacionNavigation).WithMany(p => p.AccesoHabitacion)
                .HasForeignKey(d => d.IdHabitacion)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Acceso_Hab");

            entity.HasOne(d => d.IdTarjetaNavigation).WithMany(p => p.AccesoHabitacion)
                .HasForeignKey(d => d.IdTarjeta)
                .HasConstraintName("FK_Acceso_Tarjeta");
        });

        modelBuilder.Entity<Amenidad>(entity =>
        {
            entity.HasKey(e => e.IdAmenidad);

            entity.ToTable("Amenidad", "hab");

            entity.HasIndex(e => e.Codigo, "UQ_Amenidad_Codigo").IsUnique();

            entity.Property(e => e.Activa).HasDefaultValue(true);
            entity.Property(e => e.Codigo)
                .HasMaxLength(30)
                .IsUnicode(false);
            entity.Property(e => e.Descripcion).HasMaxLength(200);
            entity.Property(e => e.Nombre).HasMaxLength(60);
        });

        modelBuilder.Entity<Bitacora>(entity =>
        {
            entity.HasKey(e => e.IdBitacora);

            entity.ToTable("Bitacora", "aud", tb => tb.HasTrigger("trg_Bitacora_Inmutable"));

            entity.HasIndex(e => new { e.Tabla, e.IdRegistro }, "IX_Bitacora");

            entity.Property(e => e.DatosAnteriores).IsUnicode(false);
            entity.Property(e => e.DatosNuevos).IsUnicode(false);
            entity.Property(e => e.Fecha)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.Operacion)
                .HasMaxLength(6)
                .IsUnicode(false);
            entity.Property(e => e.Tabla).HasMaxLength(128);
            entity.Property(e => e.UsuarioBD)
                .HasMaxLength(128)
                .HasDefaultValueSql("(original_login())");
        });

        modelBuilder.Entity<BloqueoHabitacion>(entity =>
        {
            entity.HasKey(e => e.IdBloqueo);

            entity.ToTable("BloqueoHabitacion", "hab", tb => tb.HasTrigger("trg_Bloqueo_Validar"));

            entity.HasIndex(e => new { e.IdHabitacion, e.FechaDesde, e.FechaHasta }, "IX_Bloqueo_Hab").HasFilter("([Activo]=(1))");

            entity.Property(e => e.Activo).HasDefaultValue(true);
            entity.Property(e => e.FechaCreacion)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.Motivo)
                .HasMaxLength(200)
                .IsUnicode(false);

            entity.HasOne(d => d.CreadoPorNavigation).WithMany(p => p.BloqueoHabitacion)
                .HasForeignKey(d => d.CreadoPor)
                .HasConstraintName("FK_Bloqueo_Usuario");

            entity.HasOne(d => d.IdHabitacionNavigation).WithMany(p => p.BloqueoHabitacion)
                .HasForeignKey(d => d.IdHabitacion)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Bloqueo_Habitacion");
        });

        modelBuilder.Entity<Cancelacion>(entity =>
        {
            entity.HasKey(e => e.IdCancelacion);

            entity.ToTable("Cancelacion", "res", tb => tb.HasTrigger("trg_Cancelacion_Inmutable"));

            entity.HasIndex(e => e.IdReserva, "UQ_Cancelacion_Reserva").IsUnique();

            entity.Property(e => e.FechaCancelacion)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.MontoPagado).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.MontoReembolso).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.MontoRetenido).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.Motivo)
                .HasMaxLength(300)
                .IsUnicode(false);
            entity.Property(e => e.PorcentajeAplicado).HasColumnType("decimal(5, 2)");
            entity.Property(e => e.PorcentajePolitica).HasColumnType("decimal(5, 2)");

            entity.HasOne(d => d.CanceladoPorNavigation).WithMany(p => p.Cancelacion)
                .HasForeignKey(d => d.CanceladoPor)
                .HasConstraintName("FK_Cancelacion_Usuario");

            entity.HasOne(d => d.IdPoliticaNavigation).WithMany(p => p.Cancelacion)
                .HasForeignKey(d => d.IdPolitica)
                .HasConstraintName("FK_Cancelacion_Politica");

            entity.HasOne(d => d.IdReservaNavigation).WithOne(p => p.Cancelacion)
                .HasForeignKey<Cancelacion>(d => d.IdReserva)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Cancelacion_Reserva");
        });

        modelBuilder.Entity<CategoriaMenu>(entity =>
        {
            entity.HasKey(e => e.IdCategoria);

            entity.ToTable("CategoriaMenu", "coc");

            entity.HasIndex(e => e.Nombre, "UQ_CategoriaMenu").IsUnique();

            entity.Property(e => e.Activa).HasDefaultValue(true);
            entity.Property(e => e.Nombre).HasMaxLength(50);
        });

        modelBuilder.Entity<Cliente>(entity =>
        {
            entity.HasKey(e => e.IdCliente);

            entity.ToTable("Cliente", "res");

            entity.Property(e => e.IdCliente).ValueGeneratedNever();
            entity.Property(e => e.Activo).HasDefaultValue(true);
            entity.Property(e => e.FechaRegistro)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");

            entity.HasOne(d => d.IdClienteNavigation).WithOne(p => p.Cliente)
                .HasForeignKey<Cliente>(d => d.IdCliente)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Cliente_Persona");
        });

        modelBuilder.Entity<ColaCorreo>(entity =>
        {
            entity.HasKey(e => e.IdCorreo);

            entity.HasIndex(e => e.FechaCreacion, "IX_ColaCorreo_Pend").HasFilter("([Estado]='PENDIENTE')");

            entity.Property(e => e.Asunto).HasMaxLength(200);
            entity.Property(e => e.Destinatario)
                .HasMaxLength(150)
                .IsUnicode(false);
            entity.Property(e => e.Estado)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasDefaultValue("PENDIENTE");
            entity.Property(e => e.FechaCreacion)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.FechaEnvio).HasPrecision(0);
            entity.Property(e => e.Tipo)
                .HasMaxLength(30)
                .IsUnicode(false);
            entity.Property(e => e.UltimoError)
                .HasMaxLength(500)
                .IsUnicode(false);
        });

        modelBuilder.Entity<ConsecutivoDocumento>(entity =>
        {
            entity.HasKey(e => e.TipoDocumento);

            entity.ToTable("ConsecutivoDocumento", "fac");

            entity.Property(e => e.TipoDocumento)
                .HasMaxLength(2)
                .IsUnicode(false);
        });

        modelBuilder.Entity<Descuento>(entity =>
        {
            entity.HasKey(e => e.IdDescuento);

            entity.ToTable("Descuento", "res", tb => tb.HasTrigger("trg_Descuento_Control"));

            entity.HasIndex(e => e.Codigo, "UX_Descuento_Codigo")
                .IsUnique()
                .HasFilter("([Codigo] IS NOT NULL)");

            entity.Property(e => e.Activo).HasDefaultValue(true);
            entity.Property(e => e.AplicaA)
                .HasMaxLength(19)
                .IsUnicode(false);
            entity.Property(e => e.Clase)
                .HasMaxLength(17)
                .IsUnicode(false);
            entity.Property(e => e.Codigo)
                .HasMaxLength(30)
                .IsUnicode(false);
            entity.Property(e => e.FechaCreacion)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.Nombre)
                .HasMaxLength(80)
                .IsUnicode(false);
            entity.Property(e => e.Tipo)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.Valor).HasColumnType("decimal(12, 2)");

            entity.HasOne(d => d.IdTemporadaNavigation).WithMany(p => p.Descuento)
                .HasForeignKey(d => d.IdTemporada)
                .HasConstraintName("FK_Descuento_Temporada");
        });

        modelBuilder.Entity<Edificio>(entity =>
        {
            entity.HasKey(e => e.IdEdificio);

            entity.ToTable("Edificio", "hab");

            entity.HasIndex(e => e.Codigo, "UQ_Edificio_Codigo").IsUnique();

            entity.HasIndex(e => e.Numero, "UQ_Edificio_Numero").IsUnique();

            entity.Property(e => e.Codigo)
                .HasMaxLength(1)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.Nombre)
                .HasMaxLength(50)
                .IsUnicode(false);
        });

        modelBuilder.Entity<Empleado>(entity =>
        {
            entity.HasKey(e => e.IdEmpleado);

            entity.ToTable("Empleado", "rh", tb => tb.HasTrigger("trg_Empleado_Validar"));

            entity.Property(e => e.IdEmpleado).ValueGeneratedNever();
            entity.Property(e => e.Activo).HasDefaultValue(true);
            entity.Property(e => e.CuentaIBAN)
                .HasMaxLength(22)
                .IsUnicode(false);
            entity.Property(e => e.MontoSalario).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.TipoSalario)
                .HasMaxLength(10)
                .IsUnicode(false);

            entity.HasOne(d => d.IdEmpleadoNavigation).WithOne(p => p.Empleado)
                .HasForeignKey<Empleado>(d => d.IdEmpleado)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Empleado_Persona");

            entity.HasOne(d => d.IdPuestoNavigation).WithMany(p => p.Empleado)
                .HasForeignKey(d => d.IdPuesto)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Empleado_Puesto");
        });

        modelBuilder.Entity<Factura>(entity =>
        {
            entity.HasKey(e => e.IdFactura);

            entity.ToTable("Factura", "fac", tb =>
                {
                    tb.HasTrigger("trg_Factura_Control");
                    tb.HasTrigger("trg_Factura_NoBorrar");
                });

            entity.HasIndex(e => new { e.EstadoHacienda, e.FechaEmision }, "IX_Factura_Hacienda").HasFilter("([EstadoHacienda] IN ('PENDIENTE', 'ENVIADA'))");

            entity.HasIndex(e => e.Clave, "UQ_Factura_Clave").IsUnique();

            entity.HasIndex(e => e.Consecutivo, "UQ_Factura_Consecutivo").IsUnique();

            entity.HasIndex(e => e.IdFacturaReferencia, "UX_Factura_NC")
                .IsUnique()
                .HasFilter("([IdFacturaReferencia] IS NOT NULL)");

            entity.HasIndex(e => e.IdReserva, "UX_Factura_ReservaVigente")
                .IsUnique()
                .HasFilter("([Estado]<>'ANULADA' AND [TipoDocumento]<>'NC')");

            entity.Property(e => e.Clave)
                .HasMaxLength(50)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.CodigoActividad)
                .HasMaxLength(6)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.CodigoReferencia)
                .HasMaxLength(2)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.CondicionVenta)
                .HasMaxLength(2)
                .IsUnicode(false)
                .HasDefaultValue("01")
                .IsFixedLength();
            entity.Property(e => e.Consecutivo)
                .HasMaxLength(20)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.Descuento).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.Estado)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasDefaultValue("EMITIDA");
            entity.Property(e => e.EstadoHacienda)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasDefaultValue("PENDIENTE");
            entity.Property(e => e.FechaAnulacion).HasPrecision(0);
            entity.Property(e => e.FechaEmision)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.FechaEnvioHacienda).HasPrecision(0);
            entity.Property(e => e.FechaRespuestaHacienda).HasPrecision(0);
            entity.Property(e => e.Impuesto).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.MedioPago)
                .HasMaxLength(2)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.MensajeHacienda)
                .HasMaxLength(500)
                .IsUnicode(false);
            entity.Property(e => e.Moneda)
                .HasMaxLength(3)
                .IsUnicode(false)
                .HasDefaultValue("CRC")
                .IsFixedLength();
            entity.Property(e => e.MotivoAnulacion)
                .HasMaxLength(300)
                .IsUnicode(false);
            entity.Property(e => e.NumeroFactura)
                .HasMaxLength(12)
                .IsUnicode(false)
                .HasComputedColumnSql("('FAC-'+right('00000000'+CONVERT([varchar](10),[IdFactura]),(8)))", true);
            entity.Property(e => e.RazonReferencia)
                .HasMaxLength(180)
                .IsUnicode(false);
            entity.Property(e => e.ReceptorCorreo)
                .HasMaxLength(150)
                .IsUnicode(false);
            entity.Property(e => e.ReceptorIdentificacion)
                .HasMaxLength(30)
                .IsUnicode(false);
            entity.Property(e => e.ReceptorNombre)
                .HasMaxLength(160)
                .IsUnicode(false);
            entity.Property(e => e.ReceptorTipoId)
                .HasMaxLength(15)
                .IsUnicode(false);
            entity.Property(e => e.Subtotal).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.TipoCambio)
                .HasDefaultValue(1m)
                .HasColumnType("decimal(18, 5)");
            entity.Property(e => e.TipoDocumento)
                .HasMaxLength(2)
                .IsUnicode(false);
            entity.Property(e => e.TipoFactura)
                .HasMaxLength(12)
                .IsUnicode(false);
            entity.Property(e => e.Total).HasColumnType("decimal(12, 2)");

            entity.HasOne(d => d.AnuladaPorNavigation).WithMany(p => p.FacturaAnuladaPorNavigation)
                .HasForeignKey(d => d.AnuladaPor)
                .HasConstraintName("FK_Factura_Anulador");

            entity.HasOne(d => d.EmitidaPorNavigation).WithMany(p => p.FacturaEmitidaPorNavigation)
                .HasForeignKey(d => d.EmitidaPor)
                .HasConstraintName("FK_Factura_Emisor");

            entity.HasOne(d => d.IdClienteNavigation).WithMany(p => p.Factura)
                .HasForeignKey(d => d.IdCliente)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Factura_Cliente");

            entity.HasOne(d => d.IdFacturaReferenciaNavigation).WithOne(p => p.InverseIdFacturaReferenciaNavigation)
                .HasForeignKey<Factura>(d => d.IdFacturaReferencia)
                .HasConstraintName("FK_Factura_Referencia");

            entity.HasOne(d => d.IdReservaNavigation).WithOne(p => p.Factura)
                .HasForeignKey<Factura>(d => d.IdReserva)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Factura_Reserva");
        });

        modelBuilder.Entity<FacturaDetalle>(entity =>
        {
            entity.HasKey(e => e.IdFacturaDetalle);

            entity.ToTable("FacturaDetalle", "fac", tb =>
                {
                    tb.HasTrigger("trg_FacturaDetalle_Inmutable");
                    tb.HasTrigger("trg_FacturaDetalle_Insertar");
                });

            entity.HasIndex(e => e.IdPedido, "IX_FD_Pedido").HasFilter("([IdPedido] IS NOT NULL)");

            entity.HasIndex(e => new { e.IdFactura, e.NumeroLinea }, "UQ_FD_Linea").IsUnique();

            entity.Property(e => e.Cantidad).HasColumnType("decimal(10, 2)");
            entity.Property(e => e.CodigoCabys)
                .HasMaxLength(13)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.Descripcion)
                .HasMaxLength(200)
                .IsUnicode(false);
            entity.Property(e => e.MontoDescuento).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.MontoImpuesto)
                .HasComputedColumnSql("(CONVERT([decimal](12,2),round(((CONVERT([decimal](12,2),[Cantidad]*[PrecioUnitario])-[MontoDescuento])*[PorcentajeImpuesto])/(100),(2))))", true)
                .HasColumnType("decimal(12, 2)");
            entity.Property(e => e.MontoTotal)
                .HasComputedColumnSql("(CONVERT([decimal](12,2),[Cantidad]*[PrecioUnitario]))", true)
                .HasColumnType("decimal(12, 2)");
            entity.Property(e => e.NaturalezaDescuento)
                .HasMaxLength(80)
                .IsUnicode(false);
            entity.Property(e => e.PorcentajeDescuento).HasColumnType("decimal(5, 2)");
            entity.Property(e => e.PorcentajeImpuesto).HasColumnType("decimal(5, 2)");
            entity.Property(e => e.PrecioUnitario).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.SubTotal)
                .HasComputedColumnSql("(CONVERT([decimal](12,2),CONVERT([decimal](12,2),[Cantidad]*[PrecioUnitario])-[MontoDescuento]))", true)
                .HasColumnType("decimal(12, 2)");
            entity.Property(e => e.TipoLinea)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.TotalLinea)
                .HasComputedColumnSql("(CONVERT([decimal](12,2),(CONVERT([decimal](12,2),[Cantidad]*[PrecioUnitario])-[MontoDescuento])+round(((CONVERT([decimal](12,2),[Cantidad]*[PrecioUnitario])-[MontoDescuento])*[PorcentajeImpuesto])/(100),(2))))", true)
                .HasColumnType("decimal(12, 2)");
            entity.Property(e => e.UnidadMedida)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasDefaultValue("Unid");

            entity.HasOne(d => d.IdDescuentoNavigation).WithMany(p => p.FacturaDetalle)
                .HasForeignKey(d => d.IdDescuento)
                .HasConstraintName("FK_FD_Descuento");

            entity.HasOne(d => d.IdFacturaNavigation).WithMany(p => p.FacturaDetalle)
                .HasForeignKey(d => d.IdFactura)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_FD_Factura");

            entity.HasOne(d => d.IdPedidoNavigation).WithMany(p => p.FacturaDetalle)
                .HasForeignKey(d => d.IdPedido)
                .HasConstraintName("FK_FD_Pedido");

            entity.HasOne(d => d.IdReservaHabitacionNavigation).WithMany(p => p.FacturaDetalle)
                .HasForeignKey(d => d.IdReservaHabitacion)
                .HasConstraintName("FK_FD_RH");
        });

        modelBuilder.Entity<Habitacion>(entity =>
        {
            entity.HasKey(e => e.IdHabitacion);

            entity.ToTable("Habitacion", "hab");

            entity.HasIndex(e => e.Codigo, "UQ_Habitacion_Codigo").IsUnique();

            entity.HasIndex(e => new { e.IdPiso, e.NumeroEnPiso }, "UQ_Habitacion_PisoNumero").IsUnique();

            entity.Property(e => e.Activa).HasDefaultValue(true);
            entity.Property(e => e.Codigo)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.Estado)
                .HasMaxLength(15)
                .IsUnicode(false)
                .HasDefaultValue("DISPONIBLE");
            entity.Property(e => e.RowVer)
                .IsRowVersion()
                .IsConcurrencyToken();

            entity.HasOne(d => d.IdPisoNavigation).WithMany(p => p.Habitacion)
                .HasForeignKey(d => d.IdPiso)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Habitacion_Piso");

            entity.HasOne(d => d.IdTipoHabitacionNavigation).WithMany(p => p.Habitacion)
                .HasForeignKey(d => d.IdTipoHabitacion)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Habitacion_Tipo");
        });

        modelBuilder.Entity<HabitacionAmenidad>(entity =>
        {
            entity.HasKey(e => e.IdHabitacionAmenidad);

            entity.ToTable("HabitacionAmenidad", "hab");

            entity.HasIndex(e => new { e.IdHabitacion, e.IdAmenidad }, "UQ_HabitacionAmenidad").IsUnique();

            entity.HasOne(d => d.IdAmenidadNavigation).WithMany(p => p.HabitacionAmenidad)
                .HasForeignKey(d => d.IdAmenidad)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_HA_Amenidad");

            entity.HasOne(d => d.IdHabitacionNavigation).WithMany(p => p.HabitacionAmenidad)
                .HasForeignKey(d => d.IdHabitacion)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_HA_Habitacion");
        });

        modelBuilder.Entity<Huesped>(entity =>
        {
            entity.HasKey(e => e.IdHuesped);

            entity.ToTable("Huesped", "res", tb => tb.HasTrigger("trg_Huesped_Capacidad"));

            entity.Property(e => e.Identificacion)
                .HasMaxLength(30)
                .IsUnicode(false);
            entity.Property(e => e.NombreCompleto)
                .HasMaxLength(120)
                .IsUnicode(false);
            entity.Property(e => e.TipoIdentificacion)
                .HasMaxLength(15)
                .IsUnicode(false);

            entity.HasOne(d => d.IdReservaHabitacionNavigation).WithMany(p => p.Huesped)
                .HasForeignKey(d => d.IdReservaHabitacion)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Huesped_RH");
        });

        modelBuilder.Entity<IntentoLogin>(entity =>
        {
            entity.HasKey(e => e.IdIntento);

            entity.ToTable("IntentoLogin", "seg");

            entity.HasIndex(e => new { e.LoginIngresado, e.Fecha }, "IX_IntentoLogin");

            entity.HasIndex(e => new { e.IpOrigen, e.Fecha }, "IX_IntentoLogin_Ip");

            entity.Property(e => e.Dispositivo)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.Fecha)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.IpOrigen)
                .HasMaxLength(45)
                .IsUnicode(false);
            entity.Property(e => e.LoginIngresado)
                .HasMaxLength(150)
                .IsUnicode(false);
            entity.Property(e => e.Origen)
                .HasMaxLength(3)
                .IsUnicode(false);

            entity.HasOne(d => d.IdUsuarioNavigation).WithMany(p => p.IntentoLogin)
                .HasForeignKey(d => d.IdUsuario)
                .HasConstraintName("FK_IntentoLogin_Usuario");
        });

        modelBuilder.Entity<Modulo>(entity =>
        {
            entity.HasKey(e => e.IdModulo);

            entity.ToTable("Modulo", "seg");

            entity.HasIndex(e => e.Codigo, "UQ_Modulo_Codigo").IsUnique();

            entity.Property(e => e.Activo).HasDefaultValue(true);
            entity.Property(e => e.Codigo)
                .HasMaxLength(30)
                .IsUnicode(false);
            entity.Property(e => e.Nombre)
                .HasMaxLength(60)
                .IsUnicode(false);
        });

        modelBuilder.Entity<Pago>(entity =>
        {
            entity.HasKey(e => e.IdPago);

            entity.ToTable("Pago", "res", tb =>
                {
                    tb.HasTrigger("trg_Pago_NoBorrar");
                    tb.HasTrigger("trg_Pago_Procesar");
                });

            entity.HasIndex(e => e.IdReserva, "IX_Pago_Reserva");

            entity.Property(e => e.Fecha)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.Metodo)
                .HasMaxLength(15)
                .IsUnicode(false);
            entity.Property(e => e.Monto).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.Referencia)
                .HasMaxLength(50)
                .IsUnicode(false);
            entity.Property(e => e.TipoMovimiento)
                .HasMaxLength(12)
                .IsUnicode(false);

            entity.HasOne(d => d.IdFacturaNavigation).WithMany(p => p.Pago)
                .HasForeignKey(d => d.IdFactura)
                .HasConstraintName("FK_Pago_Factura");

            entity.HasOne(d => d.IdReservaNavigation).WithMany(p => p.Pago)
                .HasForeignKey(d => d.IdReserva)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Pago_Reserva");

            entity.HasOne(d => d.RegistradoPorNavigation).WithMany(p => p.Pago)
                .HasForeignKey(d => d.RegistradoPor)
                .HasConstraintName("FK_Pago_Usuario");
        });

        modelBuilder.Entity<Parametro>(entity =>
        {
            entity.HasKey(e => e.Clave);

            entity.Property(e => e.Clave)
                .HasMaxLength(50)
                .IsUnicode(false);
            entity.Property(e => e.Descripcion)
                .HasMaxLength(200)
                .IsUnicode(false);
            entity.Property(e => e.Valor).HasColumnType("decimal(18, 4)");
        });

        modelBuilder.Entity<Pedido>(entity =>
        {
            entity.HasKey(e => e.IdPedido);

            entity.ToTable("Pedido", "coc", tb =>
                {
                    tb.HasTrigger("trg_Pedido_NoBorrar");
                    tb.HasTrigger("trg_Pedido_Validar");
                });

            entity.HasIndex(e => new { e.Estado, e.FechaPedido }, "IX_Pedido_Estado");

            entity.HasIndex(e => e.IdReservaHabitacion, "IX_Pedido_RH");

            entity.Property(e => e.CargoServicio).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.Estado)
                .HasMaxLength(15)
                .IsUnicode(false)
                .HasDefaultValue("PENDIENTE");
            entity.Property(e => e.FechaCancelado).HasPrecision(0);
            entity.Property(e => e.FechaConfirmado).HasPrecision(0);
            entity.Property(e => e.FechaEmpaquetado).HasPrecision(0);
            entity.Property(e => e.FechaEnCamino).HasPrecision(0);
            entity.Property(e => e.FechaEntregado).HasPrecision(0);
            entity.Property(e => e.FechaPedido)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.FechaPreparacion).HasPrecision(0);
            entity.Property(e => e.Impuesto).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.MotivoCancelacion)
                .HasMaxLength(200)
                .IsUnicode(false);
            entity.Property(e => e.Notas)
                .HasMaxLength(300)
                .IsUnicode(false);
            entity.Property(e => e.RowVer)
                .IsRowVersion()
                .IsConcurrencyToken();
            entity.Property(e => e.Subtotal).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.Total)
                .HasComputedColumnSql("(([Subtotal]+[CargoServicio])+[Impuesto])", true)
                .HasColumnType("decimal(14, 2)");

            entity.HasOne(d => d.IdHabitacionNavigation).WithMany(p => p.Pedido)
                .HasForeignKey(d => d.IdHabitacion)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Pedido_Hab");

            entity.HasOne(d => d.IdReservaHabitacionNavigation).WithMany(p => p.Pedido)
                .HasForeignKey(d => d.IdReservaHabitacion)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Pedido_RH");

            entity.HasOne(d => d.IdUsuarioCocinaNavigation).WithMany(p => p.PedidoIdUsuarioCocinaNavigation)
                .HasForeignKey(d => d.IdUsuarioCocina)
                .HasConstraintName("FK_Pedido_Cocina");

            entity.HasOne(d => d.IdUsuarioEntregaNavigation).WithMany(p => p.PedidoIdUsuarioEntregaNavigation)
                .HasForeignKey(d => d.IdUsuarioEntrega)
                .HasConstraintName("FK_Pedido_Entrega");
        });

        modelBuilder.Entity<PedidoDetalle>(entity =>
        {
            entity.HasKey(e => e.IdPedidoDetalle);

            entity.ToTable("PedidoDetalle", "coc", tb => tb.HasTrigger("trg_PedidoDetalle_Validar"));

            entity.HasIndex(e => new { e.IdPedido, e.IdProducto }, "UQ_PedidoDetalle").IsUnique();

            entity.Property(e => e.Notas)
                .HasMaxLength(150)
                .IsUnicode(false);
            entity.Property(e => e.PrecioUnitario).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.Subtotal)
                .HasComputedColumnSql("(CONVERT([decimal](12,2),[Cantidad]*[PrecioUnitario]))", true)
                .HasColumnType("decimal(12, 2)");

            entity.HasOne(d => d.IdPedidoNavigation).WithMany(p => p.PedidoDetalle)
                .HasForeignKey(d => d.IdPedido)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_PD_Pedido");

            entity.HasOne(d => d.IdProductoNavigation).WithMany(p => p.PedidoDetalle)
                .HasForeignKey(d => d.IdProducto)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_PD_Producto");
        });

        modelBuilder.Entity<PedidoHistorial>(entity =>
        {
            entity.HasKey(e => e.IdHistorial);

            entity.ToTable("PedidoHistorial", "coc");

            entity.Property(e => e.EstadoAnterior)
                .HasMaxLength(15)
                .IsUnicode(false);
            entity.Property(e => e.EstadoNuevo)
                .HasMaxLength(15)
                .IsUnicode(false);
            entity.Property(e => e.Fecha)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");

            entity.HasOne(d => d.IdPedidoNavigation).WithMany(p => p.PedidoHistorial)
                .HasForeignKey(d => d.IdPedido)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_PH_Pedido");
        });

        modelBuilder.Entity<Persona>(entity =>
        {
            entity.HasKey(e => e.IdPersona);

            entity.HasIndex(e => e.Correo, "UQ_Persona_Correo").IsUnique();

            entity.HasIndex(e => new { e.TipoIdentificacion, e.Identificacion }, "UQ_Persona_Identificacion").IsUnique();

            entity.Property(e => e.Apellidos)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.Correo)
                .HasMaxLength(150)
                .IsUnicode(false);
            entity.Property(e => e.FechaRegistro)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.Identificacion)
                .HasMaxLength(30)
                .IsUnicode(false);
            entity.Property(e => e.Nombre)
                .HasMaxLength(60)
                .IsUnicode(false);
            entity.Property(e => e.Telefono)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.TipoIdentificacion)
                .HasMaxLength(15)
                .IsUnicode(false);
        });

        modelBuilder.Entity<Piso>(entity =>
        {
            entity.HasKey(e => e.IdPiso);

            entity.ToTable("Piso", "hab");

            entity.HasIndex(e => new { e.IdEdificio, e.Numero }, "UQ_Piso").IsUnique();

            entity.HasOne(d => d.IdEdificioNavigation).WithMany(p => p.Piso)
                .HasForeignKey(d => d.IdEdificio)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Piso_Edificio");
        });

        modelBuilder.Entity<Planilla>(entity =>
        {
            entity.HasKey(e => e.IdPlanilla);

            entity.ToTable("Planilla", "rh", tb => tb.HasTrigger("trg_Planilla_Control"));

            entity.HasIndex(e => new { e.TipoPeriodo, e.FechaInicio }, "UX_Planilla_Periodo")
                .IsUnique()
                .HasFilter("([Estado]<>'ANULADA')");

            entity.Property(e => e.Estado)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasDefaultValue("BORRADOR");
            entity.Property(e => e.FechaAprobacion).HasPrecision(0);
            entity.Property(e => e.FechaCreacion)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.TipoPeriodo)
                .HasMaxLength(10)
                .IsUnicode(false);

            entity.HasOne(d => d.AprobadaPorNavigation).WithMany(p => p.PlanillaAprobadaPorNavigation)
                .HasForeignKey(d => d.AprobadaPor)
                .HasConstraintName("FK_Planilla_Aprobador");

            entity.HasOne(d => d.CreadaPorNavigation).WithMany(p => p.PlanillaCreadaPorNavigation)
                .HasForeignKey(d => d.CreadaPor)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Planilla_Creador");
        });

        modelBuilder.Entity<PlanillaDetalle>(entity =>
        {
            entity.HasKey(e => e.IdPlanillaDetalle);

            entity.ToTable("PlanillaDetalle", "rh", tb => tb.HasTrigger("trg_PlanillaDetalle_Control"));

            entity.HasIndex(e => new { e.IdPlanilla, e.IdEmpleado }, "UQ_PlanillaDetalle").IsUnique();

            entity.Property(e => e.Bonificaciones).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.DeduccionCCSS)
                .HasComputedColumnSql("(CONVERT([decimal](12,2),round(((([SalarioBase]+[MontoHorasExtra])+[Bonificaciones])*[PorcentajeCCSS])/(100),(2))))", true)
                .HasColumnType("decimal(12, 2)");
            entity.Property(e => e.HorasExtra).HasColumnType("decimal(6, 2)");
            entity.Property(e => e.HorasOrdinarias).HasColumnType("decimal(6, 2)");
            entity.Property(e => e.ImpuestoRenta).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.MontoHorasExtra).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.OtrasDeducciones).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.PorcentajeCCSS).HasColumnType("decimal(5, 2)");
            entity.Property(e => e.SalarioBase).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.SalarioBruto)
                .HasComputedColumnSql("(([SalarioBase]+[MontoHorasExtra])+[Bonificaciones])", true)
                .HasColumnType("decimal(14, 2)");
            entity.Property(e => e.SalarioNeto)
                .HasComputedColumnSql("(CONVERT([decimal](12,2),(((([SalarioBase]+[MontoHorasExtra])+[Bonificaciones])-round(((([SalarioBase]+[MontoHorasExtra])+[Bonificaciones])*[PorcentajeCCSS])/(100),(2)))-[ImpuestoRenta])-[OtrasDeducciones]))", true)
                .HasColumnType("decimal(12, 2)");

            entity.HasOne(d => d.IdEmpleadoNavigation).WithMany(p => p.PlanillaDetalle)
                .HasForeignKey(d => d.IdEmpleado)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_PD_Empleado");

            entity.HasOne(d => d.IdPlanillaNavigation).WithMany(p => p.PlanillaDetalle)
                .HasForeignKey(d => d.IdPlanilla)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_PD_Planilla");
        });

        modelBuilder.Entity<PoliticaCancelacion>(entity =>
        {
            entity.HasKey(e => e.IdPolitica);

            entity.ToTable("PoliticaCancelacion", "res");

            entity.HasIndex(e => e.HorasMinimas, "UX_Politica_Horas")
                .IsUnique()
                .HasFilter("([Activa]=(1))");

            entity.Property(e => e.Activa).HasDefaultValue(true);
            entity.Property(e => e.Nombre)
                .HasMaxLength(80)
                .IsUnicode(false);
            entity.Property(e => e.PorcentajePenalizacion).HasColumnType("decimal(5, 2)");
        });

        modelBuilder.Entity<ProductoMenu>(entity =>
        {
            entity.HasKey(e => e.IdProducto);

            entity.ToTable("ProductoMenu", "coc");

            entity.HasIndex(e => e.Nombre, "UQ_ProductoMenu").IsUnique();

            entity.Property(e => e.CodigoCabys)
                .HasMaxLength(13)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.Descripcion).HasMaxLength(300);
            entity.Property(e => e.Disponible).HasDefaultValue(true);
            entity.Property(e => e.Nombre).HasMaxLength(80);
            entity.Property(e => e.Precio).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.RowVer)
                .IsRowVersion()
                .IsConcurrencyToken();

            entity.HasOne(d => d.IdCategoriaNavigation).WithMany(p => p.ProductoMenu)
                .HasForeignKey(d => d.IdCategoria)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Producto_Categoria");
        });

        modelBuilder.Entity<Puesto>(entity =>
        {
            entity.HasKey(e => e.IdPuesto);

            entity.ToTable("Puesto", "rh");

            entity.HasIndex(e => e.Nombre, "UQ_Puesto").IsUnique();

            entity.Property(e => e.Activo).HasDefaultValue(true);
            entity.Property(e => e.Nombre)
                .HasMaxLength(60)
                .IsUnicode(false);

            entity.HasOne(d => d.IdRolNavigation).WithMany(p => p.Puesto)
                .HasForeignKey(d => d.IdRol)
                .HasConstraintName("FK_Puesto_Rol");
        });

        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.HasKey(e => e.IdRefreshToken);

            entity.ToTable("RefreshToken", "seg");

            entity.HasIndex(e => e.IdUsuario, "IX_RefreshToken_Usr").HasFilter("([FechaRevocacion] IS NULL)");

            entity.HasIndex(e => e.TokenHash, "UQ_RefreshToken_Hash").IsUnique();

            entity.Property(e => e.Dispositivo)
                .HasMaxLength(100)
                .IsUnicode(false);
            entity.Property(e => e.FechaCreacion)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.FechaExpiracion).HasPrecision(0);
            entity.Property(e => e.FechaRevocacion).HasPrecision(0);
            entity.Property(e => e.IpOrigen)
                .HasMaxLength(45)
                .IsUnicode(false);
            entity.Property(e => e.ReemplazadoPor)
                .HasMaxLength(32)
                .IsFixedLength();
            entity.Property(e => e.TokenHash)
                .HasMaxLength(32)
                .IsFixedLength();

            entity.HasOne(d => d.IdUsuarioNavigation).WithMany(p => p.RefreshToken)
                .HasForeignKey(d => d.IdUsuario)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_RefreshToken_Usuario");
        });

        modelBuilder.Entity<RegistroHoras>(entity =>
        {
            entity.HasKey(e => e.IdRegistro);

            entity.ToTable("RegistroHoras", "rh");

            entity.HasIndex(e => new { e.IdEmpleado, e.Fecha }, "UQ_RegistroHoras").IsUnique();

            entity.Property(e => e.HorasExtra).HasColumnType("decimal(4, 2)");
            entity.Property(e => e.HorasOrdinarias).HasColumnType("decimal(4, 2)");

            entity.HasOne(d => d.AprobadoPorNavigation).WithMany(p => p.RegistroHoras)
                .HasForeignKey(d => d.AprobadoPor)
                .HasConstraintName("FK_Horas_Usuario");

            entity.HasOne(d => d.IdEmpleadoNavigation).WithMany(p => p.RegistroHoras)
                .HasForeignKey(d => d.IdEmpleado)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Horas_Empleado");
        });

        modelBuilder.Entity<Reserva>(entity =>
        {
            entity.HasKey(e => e.IdReserva);

            entity.ToTable("Reserva", "res", tb =>
                {
                    tb.HasTrigger("trg_Reserva_NoBorrar");
                    tb.HasTrigger("trg_Reserva_Validar");
                });

            entity.HasIndex(e => new { e.IdCliente, e.Estado }, "IX_Reserva_Cliente");

            entity.HasIndex(e => new { e.IdDescuento, e.Estado }, "IX_Reserva_Descuento").HasFilter("([IdDescuento] IS NOT NULL)");

            entity.HasIndex(e => new { e.Estado, e.FechaExpiracion, e.FechaEntrada }, "IX_Reserva_Estado");

            entity.Property(e => e.AnticipoRequerido).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.Canal)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.CodigoReserva)
                .HasMaxLength(11)
                .IsUnicode(false)
                .HasComputedColumnSql("('RES-'+right('0000000'+CONVERT([varchar](10),[IdReserva]),(7)))", true);
            entity.Property(e => e.Estado)
                .HasMaxLength(12)
                .IsUnicode(false)
                .HasDefaultValue("PENDIENTE");
            entity.Property(e => e.FechaCreacion)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.FechaExpiracion).HasPrecision(0);
            entity.Property(e => e.FechaModificacion).HasPrecision(0);
            entity.Property(e => e.MontoDescuento).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.MontoImpuesto).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.MontoPagado).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.Observaciones)
                .HasMaxLength(500)
                .IsUnicode(false);
            entity.Property(e => e.PorcentajeAnticipo).HasColumnType("decimal(5, 2)");
            entity.Property(e => e.RowVer)
                .IsRowVersion()
                .IsConcurrencyToken();
            entity.Property(e => e.SaldoAnticipo)
                .HasComputedColumnSql("(case when [AnticipoRequerido]>[MontoPagado] then [AnticipoRequerido]-[MontoPagado] else (0) end)", false)
                .HasColumnType("decimal(13, 2)");
            entity.Property(e => e.SaldoTotal)
                .HasComputedColumnSql("(case when [Total]>[MontoPagado] then [Total]-[MontoPagado] else (0) end)", false)
                .HasColumnType("decimal(13, 2)");
            entity.Property(e => e.Subtotal).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.Total).HasColumnType("decimal(12, 2)");

            entity.HasOne(d => d.CreadoPorNavigation).WithMany(p => p.Reserva)
                .HasForeignKey(d => d.CreadoPor)
                .HasConstraintName("FK_Reserva_Usuario");

            entity.HasOne(d => d.IdClienteNavigation).WithMany(p => p.Reserva)
                .HasForeignKey(d => d.IdCliente)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Reserva_Cliente");

            entity.HasOne(d => d.IdDescuentoNavigation).WithMany(p => p.Reserva)
                .HasForeignKey(d => d.IdDescuento)
                .HasConstraintName("FK_Reserva_Descuento");
        });

        modelBuilder.Entity<ReservaHabitacion>(entity =>
        {
            entity.HasKey(e => e.IdReservaHabitacion);

            entity.ToTable("ReservaHabitacion", "res", tb =>
                {
                    tb.HasTrigger("trg_ReservaHab_NoBorrar");
                    tb.HasTrigger("trg_ReservaHabitacion_Validar");
                });

            entity.HasIndex(e => new { e.IdHabitacion, e.FechaDesde, e.FechaHasta }, "IX_RH_Habitacion_Fechas");

            entity.HasIndex(e => e.IdReserva, "IX_RH_Reserva");

            entity.Property(e => e.Estado)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasDefaultValue("ACTIVA");
            entity.Property(e => e.FechaCreacion)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.MontoTotal).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.MotivoCambio)
                .HasMaxLength(200)
                .IsUnicode(false);
            entity.Property(e => e.Noches).HasComputedColumnSql("(datediff(day,[FechaDesde],[FechaHasta]))", true);
            entity.Property(e => e.PersonasExtra).HasComputedColumnSql("(case when ([Adultos]+[Ninos])>[CapacidadBase] then ([Adultos]+[Ninos])-[CapacidadBase] else (0) end)", true);
            entity.Property(e => e.PrecioNoche).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.PrecioPersonaExtra).HasColumnType("decimal(12, 2)");

            entity.HasOne(d => d.IdHabitacionNavigation).WithMany(p => p.ReservaHabitacion)
                .HasForeignKey(d => d.IdHabitacion)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_RH_Habitacion");

            entity.HasOne(d => d.IdReservaNavigation).WithMany(p => p.ReservaHabitacion)
                .HasForeignKey(d => d.IdReserva)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_RH_Reserva");

            entity.HasOne(d => d.IdReservaHabitacionOrigenNavigation).WithMany(p => p.InverseIdReservaHabitacionOrigenNavigation)
                .HasForeignKey(d => d.IdReservaHabitacionOrigen)
                .HasConstraintName("FK_RH_Origen");
        });

        modelBuilder.Entity<ReservaHabitacionNoche>(entity =>
        {
            entity.HasKey(e => e.IdNoche);

            entity.ToTable("ReservaHabitacionNoche", "res", tb => tb.HasTrigger("trg_Noche_Inmutable"));

            entity.HasIndex(e => new { e.IdReservaHabitacion, e.Fecha }, "UQ_Noche").IsUnique();

            entity.Property(e => e.PorcentajeAjuste).HasColumnType("decimal(5, 2)");
            entity.Property(e => e.PrecioNoche).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.PrecioPersonaExtra).HasColumnType("decimal(12, 2)");

            entity.HasOne(d => d.IdReservaHabitacionNavigation).WithMany(p => p.ReservaHabitacionNoche)
                .HasForeignKey(d => d.IdReservaHabitacion)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Noche_RH");

            entity.HasOne(d => d.IdTemporadaNavigation).WithMany(p => p.ReservaHabitacionNoche)
                .HasForeignKey(d => d.IdTemporada)
                .HasConstraintName("FK_Noche_Temporada");
        });

        modelBuilder.Entity<Rol>(entity =>
        {
            entity.HasKey(e => e.IdRol);

            entity.ToTable("Rol", "seg");

            entity.HasIndex(e => e.Codigo, "UQ_Rol_Codigo").IsUnique();

            entity.Property(e => e.Activo).HasDefaultValue(true);
            entity.Property(e => e.Ambito)
                .HasMaxLength(7)
                .IsUnicode(false);
            entity.Property(e => e.Codigo)
                .HasMaxLength(30)
                .IsUnicode(false);
            entity.Property(e => e.Nombre)
                .HasMaxLength(60)
                .IsUnicode(false);
        });

        modelBuilder.Entity<RolModulo>(entity =>
        {
            entity.HasKey(e => e.IdRolModulo);

            entity.ToTable("RolModulo", "seg");

            entity.HasIndex(e => new { e.IdRol, e.IdModulo }, "UQ_RolModulo").IsUnique();

            entity.Property(e => e.PuedeVer).HasDefaultValue(true);

            entity.HasOne(d => d.IdModuloNavigation).WithMany(p => p.RolModulo)
                .HasForeignKey(d => d.IdModulo)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_RolModulo_Modulo");

            entity.HasOne(d => d.IdRolNavigation).WithMany(p => p.RolModulo)
                .HasForeignKey(d => d.IdRol)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_RolModulo_Rol");
        });

        modelBuilder.Entity<TarjetaHabitacion>(entity =>
        {
            entity.HasKey(e => e.IdTarjeta).HasName("PK_Tarjeta");

            entity.ToTable("TarjetaHabitacion", "hab", tb => tb.HasTrigger("trg_Tarjeta_Validar"));

            entity.HasIndex(e => new { e.IdReservaHabitacion, e.Estado }, "IX_Tarjeta_RH");

            entity.HasIndex(e => e.CodigoTarjeta, "UQ_Tarjeta_Codigo").IsUnique();

            entity.HasIndex(e => e.TokenQRHash, "UQ_Tarjeta_Token").IsUnique();

            entity.Property(e => e.CodigoTarjeta)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.Estado)
                .HasMaxLength(10)
                .IsUnicode(false)
                .HasDefaultValue("ACTIVA");
            entity.Property(e => e.FechaEmision)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.FechaRevocacion).HasPrecision(0);
            entity.Property(e => e.TokenQRHash)
                .HasMaxLength(32)
                .IsFixedLength();
            entity.Property(e => e.ValidaDesde).HasPrecision(0);
            entity.Property(e => e.ValidaHasta).HasPrecision(0);

            entity.HasOne(d => d.EmitidaPorNavigation).WithMany(p => p.TarjetaHabitacion)
                .HasForeignKey(d => d.EmitidaPor)
                .HasConstraintName("FK_Tarjeta_Usuario");

            entity.HasOne(d => d.IdHabitacionNavigation).WithMany(p => p.TarjetaHabitacion)
                .HasForeignKey(d => d.IdHabitacion)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Tarjeta_Hab");

            entity.HasOne(d => d.IdReservaHabitacionNavigation).WithMany(p => p.TarjetaHabitacion)
                .HasForeignKey(d => d.IdReservaHabitacion)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Tarjeta_RH");
        });

        modelBuilder.Entity<Temporada>(entity =>
        {
            entity.HasKey(e => e.IdTemporada);

            entity.ToTable("Temporada", "hab", tb => tb.HasTrigger("trg_Temporada_Validar"));

            entity.HasIndex(e => new { e.FechaInicio, e.FechaFin }, "IX_Temporada_Fechas").HasFilter("([Activa]=(1))");

            entity.Property(e => e.Activa).HasDefaultValue(true);
            entity.Property(e => e.Nombre)
                .HasMaxLength(60)
                .IsUnicode(false);
            entity.Property(e => e.PorcentajeAjuste).HasColumnType("decimal(5, 2)");
            entity.Property(e => e.Tipo)
                .HasMaxLength(4)
                .IsUnicode(false);
        });

        modelBuilder.Entity<TipoHabitacion>(entity =>
        {
            entity.HasKey(e => e.IdTipoHabitacion);

            entity.ToTable("TipoHabitacion", "hab");

            entity.HasIndex(e => e.Nombre, "UQ_TipoHabitacion_Nombre").IsUnique();

            entity.Property(e => e.Activo).HasDefaultValue(true);
            entity.Property(e => e.CantidadCamas).HasDefaultValue((byte)1);
            entity.Property(e => e.CodigoCabys)
                .HasMaxLength(13)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.Descripcion).HasMaxLength(300);
            entity.Property(e => e.MetrosCuadrados).HasColumnType("decimal(6, 2)");
            entity.Property(e => e.Nombre).HasMaxLength(40);
            entity.Property(e => e.PrecioNoche).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.PrecioPersonaExtra).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.TipoCama)
                .HasMaxLength(12)
                .IsUnicode(false)
                .HasDefaultValue("INDIVIDUAL");
        });

        modelBuilder.Entity<TipoHabitacionAmenidad>(entity =>
        {
            entity.HasKey(e => e.IdTipoHabitacionAmenidad);

            entity.ToTable("TipoHabitacionAmenidad", "hab");

            entity.HasIndex(e => new { e.IdTipoHabitacion, e.IdAmenidad }, "UQ_TipoHabitacionAmenidad").IsUnique();

            entity.HasOne(d => d.IdAmenidadNavigation).WithMany(p => p.TipoHabitacionAmenidad)
                .HasForeignKey(d => d.IdAmenidad)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_THA_Amenidad");

            entity.HasOne(d => d.IdTipoHabitacionNavigation).WithMany(p => p.TipoHabitacionAmenidad)
                .HasForeignKey(d => d.IdTipoHabitacion)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_THA_Tipo");
        });

        modelBuilder.Entity<TransicionEstado>(entity =>
        {
            entity.HasKey(e => new { e.Entidad, e.EstadoOrigen, e.EstadoDestino });

            entity.Property(e => e.Entidad)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.EstadoOrigen)
                .HasMaxLength(20)
                .IsUnicode(false);
            entity.Property(e => e.EstadoDestino)
                .HasMaxLength(20)
                .IsUnicode(false);
        });

        modelBuilder.Entity<Usuario>(entity =>
        {
            entity.HasKey(e => e.IdUsuario);

            entity.ToTable("Usuario", "seg", tb => tb.HasTrigger("trg_Usuario_Seguridad"));

            entity.HasIndex(e => e.NombreUsuario, "UQ_Usuario_Nombre").IsUnique();

            entity.Property(e => e.IdUsuario).ValueGeneratedNever();
            entity.Property(e => e.Activo).HasDefaultValue(true);
            entity.Property(e => e.BloqueadoHasta).HasPrecision(0);
            entity.Property(e => e.FechaCreacion)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");
            entity.Property(e => e.NombreUsuario)
                .HasMaxLength(50)
                .IsUnicode(false);
            entity.Property(e => e.PasswordHash)
                .HasMaxLength(255)
                .IsUnicode(false);
            entity.Property(e => e.SecurityStamp).HasDefaultValueSql("(newid())");
            entity.Property(e => e.UltimoAcceso).HasPrecision(0);

            entity.HasOne(d => d.IdUsuarioNavigation).WithOne(p => p.Usuario)
                .HasForeignKey<Usuario>(d => d.IdUsuario)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_Usuario_Persona");
        });

        modelBuilder.Entity<UsuarioRol>(entity =>
        {
            entity.HasKey(e => e.IdUsuarioRol);

            entity.ToTable("UsuarioRol", "seg", tb => tb.HasTrigger("trg_UsuarioRol_Validar"));

            entity.HasIndex(e => new { e.IdUsuario, e.IdRol }, "UQ_UsuarioRol").IsUnique();

            entity.Property(e => e.FechaAsignacion)
                .HasPrecision(0)
                .HasDefaultValueSql("(sysdatetime())");

            entity.HasOne(d => d.IdRolNavigation).WithMany(p => p.UsuarioRol)
                .HasForeignKey(d => d.IdRol)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_UsuarioRol_Rol");

            entity.HasOne(d => d.IdUsuarioNavigation).WithMany(p => p.UsuarioRol)
                .HasForeignKey(d => d.IdUsuario)
                .OnDelete(DeleteBehavior.ClientSetNull)
                .HasConstraintName("FK_UsuarioRol_Usuario");
        });

        modelBuilder.Entity<vw_AmenidadesHabitacion>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("vw_AmenidadesHabitacion", "hab");

            entity.Property(e => e.Codigo)
                .HasMaxLength(30)
                .IsUnicode(false);
            entity.Property(e => e.Descripcion).HasMaxLength(200);
            entity.Property(e => e.Habitacion)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.Nombre).HasMaxLength(60);
        });

        modelBuilder.Entity<vw_OcupacionHoy>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("vw_OcupacionHoy", "hab");

            entity.Property(e => e.Edificio)
                .HasMaxLength(1)
                .IsUnicode(false)
                .IsFixedLength();
            entity.Property(e => e.PorcentajeOcupacion).HasColumnType("decimal(5, 2)");
        });

        modelBuilder.Entity<vw_SeguimientoPedido>(entity =>
        {
            entity
                .HasNoKey()
                .ToView("vw_SeguimientoPedido", "coc");

            entity.Property(e => e.CargoServicio).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.Estado)
                .HasMaxLength(15)
                .IsUnicode(false);
            entity.Property(e => e.FechaPedido).HasPrecision(0);
            entity.Property(e => e.Habitacion)
                .HasMaxLength(10)
                .IsUnicode(false);
            entity.Property(e => e.Impuesto).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.Subtotal).HasColumnType("decimal(12, 2)");
            entity.Property(e => e.Total).HasColumnType("decimal(14, 2)");
        });

        OnModelCreatingPartial(modelBuilder);
    }

    partial void OnModelCreatingPartial(ModelBuilder modelBuilder);
}
