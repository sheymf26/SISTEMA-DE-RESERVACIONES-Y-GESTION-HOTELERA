USE master;
GO
-- Intercalación en español: permite guardar tildes y ñ en VARCHAR sin necesitar NVARCHAR
CREATE DATABASE HotelDB COLLATE Modern_Spanish_CI_AS;
GO
-- Lecturas sin bloquear (paneles en tiempo real); las escrituras críticas usan bloqueos explícitos
ALTER DATABASE HotelDB SET READ_COMMITTED_SNAPSHOT ON;
GO
USE HotelDB;
GO
SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
GO
/* Criterio de tipos de texto:
   - VARCHAR para todo dato interno (nombres, cédulas, motivos, bitácora, etc.)
   - NVARCHAR SOLO en textos que ve el cliente y se traducen de idioma
     (tipos de habitación, amenidades, menú y el contenido de los correos)          */
CREATE SCHEMA seg;  -- seguridad (usuarios, roles, módulos, tokens)
GO
CREATE SCHEMA hab;  -- edificios, pisos, habitaciones, temporadas, amenidades, tarjetas
GO
CREATE SCHEMA res;  -- clientes, reservas, descuentos, abonos, pagos, cancelaciones
GO
CREATE SCHEMA coc;  -- cocina / servicio a la habitación
GO
CREATE SCHEMA fac;  -- facturación electrónica
GO
CREATE SCHEMA rh;   -- empleados y planilla
GO
CREATE SCHEMA aud;  -- bitácora
GO

-- 1. TABLAS GENERALES

CREATE TABLE dbo.Parametro(
    Clave        VARCHAR(50)   NOT NULL CONSTRAINT PK_Parametro PRIMARY KEY,
    Valor        DECIMAL(18,4) NOT NULL CONSTRAINT CK_Parametro_Valor CHECK (Valor >= 0),
    Descripcion  VARCHAR(200)  NOT NULL
);

-- Máquina de estados: solo se permiten las transiciones registradas aquí
CREATE TABLE dbo.TransicionEstado(
    Entidad       VARCHAR(20) NOT NULL,
    EstadoOrigen  VARCHAR(20) NOT NULL,
    EstadoDestino VARCHAR(20) NOT NULL,
    CONSTRAINT PK_TransicionEstado PRIMARY KEY (Entidad, EstadoOrigen, EstadoDestino),
    CONSTRAINT CK_TransicionEstado CHECK (EstadoOrigen <> EstadoDestino)
);

-- Cola de correos: la BD encola y un servicio del backend los envía
CREATE TABLE dbo.ColaCorreo(
    IdCorreo      BIGINT IDENTITY(1,1) CONSTRAINT PK_ColaCorreo PRIMARY KEY,
    Destinatario  VARCHAR(150)  NOT NULL,
    Asunto        NVARCHAR(200) NOT NULL,     -- se traduce al idioma del cliente
    Cuerpo        NVARCHAR(MAX) NOT NULL,     -- se traduce al idioma del cliente
    Tipo          VARCHAR(30)   NOT NULL,
    IdReferencia  INT NULL,
    Estado        VARCHAR(10)   NOT NULL DEFAULT 'PENDIENTE',
    Intentos      TINYINT       NOT NULL DEFAULT 0,
    FechaCreacion DATETIME2(0)  NOT NULL DEFAULT SYSDATETIME(),
    FechaEnvio    DATETIME2(0)  NULL,
    UltimoError   VARCHAR(500)  NULL,
    CONSTRAINT CK_ColaCorreo_Estado   CHECK (Estado IN ('PENDIENTE','ENVIADO','ERROR')),
    CONSTRAINT CK_ColaCorreo_Intentos CHECK (Intentos <= 10),
    CONSTRAINT CK_ColaCorreo_Tipo     CHECK (Tipo IN ('RESERVA_CREADA','RESERVA_CONFIRMADA','RESERVA_CANCELADA',
                                                      'RESERVA_EXPIRADA','CAMBIO_RESERVA','FACTURA_EMITIDA','FACTURA_ANULADA',
                                                      'ABONO_VENCIDO'))
);

CREATE TABLE aud.Bitacora(
    IdBitacora      BIGINT IDENTITY(1,1) CONSTRAINT PK_Bitacora PRIMARY KEY,
    Tabla           SYSNAME      NOT NULL,
    Operacion       VARCHAR(6)   NOT NULL CONSTRAINT CK_Bitacora_Op CHECK (Operacion IN ('INSERT','UPDATE','DELETE')),
    IdRegistro      INT          NOT NULL,
    DatosAnteriores VARCHAR(MAX) NULL,
    DatosNuevos     VARCHAR(MAX) NULL,
    IdUsuario       INT NULL,                         -- SESSION_CONTEXT('IdUsuario') fijado por el backend
    UsuarioBD       SYSNAME      NOT NULL DEFAULT ORIGINAL_LOGIN(),
    Fecha           DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

/* Persona: datos personales en UN solo lugar.
   Herencia (subtipos 1:1 con la misma llave):
       dbo.Persona ──┬── res.Cliente   (IdCliente  = IdPersona)
                     ├── rh.Empleado   (IdEmpleado = IdPersona)
                     └── seg.Usuario   (IdUsuario  = IdPersona)
   Una misma persona puede ser cliente y empleado a la vez sin duplicar datos. */
CREATE TABLE dbo.Persona(
    IdPersona          INT IDENTITY(1,1) CONSTRAINT PK_Persona PRIMARY KEY,
    TipoIdentificacion VARCHAR(15)  NOT NULL,
    Identificacion     VARCHAR(30)  NOT NULL,
    Nombre             VARCHAR(60)  NOT NULL,
    Apellidos          VARCHAR(100) NOT NULL,
    Correo             VARCHAR(150) NOT NULL CONSTRAINT UQ_Persona_Correo UNIQUE,
    Telefono           VARCHAR(20)  NULL,
    FechaRegistro      DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT UQ_Persona_Identificacion UNIQUE (TipoIdentificacion, Identificacion),
    CONSTRAINT CK_Persona_TipoId CHECK (TipoIdentificacion IN ('CEDULA','DIMEX','PASAPORTE')),
    -- Cédula física: 9 dígitos | DIMEX: 11 o 12 dígitos | Pasaporte: alfanumérico
    CONSTRAINT CK_Persona_FormatoId CHECK (
           (TipoIdentificacion = 'CEDULA'    AND LEN(Identificacion) = 9 AND Identificacion NOT LIKE '%[^0-9]%')
        OR (TipoIdentificacion = 'DIMEX'     AND LEN(Identificacion) IN (11, 12) AND Identificacion NOT LIKE '%[^0-9]%')
        OR (TipoIdentificacion = 'PASAPORTE' AND LEN(Identificacion) BETWEEN 5 AND 20 AND Identificacion NOT LIKE '%[^0-9A-Z]%')),
    CONSTRAINT CK_Persona_Correo CHECK (Correo LIKE '%_@_%._%')
);

-- 2. SEGURIDAD

CREATE TABLE seg.Modulo(
    IdModulo INT IDENTITY(1,1) CONSTRAINT PK_Modulo PRIMARY KEY,
    Codigo   VARCHAR(30) NOT NULL CONSTRAINT UQ_Modulo_Codigo UNIQUE,
    Nombre   VARCHAR(60) NOT NULL,
    Activo   BIT NOT NULL DEFAULT 1
);

-- Ámbito: SISTEMA = web de administración (exige ser empleado) | APP = app de clientes (exige ser cliente)
CREATE TABLE seg.Rol(
    IdRol  INT IDENTITY(1,1) CONSTRAINT PK_Rol PRIMARY KEY,
    Codigo VARCHAR(30) NOT NULL CONSTRAINT UQ_Rol_Codigo UNIQUE,
    Nombre VARCHAR(60) NOT NULL,
    Ambito VARCHAR(7)  NOT NULL CONSTRAINT CK_Rol_Ambito CHECK (Ambito IN ('SISTEMA','APP')),
    Activo BIT NOT NULL DEFAULT 1
);

CREATE TABLE seg.RolModulo(
    IdRolModulo INT IDENTITY(1,1) CONSTRAINT PK_RolModulo PRIMARY KEY,
    IdRol       INT NOT NULL CONSTRAINT FK_RolModulo_Rol    REFERENCES seg.Rol(IdRol),
    IdModulo    INT NOT NULL CONSTRAINT FK_RolModulo_Modulo REFERENCES seg.Modulo(IdModulo),
    PuedeVer    BIT NOT NULL DEFAULT 1,
    PuedeCrear  BIT NOT NULL DEFAULT 0,
    PuedeEditar BIT NOT NULL DEFAULT 0,
    PuedeAnular BIT NOT NULL DEFAULT 0,
    CONSTRAINT UQ_RolModulo UNIQUE (IdRol, IdModulo),
    CONSTRAINT CK_RolModulo_Coherente CHECK (PuedeVer = 1 OR (PuedeCrear = 0 AND PuedeEditar = 0 AND PuedeAnular = 0))
);

-- Usuario genérico (app y sistema): lo que puede hacer depende solo de sus roles
CREATE TABLE seg.Usuario(
    IdUsuario           INT NOT NULL CONSTRAINT PK_Usuario PRIMARY KEY
                            CONSTRAINT FK_Usuario_Persona REFERENCES dbo.Persona(IdPersona),
    NombreUsuario       VARCHAR(50)  NOT NULL CONSTRAINT UQ_Usuario_Nombre UNIQUE,
    PasswordHash        VARCHAR(255) NOT NULL,
    SecurityStamp       UNIQUEIDENTIFIER NOT NULL DEFAULT NEWID(),  -- va dentro del JWT; si cambia, el token muere
    IntentosFallidos    TINYINT      NOT NULL DEFAULT 0,
    BloqueadoHasta      DATETIME2(0) NULL,
    DebeCambiarPassword BIT          NOT NULL DEFAULT 0,
    UltimoAcceso        DATETIME2(0) NULL,
    Activo              BIT          NOT NULL DEFAULT 1,
    FechaCreacion       DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    -- El login acepta nombre de usuario o correo: un nombre con '@' podría confundirse con el correo de otra persona
    CONSTRAINT CK_Usuario_Nombre CHECK (NombreUsuario NOT LIKE '%@%' AND LEN(NombreUsuario) >= 4),
    -- Impide guardar contraseñas en texto plano: solo acepta BCrypt, Argon2 o ASP.NET Identity
    CONSTRAINT CK_Usuario_Hash CHECK (LEN(PasswordHash) >= 60 AND
        (PasswordHash LIKE '$2[aby]$%' OR PasswordHash LIKE '$argon2%' OR PasswordHash LIKE 'AQAAAA%'))
);

CREATE TABLE seg.UsuarioRol(
    IdUsuarioRol    INT IDENTITY(1,1) CONSTRAINT PK_UsuarioRol PRIMARY KEY,
    IdUsuario       INT NOT NULL CONSTRAINT FK_UsuarioRol_Usuario REFERENCES seg.Usuario(IdUsuario),
    IdRol           INT NOT NULL CONSTRAINT FK_UsuarioRol_Rol     REFERENCES seg.Rol(IdRol),
    FechaAsignacion DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT UQ_UsuarioRol UNIQUE (IdUsuario, IdRol)
);

-- Solo se guarda el HASH (SHA-256) del refresh token, nunca el token
CREATE TABLE seg.RefreshToken(
    IdRefreshToken  BIGINT IDENTITY(1,1) CONSTRAINT PK_RefreshToken PRIMARY KEY,
    IdUsuario       INT NOT NULL CONSTRAINT FK_RefreshToken_Usuario REFERENCES seg.Usuario(IdUsuario),
    TokenHash       BINARY(32) NOT NULL CONSTRAINT UQ_RefreshToken_Hash UNIQUE,
    ReemplazadoPor  BINARY(32) NULL,
    Dispositivo     VARCHAR(100) NULL,
    IpOrigen        VARCHAR(45) NULL,
    FechaCreacion   DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    FechaExpiracion DATETIME2(0) NOT NULL,
    FechaRevocacion DATETIME2(0) NULL,
    CONSTRAINT CK_RefreshToken_Exp CHECK (FechaExpiracion > FechaCreacion)
);

-- Una sola tabla y un solo contador para los intentos de la app y del sistema web; Origen solo informa de dónde vino
CREATE TABLE seg.IntentoLogin(
    IdIntento      BIGINT IDENTITY(1,1) CONSTRAINT PK_IntentoLogin PRIMARY KEY,
    LoginIngresado VARCHAR(150) NOT NULL,
    IdUsuario      INT NULL CONSTRAINT FK_IntentoLogin_Usuario REFERENCES seg.Usuario(IdUsuario),
    Origen         VARCHAR(3)   NOT NULL CONSTRAINT CK_IntentoLogin_Origen CHECK (Origen IN ('APP','WEB')),
    Exitoso        BIT NOT NULL,
    IpOrigen       VARCHAR(45) NULL,
    Dispositivo    VARCHAR(100) NULL,
    Fecha          DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

-- 3. INFRAESTRUCTURA: 4 edificios × 6 pisos × 10 habitaciones

CREATE TABLE hab.Edificio(
    IdEdificio INT IDENTITY(1,1) CONSTRAINT PK_Edificio PRIMARY KEY,
    Numero     TINYINT NOT NULL CONSTRAINT UQ_Edificio_Numero UNIQUE,
    Codigo     CHAR(1) NOT NULL CONSTRAINT UQ_Edificio_Codigo UNIQUE,
    Nombre     VARCHAR(50) NOT NULL,
    CONSTRAINT CK_Edificio_Numero CHECK (Numero BETWEEN 1 AND 4),     -- máximo 4 edificios
    CONSTRAINT CK_Edificio_Codigo CHECK (Codigo LIKE '[A-Z]')
);

CREATE TABLE hab.Piso(
    IdPiso     INT IDENTITY(1,1) CONSTRAINT PK_Piso PRIMARY KEY,
    IdEdificio INT NOT NULL CONSTRAINT FK_Piso_Edificio REFERENCES hab.Edificio(IdEdificio),
    Numero     TINYINT NOT NULL,
    CONSTRAINT UQ_Piso UNIQUE (IdEdificio, Numero),
    CONSTRAINT CK_Piso_Numero CHECK (Numero BETWEEN 1 AND 6)          -- máximo 6 pisos
);

CREATE TABLE hab.TipoHabitacion(
    IdTipoHabitacion   INT IDENTITY(1,1) CONSTRAINT PK_TipoHabitacion PRIMARY KEY,
    Nombre             NVARCHAR(40) NOT NULL CONSTRAINT UQ_TipoHabitacion_Nombre UNIQUE,   -- se traduce
    CapacidadBase      TINYINT NOT NULL,          -- personas incluidas en el precio
    CapacidadMaxima    TINYINT NOT NULL,          -- tope absoluto
    CantidadCamas      TINYINT NOT NULL DEFAULT 1,
    TipoCama           VARCHAR(12) NOT NULL DEFAULT 'INDIVIDUAL',
    MetrosCuadrados    DECIMAL(6,2) NULL,
    PrecioNoche        DECIMAL(12,2) NOT NULL,    -- tarifa base (temporada regular)
    PrecioPersonaExtra DECIMAL(12,2) NOT NULL,    -- por noche, por cada persona sobre la base
    CodigoCabys        CHAR(13) NULL,             -- código CABYS de Hacienda para la factura electrónica
    Descripcion        NVARCHAR(300) NULL,        -- se traduce
    Activo             BIT NOT NULL DEFAULT 1,
    CONSTRAINT CK_TipoHab_Capacidad CHECK (CapacidadBase >= 1 AND CapacidadMaxima >= CapacidadBase AND CapacidadMaxima <= 8),
    CONSTRAINT CK_TipoHab_Precios   CHECK (PrecioNoche > 0 AND PrecioPersonaExtra >= 0),
    CONSTRAINT CK_TipoHab_Camas     CHECK (CantidadCamas BETWEEN 1 AND 4),
    CONSTRAINT CK_TipoHab_TipoCama  CHECK (TipoCama IN ('INDIVIDUAL','MATRIMONIAL','QUEEN','KING')),
    CONSTRAINT CK_TipoHab_M2        CHECK (MetrosCuadrados IS NULL OR MetrosCuadrados > 0),
    CONSTRAINT CK_TipoHab_Cabys     CHECK (CodigoCabys IS NULL OR CodigoCabys NOT LIKE '%[^0-9]%')
);

CREATE TABLE hab.Habitacion(
    IdHabitacion     INT IDENTITY(1,1) CONSTRAINT PK_Habitacion PRIMARY KEY,
    IdPiso           INT NOT NULL CONSTRAINT FK_Habitacion_Piso REFERENCES hab.Piso(IdPiso),
    NumeroEnPiso     TINYINT NOT NULL,
    Codigo           VARCHAR(10) NOT NULL CONSTRAINT UQ_Habitacion_Codigo UNIQUE,   -- ej. B-305
    IdTipoHabitacion INT NOT NULL CONSTRAINT FK_Habitacion_Tipo REFERENCES hab.TipoHabitacion(IdTipoHabitacion),
    Estado           VARCHAR(15) NOT NULL DEFAULT 'DISPONIBLE',
    Activa           BIT NOT NULL DEFAULT 1,
    RowVer           ROWVERSION,
    CONSTRAINT UQ_Habitacion_PisoNumero UNIQUE (IdPiso, NumeroEnPiso),
    CONSTRAINT CK_Habitacion_Numero CHECK (NumeroEnPiso BETWEEN 1 AND 10),          -- máximo 10 por piso
    CONSTRAINT CK_Habitacion_Estado CHECK (Estado IN ('DISPONIBLE','OCUPADA','LIMPIEZA','MANTENIMIENTO','FUERA_SERVICIO'))
);

-- Amenidades: las del tipo aplican a todas sus habitaciones; HabitacionAmenidad agrega extras de una habitación puntual
CREATE TABLE hab.Amenidad(
    IdAmenidad  INT IDENTITY(1,1) CONSTRAINT PK_Amenidad PRIMARY KEY,
    Codigo      VARCHAR(30)   NOT NULL CONSTRAINT UQ_Amenidad_Codigo UNIQUE,
    Nombre      NVARCHAR(60)  NOT NULL,       -- se traduce
    Descripcion NVARCHAR(200) NULL,           -- se traduce
    Activa      BIT NOT NULL DEFAULT 1
);

CREATE TABLE hab.TipoHabitacionAmenidad(
    IdTipoHabitacionAmenidad INT IDENTITY(1,1) CONSTRAINT PK_TipoHabitacionAmenidad PRIMARY KEY,
    IdTipoHabitacion INT NOT NULL CONSTRAINT FK_THA_Tipo     REFERENCES hab.TipoHabitacion(IdTipoHabitacion),
    IdAmenidad       INT NOT NULL CONSTRAINT FK_THA_Amenidad REFERENCES hab.Amenidad(IdAmenidad),
    CONSTRAINT UQ_TipoHabitacionAmenidad UNIQUE (IdTipoHabitacion, IdAmenidad)
);

CREATE TABLE hab.HabitacionAmenidad(
    IdHabitacionAmenidad INT IDENTITY(1,1) CONSTRAINT PK_HabitacionAmenidad PRIMARY KEY,
    IdHabitacion INT NOT NULL CONSTRAINT FK_HA_Habitacion REFERENCES hab.Habitacion(IdHabitacion),
    IdAmenidad   INT NOT NULL CONSTRAINT FK_HA_Amenidad   REFERENCES hab.Amenidad(IdAmenidad),
    CONSTRAINT UQ_HabitacionAmenidad UNIQUE (IdHabitacion, IdAmenidad)
);

/* Temporadas: ajustan la tarifa base de TODAS las habitaciones en un rango de fechas.
   ALTA = recargo (+%), BAJA = rebaja (-%). Las fechas sin temporada usan la tarifa base.
   FechaFin es inclusiva: es la última NOCHE de la temporada. */
CREATE TABLE hab.Temporada(
    IdTemporada      INT IDENTITY(1,1) CONSTRAINT PK_Temporada PRIMARY KEY,
    Nombre           VARCHAR(60) NOT NULL,
    Tipo             VARCHAR(4)  NOT NULL CONSTRAINT CK_Temporada_Tipo CHECK (Tipo IN ('ALTA','BAJA')),
    FechaInicio      DATE NOT NULL,
    FechaFin         DATE NOT NULL,
    PorcentajeAjuste DECIMAL(5,2) NOT NULL,
    Activa           BIT NOT NULL DEFAULT 1,
    CONSTRAINT CK_Temporada_Fechas CHECK (FechaFin >= FechaInicio),
    CONSTRAINT CK_Temporada_Ajuste CHECK (PorcentajeAjuste BETWEEN -90 AND 200 AND
                                          ((Tipo = 'ALTA' AND PorcentajeAjuste > 0) OR (Tipo = 'BAJA' AND PorcentajeAjuste < 0)))
);

CREATE TABLE hab.BloqueoHabitacion(
    IdBloqueo     INT IDENTITY(1,1) CONSTRAINT PK_BloqueoHabitacion PRIMARY KEY,
    IdHabitacion  INT NOT NULL CONSTRAINT FK_Bloqueo_Habitacion REFERENCES hab.Habitacion(IdHabitacion),
    FechaDesde    DATE NOT NULL,
    FechaHasta    DATE NOT NULL,
    Motivo        VARCHAR(200) NOT NULL,
    Activo        BIT NOT NULL DEFAULT 1,
    CreadoPor     INT NULL CONSTRAINT FK_Bloqueo_Usuario REFERENCES seg.Usuario(IdUsuario),
    FechaCreacion DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Bloqueo_Fechas CHECK (FechaHasta > FechaDesde)
);

-- 4. CLIENTES Y RESERVAS

-- Subtipo de Persona: solo guarda lo propio del cliente
CREATE TABLE res.Cliente(
    IdCliente           INT NOT NULL CONSTRAINT PK_Cliente PRIMARY KEY
                            CONSTRAINT FK_Cliente_Persona REFERENCES dbo.Persona(IdPersona),
    EstadiasCompletadas INT NOT NULL DEFAULT 0 CONSTRAINT CK_Cliente_Estadias CHECK (EstadiasCompletadas >= 0),
    EsFrecuente         BIT NOT NULL DEFAULT 0,
    Activo              BIT NOT NULL DEFAULT 1,
    FechaRegistro       DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);

-- Tramos: se aplica el de mayor HorasMinimas que se cumpla, % sobre lo PAGADO (anticipo)
CREATE TABLE res.PoliticaCancelacion(
    IdPolitica             INT IDENTITY(1,1) CONSTRAINT PK_PoliticaCancelacion PRIMARY KEY,
    Nombre                 VARCHAR(80) NOT NULL,
    HorasMinimas           INT NOT NULL CONSTRAINT CK_Politica_Horas CHECK (HorasMinimas >= 0),
    PorcentajePenalizacion DECIMAL(5,2) NOT NULL CONSTRAINT CK_Politica_Pct CHECK (PorcentajePenalizacion BETWEEN 0 AND 100),
    Activa                 BIT NOT NULL DEFAULT 1
);
CREATE UNIQUE INDEX UX_Politica_Horas ON res.PoliticaCancelacion(HorasMinimas) WHERE Activa = 1;

/* Descuentos generales (catálogo). Reglas:
   - NO son acumulables: una reservación tiene a lo sumo UN descuento (se aplica el que más beneficia en hospedaje)
   - Clase PROMOCION se usa con código; CLIENTE_FRECUENTE se aplica solo; CORTESIA la aplica el personal
   - Un descuento ya usado no cambia sus condiciones: se desactiva y se crea otro
   - Los usos se cuentan sobre reservaciones vigentes (las canceladas o expiradas liberan el uso) */
CREATE TABLE res.Descuento(
    IdDescuento  INT IDENTITY(1,1) CONSTRAINT PK_Descuento PRIMARY KEY,
    Codigo       VARCHAR(30) NULL,
    Nombre       VARCHAR(80) NOT NULL,
    Clase        VARCHAR(17) NOT NULL,
    Tipo         VARCHAR(10) NOT NULL,
    Valor        DECIMAL(12,2) NOT NULL,
    AplicaA      VARCHAR(19) NOT NULL,
    FechaInicio  DATE NULL,                 -- vigencia según la fecha de entrada de la reservación
    FechaFin     DATE NULL,
    IdTemporada  INT NULL CONSTRAINT FK_Descuento_Temporada REFERENCES hab.Temporada(IdTemporada),
    MinNoches    TINYINT NULL,
    UsosMaximos  INT NULL,
    Activo       BIT NOT NULL DEFAULT 1,
    FechaCreacion DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Descuento_Clase   CHECK (Clase IN ('PROMOCION','CLIENTE_FRECUENTE','CORTESIA')),
    CONSTRAINT CK_Descuento_Tipo    CHECK (Tipo IN ('PORCENTAJE','MONTO')),
    CONSTRAINT CK_Descuento_Valor   CHECK (Valor > 0 AND (Tipo = 'MONTO' OR Valor <= 100)),
    CONSTRAINT CK_Descuento_AplicaA CHECK (AplicaA IN ('HOSPEDAJE','SERVICIO_HABITACION','TODO')),
    CONSTRAINT CK_Descuento_Fechas  CHECK (FechaInicio IS NULL OR FechaFin IS NULL OR FechaFin >= FechaInicio),
    CONSTRAINT CK_Descuento_Usos    CHECK (UsosMaximos IS NULL OR UsosMaximos > 0),
    CONSTRAINT CK_Descuento_Codigo  CHECK ((Clase = 'PROMOCION' AND Codigo IS NOT NULL) OR (Clase <> 'PROMOCION' AND Codigo IS NULL))
);
CREATE UNIQUE INDEX UX_Descuento_Codigo ON res.Descuento(Codigo) WHERE Codigo IS NOT NULL;

CREATE TABLE res.Reserva(
    IdReserva           INT IDENTITY(1,1) CONSTRAINT PK_Reserva PRIMARY KEY,
    CodigoReserva       AS ('RES-' + RIGHT('0000000' + CAST(IdReserva AS VARCHAR(10)), 7)) PERSISTED,
    IdCliente           INT NOT NULL CONSTRAINT FK_Reserva_Cliente REFERENCES res.Cliente(IdCliente),
    FechaEntrada        DATE NOT NULL,
    FechaSalida         DATE NOT NULL,
    Estado              VARCHAR(12) NOT NULL DEFAULT 'PENDIENTE',
    Canal               VARCHAR(10) NOT NULL,
    IdDescuento         INT NULL CONSTRAINT FK_Reserva_Descuento REFERENCES res.Descuento(IdDescuento),
    Subtotal            DECIMAL(12,2) NOT NULL DEFAULT 0,   -- hospedaje (ya con el ajuste de temporada)
    MontoDescuento      DECIMAL(12,2) NOT NULL DEFAULT 0,   -- descuento sobre el hospedaje
    MontoImpuesto       DECIMAL(12,2) NOT NULL DEFAULT 0,
    Total               DECIMAL(12,2) NOT NULL DEFAULT 0,
    PorcentajeAnticipo  DECIMAL(5,2)  NOT NULL,
    AnticipoRequerido   DECIMAL(12,2) NOT NULL DEFAULT 0,
    MontoPagado         DECIMAL(12,2) NOT NULL DEFAULT 0,   -- neto (pagos - reembolsos), lo mantiene un trigger
    SaldoAnticipo       AS (CASE WHEN AnticipoRequerido > MontoPagado THEN AnticipoRequerido - MontoPagado ELSE 0 END),
    SaldoTotal          AS (CASE WHEN Total > MontoPagado THEN Total - MontoPagado ELSE 0 END),
    FechaExpiracion     DATETIME2(0) NULL,                  -- límite para pagar el anticipo
    Observaciones       VARCHAR(500) NULL,
    CreadoPor           INT NULL CONSTRAINT FK_Reserva_Usuario REFERENCES seg.Usuario(IdUsuario),
    FechaCreacion       DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    FechaModificacion   DATETIME2(0) NULL,
    RowVer              ROWVERSION,
    CONSTRAINT CK_Reserva_Fechas     CHECK (FechaSalida > FechaEntrada),
    CONSTRAINT CK_Reserva_MaxNoches  CHECK (DATEDIFF(DAY, FechaEntrada, FechaSalida) <= 60),
    CONSTRAINT CK_Reserva_Estado     CHECK (Estado IN ('PENDIENTE','CONFIRMADA','CHECKIN','CHECKOUT','CANCELADA','EXPIRADA','NO_SHOW')),
    CONSTRAINT CK_Reserva_Canal      CHECK (Canal IN ('WEB','APP','RECEPCION')),
    CONSTRAINT CK_Reserva_Montos     CHECK (Subtotal >= 0 AND MontoDescuento >= 0 AND MontoDescuento <= Subtotal AND MontoImpuesto >= 0
                                            AND Total >= 0 AND AnticipoRequerido >= 0 AND AnticipoRequerido <= Total AND MontoPagado >= 0),
    CONSTRAINT CK_Reserva_Pct        CHECK (PorcentajeAnticipo BETWEEN 0 AND 100),
    CONSTRAINT CK_Reserva_Expiracion CHECK (Estado <> 'PENDIENTE' OR FechaExpiracion IS NOT NULL)
);

-- Una reservación puede tener varias habitaciones; cada cambio de habitación/ocupación genera una línea nueva
CREATE TABLE res.ReservaHabitacion(
    IdReservaHabitacion INT IDENTITY(1,1) CONSTRAINT PK_ReservaHabitacion PRIMARY KEY,
    IdReserva           INT NOT NULL CONSTRAINT FK_RH_Reserva    REFERENCES res.Reserva(IdReserva),
    IdHabitacion        INT NOT NULL CONSTRAINT FK_RH_Habitacion REFERENCES hab.Habitacion(IdHabitacion),
    FechaDesde          DATE NOT NULL,
    FechaHasta          DATE NOT NULL,
    Adultos             TINYINT NOT NULL,
    Ninos               TINYINT NOT NULL DEFAULT 0,
    CapacidadBase       TINYINT NOT NULL,          -- copia del tipo al momento de reservar
    PrecioNoche         DECIMAL(12,2) NOT NULL,    -- tarifa BASE pactada (no cambia si cambia la tarifa)
    PrecioPersonaExtra  DECIMAL(12,2) NOT NULL,
    Noches        AS (DATEDIFF(DAY, FechaDesde, FechaHasta)) PERSISTED,
    PersonasExtra AS (CASE WHEN Adultos + Ninos > CapacidadBase THEN Adultos + Ninos - CapacidadBase ELSE 0 END) PERSISTED,
    MontoTotal          DECIMAL(12,2) NOT NULL DEFAULT 0,   -- suma de sus noches (con temporada); lo calcula res.sp_RecalcularReserva
    Estado              VARCHAR(10) NOT NULL DEFAULT 'ACTIVA',
    IdReservaHabitacionOrigen INT NULL CONSTRAINT FK_RH_Origen REFERENCES res.ReservaHabitacion(IdReservaHabitacion),
    MotivoCambio        VARCHAR(200) NULL,
    FechaCreacion       DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT CK_RH_Fechas   CHECK (FechaHasta > FechaDesde),
    CONSTRAINT CK_RH_Personas CHECK (Adultos >= 1 AND Adultos + Ninos <= 8),
    CONSTRAINT CK_RH_Precios  CHECK (PrecioNoche >= 0 AND PrecioPersonaExtra >= 0 AND MontoTotal >= 0),
    CONSTRAINT CK_RH_Estado   CHECK (Estado IN ('ACTIVA','CAMBIADA','CANCELADA','FINALIZADA'))
);

/* Precio pactado NOCHE POR NOCHE (resuelve estadías que cruzan de temporada baja a alta).
   Se congela al reservar: si luego cambia una temporada, las reservas hechas no cambian.
   Al acortar una línea sus noches sobrantes se ignoran; una línea nueva (cambio de habitación u ocupación)
   hereda el % de temporada pactado en la línea de origen. */
CREATE TABLE res.ReservaHabitacionNoche(
    IdNoche             BIGINT IDENTITY(1,1) CONSTRAINT PK_ReservaHabitacionNoche PRIMARY KEY,
    IdReservaHabitacion INT  NOT NULL CONSTRAINT FK_Noche_RH REFERENCES res.ReservaHabitacion(IdReservaHabitacion),
    Fecha               DATE NOT NULL,
    IdTemporada         INT  NULL CONSTRAINT FK_Noche_Temporada REFERENCES hab.Temporada(IdTemporada),
    PorcentajeAjuste    DECIMAL(5,2)  NOT NULL DEFAULT 0,
    PrecioNoche         DECIMAL(12,2) NOT NULL,      -- ya ajustado por temporada
    PrecioPersonaExtra  DECIMAL(12,2) NOT NULL,      -- ya ajustado por temporada
    CONSTRAINT UQ_Noche UNIQUE (IdReservaHabitacion, Fecha),
    CONSTRAINT CK_Noche_Precios CHECK (PrecioNoche >= 0 AND PrecioPersonaExtra >= 0)
);

CREATE TABLE res.Huesped(
    IdHuesped           INT IDENTITY(1,1) CONSTRAINT PK_Huesped PRIMARY KEY,
    IdReservaHabitacion INT NOT NULL CONSTRAINT FK_Huesped_RH REFERENCES res.ReservaHabitacion(IdReservaHabitacion),
    NombreCompleto      VARCHAR(120) NOT NULL,
    TipoIdentificacion  VARCHAR(15) NULL,
    Identificacion      VARCHAR(30) NULL,
    EsMenor             BIT NOT NULL DEFAULT 0,
    CONSTRAINT CK_Huesped_TipoId CHECK (TipoIdentificacion IS NULL OR TipoIdentificacion IN ('CEDULA','DIMEX','PASAPORTE')),
    CONSTRAINT CK_Huesped_Id     CHECK ((TipoIdentificacion IS NULL AND Identificacion IS NULL)
                                     OR (TipoIdentificacion IS NOT NULL AND Identificacion IS NOT NULL))
);

/* Plan de abonos de una reservación (cuotas). Se arma con los parámetros:
   PCT_ANTICIPO (cuota 1), CANTIDAD_MAX_ABONOS, PCT_ABONO_MINIMO y DIAS_LIMITE_SALDO.
   Los pagos se aplican a las cuotas en orden (FIFO): MontoPagado de cada cuota se deriva de res.Reserva.MontoPagado,
   por eso un pago anulado o un reembolso se reflejan solos. */
CREATE TABLE res.Abono(
    IdAbono         INT IDENTITY(1,1) CONSTRAINT PK_Abono PRIMARY KEY,
    IdReserva       INT NOT NULL CONSTRAINT FK_Abono_Reserva REFERENCES res.Reserva(IdReserva),
    Numero          TINYINT NOT NULL,
    Concepto        VARCHAR(8) NOT NULL CONSTRAINT CK_Abono_Concepto CHECK (Concepto IN ('ANTICIPO','ABONO','SALDO')),
    MontoProgramado DECIMAL(12,2) NOT NULL,
    MontoPagado     DECIMAL(12,2) NOT NULL DEFAULT 0,
    SaldoPendiente  AS (CAST(MontoProgramado - MontoPagado AS DECIMAL(12,2))),
    FechaLimite     DATETIME2(0) NOT NULL,
    Estado          VARCHAR(9) NOT NULL DEFAULT 'PENDIENTE',
    FechaPago       DATETIME2(0) NULL,
    CONSTRAINT UQ_Abono_Numero  UNIQUE (IdReserva, Numero),
    CONSTRAINT CK_Abono_Montos  CHECK (MontoProgramado > 0 AND MontoPagado >= 0 AND MontoPagado <= MontoProgramado),
    CONSTRAINT CK_Abono_Estado  CHECK (Estado IN ('PENDIENTE','PAGADO','VENCIDO','ANULADO')),
    CONSTRAINT CK_Abono_Pagado  CHECK (Estado <> 'PAGADO' OR (MontoPagado = MontoProgramado AND FechaPago IS NOT NULL))
);

CREATE TABLE res.Pago(
    IdPago         INT IDENTITY(1,1) CONSTRAINT PK_Pago PRIMARY KEY,
    IdReserva      INT NOT NULL CONSTRAINT FK_Pago_Reserva REFERENCES res.Reserva(IdReserva),
    IdFactura      INT NULL,      -- FK se agrega después de crear fac.Factura
    TipoMovimiento VARCHAR(12) NOT NULL,
    Metodo         VARCHAR(15) NOT NULL,
    Monto          DECIMAL(12,2) NOT NULL,
    Referencia     VARCHAR(50) NULL,        -- número de autorización, NUNCA el número de tarjeta
    Anulado        BIT NOT NULL DEFAULT 0,
    RegistradoPor  INT NULL CONSTRAINT FK_Pago_Usuario REFERENCES seg.Usuario(IdUsuario),
    Fecha          DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Pago_Tipo   CHECK (TipoMovimiento IN ('ANTICIPO','ABONO','PAGO_FINAL','REEMBOLSO')),
    CONSTRAINT CK_Pago_Metodo CHECK (Metodo IN ('EFECTIVO','TARJETA','TRANSFERENCIA','SINPE')),
    CONSTRAINT CK_Pago_Monto  CHECK (Monto > 0),
    -- Rechaza referencias con 13+ dígitos seguidos (parecen números de tarjeta)
    CONSTRAINT CK_Pago_SinTarjeta CHECK (Referencia IS NULL OR Referencia NOT LIKE
        '%[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]%')
);

CREATE TABLE res.Cancelacion(
    IdCancelacion       INT IDENTITY(1,1) CONSTRAINT PK_Cancelacion PRIMARY KEY,
    IdReserva           INT NOT NULL CONSTRAINT UQ_Cancelacion_Reserva UNIQUE
                            CONSTRAINT FK_Cancelacion_Reserva REFERENCES res.Reserva(IdReserva),
    FechaCancelacion    DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    HorasAntelacion     INT NOT NULL,
    IdPolitica          INT NULL CONSTRAINT FK_Cancelacion_Politica REFERENCES res.PoliticaCancelacion(IdPolitica),
    PorcentajePolitica  DECIMAL(5,2) NOT NULL,
    EraClienteFrecuente BIT NOT NULL,
    PorcentajeAplicado  DECIMAL(5,2) NOT NULL,
    MontoPagado         DECIMAL(12,2) NOT NULL,
    MontoRetenido       DECIMAL(12,2) NOT NULL,
    MontoReembolso      DECIMAL(12,2) NOT NULL,
    Motivo              VARCHAR(300) NOT NULL,
    CanceladoPor        INT NULL CONSTRAINT FK_Cancelacion_Usuario REFERENCES seg.Usuario(IdUsuario),
    CONSTRAINT CK_Cancelacion_Montos CHECK (MontoRetenido >= 0 AND MontoReembolso >= 0 AND MontoRetenido + MontoReembolso = MontoPagado),
    CONSTRAINT CK_Cancelacion_Pct    CHECK (PorcentajeAplicado <= PorcentajePolitica)
);


  -- 5. TARJETA DE HABITACIÓN / QR

CREATE TABLE hab.TarjetaHabitacion(
    IdTarjeta           INT IDENTITY(1,1) CONSTRAINT PK_Tarjeta PRIMARY KEY,
    IdReservaHabitacion INT NOT NULL CONSTRAINT FK_Tarjeta_RH  REFERENCES res.ReservaHabitacion(IdReservaHabitacion),
    IdHabitacion        INT NOT NULL CONSTRAINT FK_Tarjeta_Hab REFERENCES hab.Habitacion(IdHabitacion),
    CodigoTarjeta       VARCHAR(20) NOT NULL CONSTRAINT UQ_Tarjeta_Codigo UNIQUE,   -- impreso en la tarjeta física
    TokenQRHash         BINARY(32)  NOT NULL CONSTRAINT UQ_Tarjeta_Token  UNIQUE,   -- SHA-256 del token del QR
    ValidaDesde         DATETIME2(0) NOT NULL,
    ValidaHasta         DATETIME2(0) NOT NULL,
    Estado              VARCHAR(10) NOT NULL DEFAULT 'ACTIVA',
    EmitidaPor          INT NULL CONSTRAINT FK_Tarjeta_Usuario REFERENCES seg.Usuario(IdUsuario),
    FechaEmision        DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    FechaRevocacion     DATETIME2(0) NULL,
    CONSTRAINT CK_Tarjeta_Vigencia CHECK (ValidaHasta > ValidaDesde),
    CONSTRAINT CK_Tarjeta_Estado   CHECK (Estado IN ('ACTIVA','REVOCADA','EXPIRADA'))
);

CREATE TABLE hab.AccesoHabitacion(
    IdAcceso     BIGINT IDENTITY(1,1) CONSTRAINT PK_Acceso PRIMARY KEY,
    IdTarjeta    INT NULL CONSTRAINT FK_Acceso_Tarjeta REFERENCES hab.TarjetaHabitacion(IdTarjeta),
    IdHabitacion INT NOT NULL CONSTRAINT FK_Acceso_Hab REFERENCES hab.Habitacion(IdHabitacion),
    Medio        VARCHAR(10) NOT NULL CONSTRAINT CK_Acceso_Medio CHECK (Medio IN ('QR','TARJETA')),
    Permitido    BIT NOT NULL,
    Motivo       VARCHAR(100) NULL,
    Fecha        DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);


  -- 6. COCINA / SERVICIO A LA HABITACIÓN

CREATE TABLE coc.CategoriaMenu(
    IdCategoria INT IDENTITY(1,1) CONSTRAINT PK_CategoriaMenu PRIMARY KEY,
    Nombre      NVARCHAR(50) NOT NULL CONSTRAINT UQ_CategoriaMenu UNIQUE,   -- se traduce
    Activa      BIT NOT NULL DEFAULT 1
);

CREATE TABLE coc.ProductoMenu(
    IdProducto         INT IDENTITY(1,1) CONSTRAINT PK_ProductoMenu PRIMARY KEY,
    IdCategoria        INT NOT NULL CONSTRAINT FK_Producto_Categoria REFERENCES coc.CategoriaMenu(IdCategoria),
    Nombre             NVARCHAR(80) NOT NULL CONSTRAINT UQ_ProductoMenu UNIQUE,   -- se traduce
    Descripcion        NVARCHAR(300) NULL,                                       -- se traduce
    Precio             DECIMAL(12,2) NOT NULL CONSTRAINT CK_Producto_Precio CHECK (Precio > 0),
    MinutosPreparacion TINYINT NOT NULL CONSTRAINT CK_Producto_Min CHECK (MinutosPreparacion BETWEEN 1 AND 180),
    Stock              INT NULL CONSTRAINT CK_Producto_Stock CHECK (Stock IS NULL OR Stock >= 0),  -- NULL = sin control
    CodigoCabys        CHAR(13) NULL CONSTRAINT CK_Producto_Cabys CHECK (CodigoCabys IS NULL OR CodigoCabys NOT LIKE '%[^0-9]%'),
    Disponible         BIT NOT NULL DEFAULT 1,
    RowVer             ROWVERSION
);

CREATE TABLE coc.Pedido(
    IdPedido            INT IDENTITY(1,1) CONSTRAINT PK_Pedido PRIMARY KEY,
    IdReservaHabitacion INT NOT NULL CONSTRAINT FK_Pedido_RH  REFERENCES res.ReservaHabitacion(IdReservaHabitacion),
    IdHabitacion        INT NOT NULL CONSTRAINT FK_Pedido_Hab REFERENCES hab.Habitacion(IdHabitacion),
    Estado              VARCHAR(15) NOT NULL DEFAULT 'PENDIENTE',
    Subtotal            DECIMAL(12,2) NOT NULL DEFAULT 0,
    CargoServicio       DECIMAL(12,2) NOT NULL DEFAULT 0,
    Impuesto            DECIMAL(12,2) NOT NULL DEFAULT 0,
    Total AS (Subtotal + CargoServicio + Impuesto) PERSISTED,
    MinPreparacionEst   SMALLINT NOT NULL DEFAULT 0,
    MinEmpaqueEst       SMALLINT NOT NULL DEFAULT 0,
    MinEntregaEst       SMALLINT NOT NULL DEFAULT 0,
    Notas               VARCHAR(300) NULL,
    FechaPedido         DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    FechaConfirmado     DATETIME2(0) NULL,
    FechaPreparacion    DATETIME2(0) NULL,
    FechaEmpaquetado    DATETIME2(0) NULL,
    FechaEnCamino       DATETIME2(0) NULL,
    FechaEntregado      DATETIME2(0) NULL,
    FechaCancelado      DATETIME2(0) NULL,
    MotivoCancelacion   VARCHAR(200) NULL,
    IdUsuarioCocina     INT NULL CONSTRAINT FK_Pedido_Cocina  REFERENCES seg.Usuario(IdUsuario),
    IdUsuarioEntrega    INT NULL CONSTRAINT FK_Pedido_Entrega REFERENCES seg.Usuario(IdUsuario),
    Facturado           BIT NOT NULL DEFAULT 0,
    RowVer              ROWVERSION,
    CONSTRAINT CK_Pedido_Estado    CHECK (Estado IN ('PENDIENTE','CONFIRMADO','EN_PREPARACION','EMPAQUETADO','EN_CAMINO','ENTREGADO','CANCELADO')),
    CONSTRAINT CK_Pedido_Montos    CHECK (Subtotal >= 0 AND CargoServicio >= 0 AND Impuesto >= 0),
    CONSTRAINT CK_Pedido_Cancel    CHECK (Estado <> 'CANCELADO' OR MotivoCancelacion IS NOT NULL),
    CONSTRAINT CK_Pedido_Facturado CHECK (Facturado = 0 OR Estado = 'ENTREGADO')
);

CREATE TABLE coc.PedidoDetalle(
    IdPedidoDetalle INT IDENTITY(1,1) CONSTRAINT PK_PedidoDetalle PRIMARY KEY,
    IdPedido        INT NOT NULL CONSTRAINT FK_PD_Pedido   REFERENCES coc.Pedido(IdPedido),
    IdProducto      INT NOT NULL CONSTRAINT FK_PD_Producto REFERENCES coc.ProductoMenu(IdProducto),
    Cantidad        SMALLINT NOT NULL CONSTRAINT CK_PD_Cantidad CHECK (Cantidad BETWEEN 1 AND 50),
    PrecioUnitario  DECIMAL(12,2) NOT NULL CONSTRAINT CK_PD_Precio CHECK (PrecioUnitario > 0),
    Subtotal AS (CAST(Cantidad * PrecioUnitario AS DECIMAL(12,2))) PERSISTED,
    Notas           VARCHAR(150) NULL,
    CONSTRAINT UQ_PedidoDetalle UNIQUE (IdPedido, IdProducto)
);

CREATE TABLE coc.PedidoHistorial(
    IdHistorial    BIGINT IDENTITY(1,1) CONSTRAINT PK_PedidoHistorial PRIMARY KEY,
    IdPedido       INT NOT NULL CONSTRAINT FK_PH_Pedido REFERENCES coc.Pedido(IdPedido),
    EstadoAnterior VARCHAR(15) NULL,
    EstadoNuevo    VARCHAR(15) NOT NULL,
    IdUsuario      INT NULL,
    Fecha          DATETIME2(0) NOT NULL DEFAULT SYSDATETIME()
);


 -- 7. FACTURACIÓN ELECTRÓNICA

-- Consecutivo sin huecos por tipo de comprobante (se reserva dentro de la transacción que emite)
CREATE TABLE fac.ConsecutivoDocumento(
    TipoDocumento VARCHAR(2) NOT NULL CONSTRAINT PK_ConsecutivoDocumento PRIMARY KEY
                      CONSTRAINT CK_Consecutivo_Tipo CHECK (TipoDocumento IN ('FE','TE','NC')),
    Ultimo        BIGINT NOT NULL DEFAULT 0 CONSTRAINT CK_Consecutivo_Ultimo CHECK (Ultimo BETWEEN 0 AND 9999999999)
);

/* Comprobante electrónico:
   - FE = factura electrónica (receptor con cédula o DIMEX) | TE = tiquete electrónico (receptor con pasaporte)
   - NC = nota de crédito: la ÚNICA forma de anular un comprobante (Hacienda no permite borrar ni editar)
   - Los datos del receptor se copian al emitir: si la persona cambia luego, el comprobante no cambia
   - Los XML se guardan como VARBINARY para conservar los bytes exactos de la firma digital */
CREATE TABLE fac.Factura(
    IdFactura             INT IDENTITY(1,1) CONSTRAINT PK_Factura PRIMARY KEY,
    NumeroFactura         AS ('FAC-' + RIGHT('00000000' + CAST(IdFactura AS VARCHAR(10)), 8)) PERSISTED,  -- número interno
    TipoDocumento         VARCHAR(2)  NOT NULL CONSTRAINT CK_Factura_TipoDoc CHECK (TipoDocumento IN ('FE','TE','NC')),
    Consecutivo           CHAR(20)    NOT NULL CONSTRAINT UQ_Factura_Consecutivo UNIQUE,
    Clave                 CHAR(50)    NOT NULL CONSTRAINT UQ_Factura_Clave UNIQUE,
    CodigoActividad       CHAR(6)     NOT NULL,
    CondicionVenta        CHAR(2)     NOT NULL DEFAULT '01',     -- 01 contado, 02 crédito
    MedioPago             CHAR(2)     NULL,                      -- 01 efectivo, 02 tarjeta, 04 transferencia, 06 SINPE Móvil
    Moneda                CHAR(3)     NOT NULL DEFAULT 'CRC',
    TipoCambio            DECIMAL(18,5) NOT NULL DEFAULT 1,
    IdReserva             INT NOT NULL CONSTRAINT FK_Factura_Reserva REFERENCES res.Reserva(IdReserva),
    IdCliente             INT NOT NULL CONSTRAINT FK_Factura_Cliente REFERENCES res.Cliente(IdCliente),
    ReceptorNombre        VARCHAR(160) NOT NULL,
    ReceptorTipoId        VARCHAR(15)  NOT NULL,
    ReceptorIdentificacion VARCHAR(30) NOT NULL,
    ReceptorCorreo        VARCHAR(150) NOT NULL,
    TipoFactura           VARCHAR(12) NOT NULL CONSTRAINT CK_Factura_Tipo CHECK (TipoFactura IN ('ESTADIA','PENALIZACION')),
    IdFacturaReferencia   INT NULL CONSTRAINT FK_Factura_Referencia REFERENCES fac.Factura(IdFactura),
    CodigoReferencia      CHAR(2) NULL,                          -- 01 = anula documento de referencia
    RazonReferencia       VARCHAR(180) NULL,
    FechaEmision          DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    Subtotal              DECIMAL(12,2) NOT NULL,
    Descuento             DECIMAL(12,2) NOT NULL DEFAULT 0,
    Impuesto              DECIMAL(12,2) NOT NULL DEFAULT 0,
    Total                 DECIMAL(12,2) NOT NULL,
    Estado                VARCHAR(10) NOT NULL DEFAULT 'EMITIDA',
    EmitidaPor            INT NULL CONSTRAINT FK_Factura_Emisor  REFERENCES seg.Usuario(IdUsuario),
    MotivoAnulacion       VARCHAR(300) NULL,
    FechaAnulacion        DATETIME2(0) NULL,
    AnuladaPor            INT NULL CONSTRAINT FK_Factura_Anulador REFERENCES seg.Usuario(IdUsuario),
    EstadoHacienda        VARCHAR(10) NOT NULL DEFAULT 'PENDIENTE',
    XmlComprobante        VARBINARY(MAX) NULL,                   -- XML firmado enviado a Hacienda
    XmlRespuesta          VARBINARY(MAX) NULL,                   -- mensaje de respuesta de Hacienda
    MensajeHacienda       VARCHAR(500) NULL,
    FechaEnvioHacienda    DATETIME2(0) NULL,
    FechaRespuestaHacienda DATETIME2(0) NULL,
    CONSTRAINT CK_Factura_Estado    CHECK (Estado IN ('EMITIDA','PAGADA','ANULADA')),
    CONSTRAINT CK_Factura_EstadoMH  CHECK (EstadoHacienda IN ('PENDIENTE','ENVIADA','ACEPTADA','RECHAZADA')),
    CONSTRAINT CK_Factura_Condicion CHECK (CondicionVenta IN ('01','02')),
    CONSTRAINT CK_Factura_MedioPago CHECK (MedioPago IS NULL OR MedioPago IN ('01','02','04','06')),
    CONSTRAINT CK_Factura_Moneda    CHECK (Moneda IN ('CRC','USD') AND TipoCambio > 0 AND (Moneda <> 'CRC' OR TipoCambio = 1)),
    CONSTRAINT CK_Factura_Numeros   CHECK (Consecutivo NOT LIKE '%[^0-9]%' AND Clave NOT LIKE '%[^0-9]%' AND CodigoActividad NOT LIKE '%[^0-9]%'),
    CONSTRAINT CK_Factura_NC        CHECK ((TipoDocumento = 'NC' AND IdFacturaReferencia IS NOT NULL AND CodigoReferencia IS NOT NULL AND RazonReferencia IS NOT NULL)
                                        OR (TipoDocumento <> 'NC' AND IdFacturaReferencia IS NULL AND CodigoReferencia IS NULL)),
    CONSTRAINT CK_Factura_NCEstado  CHECK (TipoDocumento <> 'NC' OR Estado = 'EMITIDA'),
    CONSTRAINT CK_Factura_Montos    CHECK (Subtotal >= 0 AND Descuento >= 0 AND Descuento <= Subtotal AND Impuesto >= 0
                                           AND Total = Subtotal - Descuento + Impuesto),
    CONSTRAINT CK_Factura_Anulada   CHECK (Estado <> 'ANULADA' OR (MotivoAnulacion IS NOT NULL AND FechaAnulacion IS NOT NULL)),
    CONSTRAINT CK_Factura_Enviada   CHECK (EstadoHacienda = 'PENDIENTE' OR (XmlComprobante IS NOT NULL AND FechaEnvioHacienda IS NOT NULL))
);
-- Nunca dos comprobantes vigentes para la misma reservación (evita doble cobro); las notas de crédito no cuentan
CREATE UNIQUE INDEX UX_Factura_ReservaVigente ON fac.Factura(IdReserva) WHERE Estado <> 'ANULADA' AND TipoDocumento <> 'NC';
-- Un comprobante se anula con UNA sola nota de crédito
CREATE UNIQUE INDEX UX_Factura_NC ON fac.Factura(IdFacturaReferencia) WHERE IdFacturaReferencia IS NOT NULL;

/* Línea del comprobante (estructura de LineaDetalle de Hacienda):
   MontoTotal = Cantidad × Precio | SubTotal = MontoTotal - Descuento | TotalLinea = SubTotal + Impuesto
   Los montos derivados son columnas calculadas: no pueden quedar descuadrados. */
CREATE TABLE fac.FacturaDetalle(
    IdFacturaDetalle    INT IDENTITY(1,1) CONSTRAINT PK_FacturaDetalle PRIMARY KEY,
    IdFactura           INT NOT NULL CONSTRAINT FK_FD_Factura REFERENCES fac.Factura(IdFactura),
    NumeroLinea         SMALLINT NOT NULL,
    TipoLinea           VARCHAR(20) NOT NULL,
    CodigoCabys         CHAR(13) NULL,
    Descripcion         VARCHAR(200) NOT NULL,
    Cantidad            DECIMAL(10,2) NOT NULL CONSTRAINT CK_FD_Cantidad CHECK (Cantidad > 0),
    UnidadMedida        VARCHAR(10) NOT NULL DEFAULT 'Unid',
    PrecioUnitario      DECIMAL(12,2) NOT NULL CONSTRAINT CK_FD_Precio CHECK (PrecioUnitario >= 0),
    MontoTotal    AS (CAST(Cantidad * PrecioUnitario AS DECIMAL(12,2))) PERSISTED,
    IdDescuento         INT NULL CONSTRAINT FK_FD_Descuento REFERENCES res.Descuento(IdDescuento),
    PorcentajeDescuento DECIMAL(5,2)  NOT NULL DEFAULT 0,
    MontoDescuento      DECIMAL(12,2) NOT NULL DEFAULT 0,
    NaturalezaDescuento VARCHAR(80) NULL,
    SubTotal      AS (CAST(CAST(Cantidad * PrecioUnitario AS DECIMAL(12,2)) - MontoDescuento AS DECIMAL(12,2))) PERSISTED,
    PorcentajeImpuesto  DECIMAL(5,2) NOT NULL DEFAULT 0,
    MontoImpuesto AS (CAST(ROUND((CAST(Cantidad * PrecioUnitario AS DECIMAL(12,2)) - MontoDescuento) * PorcentajeImpuesto / 100, 2) AS DECIMAL(12,2))) PERSISTED,
    TotalLinea    AS (CAST(CAST(Cantidad * PrecioUnitario AS DECIMAL(12,2)) - MontoDescuento
                         + ROUND((CAST(Cantidad * PrecioUnitario AS DECIMAL(12,2)) - MontoDescuento) * PorcentajeImpuesto / 100, 2) AS DECIMAL(12,2))) PERSISTED,
    IdReservaHabitacion INT NULL CONSTRAINT FK_FD_RH     REFERENCES res.ReservaHabitacion(IdReservaHabitacion),
    IdPedido            INT NULL CONSTRAINT FK_FD_Pedido REFERENCES coc.Pedido(IdPedido),
    CONSTRAINT UQ_FD_Linea      UNIQUE (IdFactura, NumeroLinea),
    CONSTRAINT CK_FD_Tipo       CHECK (TipoLinea IN ('HOSPEDAJE','PERSONA_EXTRA','SERVICIO_HABITACION','CARGO_SERVICIO','PENALIZACION')),
    CONSTRAINT CK_FD_Descuento  CHECK (MontoDescuento >= 0 AND MontoDescuento <= CAST(Cantidad * PrecioUnitario AS DECIMAL(12,2))
                                       AND PorcentajeDescuento BETWEEN 0 AND 100
                                       AND (MontoDescuento = 0 OR NaturalezaDescuento IS NOT NULL)),
    CONSTRAINT CK_FD_Impuesto   CHECK (PorcentajeImpuesto BETWEEN 0 AND 100),
    CONSTRAINT CK_FD_Cabys      CHECK (CodigoCabys IS NULL OR CodigoCabys NOT LIKE '%[^0-9]%')
);

ALTER TABLE res.Pago ADD CONSTRAINT FK_Pago_Factura FOREIGN KEY (IdFactura) REFERENCES fac.Factura(IdFactura);
GO
-- Líneas de un comprobante: la usan los procedimientos que emiten facturas y notas de crédito
CREATE TYPE fac.tp_LineaFactura AS TABLE(
    Orden               INT IDENTITY(1,1) PRIMARY KEY,
    TipoLinea           VARCHAR(20)   NOT NULL,
    CodigoCabys         CHAR(13)      NULL,
    Descripcion         VARCHAR(200)  NOT NULL,
    Cantidad            DECIMAL(10,2) NOT NULL,
    UnidadMedida        VARCHAR(10)   NOT NULL DEFAULT 'Unid',
    PrecioUnitario      DECIMAL(12,2) NOT NULL,
    IdDescuento         INT           NULL,
    PorcentajeDescuento DECIMAL(5,2)  NOT NULL DEFAULT 0,
    MontoDescuento      DECIMAL(12,2) NOT NULL DEFAULT 0,
    NaturalezaDescuento VARCHAR(80)   NULL,
    PorcentajeImpuesto  DECIMAL(5,2)  NOT NULL DEFAULT 0,
    IdReservaHabitacion INT           NULL,
    IdPedido            INT           NULL
);
GO


  -- 8. EMPLEADOS Y PLANILLA

CREATE TABLE rh.Puesto(
    IdPuesto INT IDENTITY(1,1) CONSTRAINT PK_Puesto PRIMARY KEY,
    Nombre   VARCHAR(60) NOT NULL CONSTRAINT UQ_Puesto UNIQUE,
    IdRol    INT NULL CONSTRAINT FK_Puesto_Rol REFERENCES seg.Rol(IdRol),   -- rol sugerido en la web
    Activo   BIT NOT NULL DEFAULT 1
);

-- Subtipo de Persona: solo guarda lo propio del empleado
CREATE TABLE rh.Empleado(
    IdEmpleado     INT NOT NULL CONSTRAINT PK_Empleado PRIMARY KEY
                       CONSTRAINT FK_Empleado_Persona REFERENCES dbo.Persona(IdPersona),
    IdPuesto       INT NOT NULL CONSTRAINT FK_Empleado_Puesto REFERENCES rh.Puesto(IdPuesto),
    TipoSalario    VARCHAR(10) NOT NULL CONSTRAINT CK_Empleado_TipoSal CHECK (TipoSalario IN ('MENSUAL','POR_HORA')),
    MontoSalario   DECIMAL(12,2) NOT NULL CONSTRAINT CK_Empleado_Salario CHECK (MontoSalario > 0), -- mensual o tarifa/hora
    CuentaIBAN     VARCHAR(22) NULL,
    FechaIngreso   DATE NOT NULL,
    FechaSalida    DATE NULL,
    Activo         BIT NOT NULL DEFAULT 1,
    CONSTRAINT CK_Empleado_Fechas CHECK (FechaSalida IS NULL OR FechaSalida >= FechaIngreso),
    CONSTRAINT CK_Empleado_Baja   CHECK (Activo = 1 OR FechaSalida IS NOT NULL),
    CONSTRAINT CK_Empleado_IBAN   CHECK (CuentaIBAN IS NULL OR (LEN(CuentaIBAN) = 22 AND LEFT(CuentaIBAN, 2) = 'CR'
                                         AND SUBSTRING(CuentaIBAN, 3, 20) NOT LIKE '%[^0-9]%'))
);

CREATE TABLE rh.RegistroHoras(
    IdRegistro      INT IDENTITY(1,1) CONSTRAINT PK_RegistroHoras PRIMARY KEY,
    IdEmpleado      INT NOT NULL CONSTRAINT FK_Horas_Empleado REFERENCES rh.Empleado(IdEmpleado),
    Fecha           DATE NOT NULL,
    HorasOrdinarias DECIMAL(4,2) NOT NULL DEFAULT 0,
    HorasExtra      DECIMAL(4,2) NOT NULL DEFAULT 0,
    Aprobado        BIT NOT NULL DEFAULT 0,
    AprobadoPor     INT NULL CONSTRAINT FK_Horas_Usuario REFERENCES seg.Usuario(IdUsuario),
    CONSTRAINT UQ_RegistroHoras UNIQUE (IdEmpleado, Fecha),
    CONSTRAINT CK_Horas CHECK (HorasOrdinarias BETWEEN 0 AND 12 AND HorasExtra BETWEEN 0 AND 4 AND HorasOrdinarias + HorasExtra <= 12)
);

CREATE TABLE rh.Planilla(
    IdPlanilla      INT IDENTITY(1,1) CONSTRAINT PK_Planilla PRIMARY KEY,
    TipoPeriodo     VARCHAR(10) NOT NULL CONSTRAINT CK_Planilla_Tipo CHECK (TipoPeriodo IN ('QUINCENAL','MENSUAL')),
    FechaInicio     DATE NOT NULL,
    FechaFin        DATE NOT NULL,
    FechaPago       DATE NOT NULL,
    Estado          VARCHAR(10) NOT NULL DEFAULT 'BORRADOR',
    CreadaPor       INT NOT NULL CONSTRAINT FK_Planilla_Creador  REFERENCES seg.Usuario(IdUsuario),
    AprobadaPor     INT NULL     CONSTRAINT FK_Planilla_Aprobador REFERENCES seg.Usuario(IdUsuario),
    FechaAprobacion DATETIME2(0) NULL,
    FechaCreacion   DATETIME2(0) NOT NULL DEFAULT SYSDATETIME(),
    CONSTRAINT CK_Planilla_Estado    CHECK (Estado IN ('BORRADOR','APROBADA','PAGADA','ANULADA')),
    CONSTRAINT CK_Planilla_Fechas    CHECK (FechaFin >= FechaInicio AND FechaPago >= FechaFin),
    CONSTRAINT CK_Planilla_Separacion CHECK (AprobadaPor IS NULL OR AprobadaPor <> CreadaPor),   -- quien crea no aprueba
    CONSTRAINT CK_Planilla_Aprobada  CHECK (Estado NOT IN ('APROBADA','PAGADA') OR AprobadaPor IS NOT NULL)
);
CREATE UNIQUE INDEX UX_Planilla_Periodo ON rh.Planilla(TipoPeriodo, FechaInicio) WHERE Estado <> 'ANULADA';

CREATE TABLE rh.PlanillaDetalle(
    IdPlanillaDetalle INT IDENTITY(1,1) CONSTRAINT PK_PlanillaDetalle PRIMARY KEY,
    IdPlanilla        INT NOT NULL CONSTRAINT FK_PD_Planilla REFERENCES rh.Planilla(IdPlanilla),
    IdEmpleado        INT NOT NULL CONSTRAINT FK_PD_Empleado REFERENCES rh.Empleado(IdEmpleado),
    SalarioBase       DECIMAL(12,2) NOT NULL,
    HorasOrdinarias   DECIMAL(6,2)  NOT NULL DEFAULT 0,
    HorasExtra        DECIMAL(6,2)  NOT NULL DEFAULT 0,
    MontoHorasExtra   DECIMAL(12,2) NOT NULL DEFAULT 0,
    Bonificaciones    DECIMAL(12,2) NOT NULL DEFAULT 0,
    PorcentajeCCSS    DECIMAL(5,2)  NOT NULL,
    ImpuestoRenta     DECIMAL(12,2) NOT NULL DEFAULT 0,
    OtrasDeducciones  DECIMAL(12,2) NOT NULL DEFAULT 0,
    SalarioBruto  AS (SalarioBase + MontoHorasExtra + Bonificaciones) PERSISTED,
    DeduccionCCSS AS (CAST(ROUND((SalarioBase + MontoHorasExtra + Bonificaciones) * PorcentajeCCSS / 100, 2) AS DECIMAL(12,2))) PERSISTED,
    SalarioNeto   AS (CAST(SalarioBase + MontoHorasExtra + Bonificaciones
                      - ROUND((SalarioBase + MontoHorasExtra + Bonificaciones) * PorcentajeCCSS / 100, 2)
                      - ImpuestoRenta - OtrasDeducciones AS DECIMAL(12,2))) PERSISTED,
    CONSTRAINT UQ_PlanillaDetalle UNIQUE (IdPlanilla, IdEmpleado),
    CONSTRAINT CK_PD_Montos CHECK (SalarioBase >= 0 AND MontoHorasExtra >= 0 AND Bonificaciones >= 0
                                   AND ImpuestoRenta >= 0 AND OtrasDeducciones >= 0 AND PorcentajeCCSS BETWEEN 0 AND 100),
    CONSTRAINT CK_PD_Neto CHECK (SalarioBase + MontoHorasExtra + Bonificaciones - ImpuestoRenta - OtrasDeducciones
                                 - (SalarioBase + MontoHorasExtra + Bonificaciones) * PorcentajeCCSS / 100 >= 0)
);
GO

-- 9. ÍNDICES

CREATE INDEX IX_RH_Habitacion_Fechas ON res.ReservaHabitacion(IdHabitacion, FechaDesde, FechaHasta) INCLUDE (Estado, IdReserva);
CREATE INDEX IX_RH_Reserva          ON res.ReservaHabitacion(IdReserva) INCLUDE (Estado);
CREATE INDEX IX_Reserva_Cliente     ON res.Reserva(IdCliente, Estado);
CREATE INDEX IX_Reserva_Estado      ON res.Reserva(Estado, FechaExpiracion, FechaEntrada);
CREATE INDEX IX_Reserva_Descuento   ON res.Reserva(IdDescuento, Estado) WHERE IdDescuento IS NOT NULL;
CREATE INDEX IX_Pago_Reserva        ON res.Pago(IdReserva) INCLUDE (TipoMovimiento, Monto, Anulado);
CREATE INDEX IX_Abono_Vencimiento   ON res.Abono(Estado, FechaLimite);
CREATE INDEX IX_Temporada_Fechas    ON hab.Temporada(FechaInicio, FechaFin) INCLUDE (PorcentajeAjuste) WHERE Activa = 1;
CREATE INDEX IX_Pedido_Estado       ON coc.Pedido(Estado, FechaPedido);
CREATE INDEX IX_Pedido_RH           ON coc.Pedido(IdReservaHabitacion);
CREATE INDEX IX_Tarjeta_RH          ON hab.TarjetaHabitacion(IdReservaHabitacion, Estado);
CREATE INDEX IX_Bloqueo_Hab         ON hab.BloqueoHabitacion(IdHabitacion, FechaDesde, FechaHasta) WHERE Activo = 1;
CREATE INDEX IX_IntentoLogin        ON seg.IntentoLogin(LoginIngresado, Fecha);
CREATE INDEX IX_IntentoLogin_Ip     ON seg.IntentoLogin(IpOrigen, Fecha);
CREATE INDEX IX_RefreshToken_Usr    ON seg.RefreshToken(IdUsuario) WHERE FechaRevocacion IS NULL;
CREATE INDEX IX_ColaCorreo_Pend     ON dbo.ColaCorreo(FechaCreacion) WHERE Estado = 'PENDIENTE';
CREATE INDEX IX_Factura_Hacienda    ON fac.Factura(EstadoHacienda, FechaEmision) WHERE EstadoHacienda IN ('PENDIENTE','ENVIADA');
CREATE INDEX IX_FD_Pedido           ON fac.FacturaDetalle(IdPedido) WHERE IdPedido IS NOT NULL;
CREATE INDEX IX_Bitacora            ON aud.Bitacora(Tabla, IdRegistro);
GO

-- 10. FUNCIONES

CREATE FUNCTION dbo.fn_Param(@Clave VARCHAR(50)) RETURNS DECIMAL(18,4)
AS
BEGIN
    RETURN (SELECT Valor FROM dbo.Parametro WHERE Clave = @Clave);
END
GO
CREATE FUNCTION dbo.fn_TransicionValida(@Entidad VARCHAR(20), @Origen VARCHAR(20), @Destino VARCHAR(20)) RETURNS BIT
AS
BEGIN
    RETURN CASE WHEN EXISTS (SELECT 1 FROM dbo.TransicionEstado
                             WHERE Entidad = @Entidad AND EstadoOrigen = @Origen AND EstadoDestino = @Destino) THEN 1 ELSE 0 END;
END
GO
-- Una fila por noche del rango [@Desde, @Hasta) — máximo 64 noches (una reservación permite 60)
CREATE FUNCTION dbo.fn_Fechas(@Desde DATE, @Hasta DATE) RETURNS TABLE
AS RETURN
SELECT DATEADD(DAY, x.n, @Desde) AS Fecha
FROM (SELECT a.d * 8 + b.d AS n
      FROM (VALUES (0),(1),(2),(3),(4),(5),(6),(7)) a(d)
      CROSS JOIN (VALUES (0),(1),(2),(3),(4),(5),(6),(7)) b(d)) x
WHERE x.n < DATEDIFF(DAY, @Desde, @Hasta);
GO
-- Temporada que aplica a una noche (ninguna fila = tarifa base)
CREATE FUNCTION hab.fn_AjusteTemporada(@Fecha DATE) RETURNS TABLE
AS RETURN
SELECT TOP (1) t.IdTemporada, t.Nombre, t.Tipo, t.PorcentajeAjuste
FROM hab.Temporada t
WHERE t.Activa = 1 AND @Fecha BETWEEN t.FechaInicio AND t.FechaFin
ORDER BY t.IdTemporada;
GO
-- Cotización del hospedaje noche por noche con temporada (mismo redondeo que res.sp_GenerarNoches)
CREATE FUNCTION hab.fn_CotizarHospedaje(@IdTipoHabitacion INT, @Desde DATE, @Hasta DATE, @Personas INT) RETURNS DECIMAL(12,2)
AS
BEGIN
    RETURN (SELECT CAST(ISNULL(SUM(ROUND(t.PrecioNoche * (100 + ISNULL(a.PorcentajeAjuste, 0)) / 100, 2)
                                 + ROUND(t.PrecioPersonaExtra * (100 + ISNULL(a.PorcentajeAjuste, 0)) / 100, 2)
                                   * IIF(@Personas > t.CapacidadBase, @Personas - t.CapacidadBase, 0)), 0) AS DECIMAL(12,2))
            FROM hab.TipoHabitacion t
            CROSS APPLY dbo.fn_Fechas(@Desde, @Hasta) f
            OUTER APPLY hab.fn_AjusteTemporada(f.Fecha) a
            WHERE t.IdTipoHabitacion = @IdTipoHabitacion);
END
GO
-- @Accion: V=ver, C=crear, E=editar, A=anular. El usuario es genérico: solo cuentan sus roles
CREATE FUNCTION seg.fn_TienePermiso(@IdUsuario INT, @CodigoModulo VARCHAR(30), @Accion CHAR(1)) RETURNS BIT
AS
BEGIN
    IF EXISTS (SELECT 1
               FROM seg.Usuario u
               JOIN seg.UsuarioRol ur ON ur.IdUsuario = u.IdUsuario
               JOIN seg.Rol r         ON r.IdRol = ur.IdRol AND r.Activo = 1
               JOIN seg.RolModulo rm  ON rm.IdRol = r.IdRol
               JOIN seg.Modulo m      ON m.IdModulo = rm.IdModulo AND m.Activo = 1
               WHERE u.IdUsuario = @IdUsuario AND u.Activo = 1
                 AND m.Codigo = @CodigoModulo
                 AND (   (@Accion = 'V' AND rm.PuedeVer = 1)    OR (@Accion = 'C' AND rm.PuedeCrear = 1)
                      OR (@Accion = 'E' AND rm.PuedeEditar = 1) OR (@Accion = 'A' AND rm.PuedeAnular = 1)))
        RETURN 1;
    RETURN 0;
END
GO
CREATE FUNCTION res.fn_HabitacionDisponible(@IdHabitacion INT, @Desde DATE, @Hasta DATE, @ExcluirLinea INT) RETURNS BIT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM hab.Habitacion WHERE IdHabitacion = @IdHabitacion AND (Activa = 0 OR Estado = 'FUERA_SERVICIO'))
        RETURN 0;
    IF EXISTS (SELECT 1 FROM res.ReservaHabitacion lin
               JOIN res.Reserva r ON r.IdReserva = lin.IdReserva
               WHERE lin.IdHabitacion = @IdHabitacion AND lin.Estado = 'ACTIVA'
                 AND r.Estado IN ('PENDIENTE','CONFIRMADA','CHECKIN')
                 AND lin.FechaDesde < @Hasta AND @Desde < lin.FechaHasta
                 AND (@ExcluirLinea IS NULL OR lin.IdReservaHabitacion <> @ExcluirLinea))
        RETURN 0;
    IF EXISTS (SELECT 1 FROM hab.BloqueoHabitacion b
               WHERE b.IdHabitacion = @IdHabitacion AND b.Activo = 1 AND b.FechaDesde < @Hasta AND @Desde < b.FechaHasta)
        RETURN 0;
    RETURN 1;
END
GO
-- ¿El descuento puede aplicarse a esta reservación? (vigencia, temporada, noches mínimas, cliente frecuente, usos)
CREATE FUNCTION res.fn_DescuentoAplicable(@IdDescuento INT, @IdCliente INT, @Entrada DATE, @Salida DATE, @ExcluirReserva INT) RETURNS BIT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM res.Descuento d
               WHERE d.IdDescuento = @IdDescuento AND d.Activo = 1
                 AND (d.FechaInicio IS NULL OR @Entrada >= d.FechaInicio)
                 AND (d.FechaFin    IS NULL OR @Entrada <= d.FechaFin)
                 AND (d.IdTemporada IS NULL OR EXISTS (SELECT 1 FROM hab.Temporada t
                                                       WHERE t.IdTemporada = d.IdTemporada AND t.Activa = 1
                                                         AND @Entrada BETWEEN t.FechaInicio AND t.FechaFin))
                 AND (d.MinNoches IS NULL OR DATEDIFF(DAY, @Entrada, @Salida) >= d.MinNoches)
                 AND (d.Clase <> 'CLIENTE_FRECUENTE' OR EXISTS (SELECT 1 FROM res.Cliente c WHERE c.IdCliente = @IdCliente AND c.EsFrecuente = 1))
                 AND (d.UsosMaximos IS NULL OR d.UsosMaximos > (SELECT COUNT(*) FROM res.Reserva r
                                                                WHERE r.IdDescuento = d.IdDescuento AND r.Estado NOT IN ('CANCELADA','EXPIRADA')
                                                                  AND (@ExcluirReserva IS NULL OR r.IdReserva <> @ExcluirReserva))))
        RETURN 1;
    RETURN 0;
END
GO
-- Monto que el descuento rebaja del HOSPEDAJE (0 si solo aplica al servicio a la habitación)
CREATE FUNCTION res.fn_MontoDescuento(@IdDescuento INT, @Base DECIMAL(12,2)) RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @m DECIMAL(12,2);
    SELECT @m = CASE WHEN d.Tipo = 'PORCENTAJE' THEN ROUND(@Base * d.Valor / 100, 2)
                     WHEN d.Valor > @Base       THEN @Base
                     ELSE d.Valor END
    FROM res.Descuento d WHERE d.IdDescuento = @IdDescuento AND d.AplicaA IN ('HOSPEDAJE','TODO');
    RETURN ISNULL(@m, 0);
END
GO
-- Reparte lo pagado de la reservación entre sus cuotas, en orden (FIFO)
CREATE FUNCTION res.fn_DistribucionAbonos(@IdReserva INT) RETURNS TABLE
AS RETURN
SELECT a.IdAbono,
       CAST(CASE WHEN r.MontoPagado >= x.Acumulado                       THEN a.MontoProgramado
                 WHEN r.MontoPagado >  x.Acumulado - a.MontoProgramado   THEN r.MontoPagado - (x.Acumulado - a.MontoProgramado)
                 ELSE 0 END AS DECIMAL(12,2)) AS Pagado
FROM res.Abono a
JOIN res.Reserva r ON r.IdReserva = a.IdReserva
CROSS APPLY (SELECT SUM(b.MontoProgramado) AS Acumulado FROM res.Abono b
             WHERE b.IdReserva = a.IdReserva AND b.Numero <= a.Numero AND b.Estado <> 'ANULADO') x
WHERE a.IdReserva = @IdReserva AND a.Estado <> 'ANULADO';
GO
/* Cálculo de cancelación:
   - Horas de antelación = horas entre la cancelación y la hora de check-in del día de entrada
   - Tramo de política según esas horas -> % de lo PAGADO que se retiene
   - Cliente frecuente: rebaja PCT_DESC_PENALIZACION_FRECUENTE sobre ese %                      */
CREATE FUNCTION res.fn_CalculoCancelacion(@IdReserva INT, @Fecha DATETIME2(0))
RETURNS TABLE
AS RETURN
WITH b AS (
    SELECT r.IdReserva, r.MontoPagado, c.EsFrecuente,
           DATEDIFF(HOUR, @Fecha, DATEADD(HOUR, CAST(dbo.fn_Param('HORA_CHECKIN') AS INT), CAST(r.FechaEntrada AS DATETIME2(0)))) AS HorasAntelacion
    FROM res.Reserva r JOIN res.Cliente c ON c.IdCliente = r.IdCliente
    WHERE r.IdReserva = @IdReserva
), p AS (
    SELECT b.*, pol.IdPolitica, pol.Nombre AS Politica, ISNULL(pol.PorcentajePenalizacion, 0) AS PorcentajePenalizacion
    FROM b
    OUTER APPLY (SELECT TOP (1) x.IdPolitica, x.Nombre, x.PorcentajePenalizacion
                 FROM res.PoliticaCancelacion x
                 WHERE x.Activa = 1 AND x.HorasMinimas <= IIF(b.HorasAntelacion < 0, 0, b.HorasAntelacion)
                 ORDER BY x.HorasMinimas DESC) pol
), k AS (
    SELECT p.*, CAST(IIF(p.EsFrecuente = 1,
                     p.PorcentajePenalizacion * (100 - dbo.fn_Param('PCT_DESC_PENALIZACION_FRECUENTE')) / 100,
                     p.PorcentajePenalizacion) AS DECIMAL(5,2)) AS PorcentajeAplicado
    FROM p
)
SELECT IdReserva, HorasAntelacion, IdPolitica, Politica, PorcentajePenalizacion, EsFrecuente, PorcentajeAplicado, MontoPagado,
       CAST(ROUND(MontoPagado * PorcentajeAplicado / 100, 2) AS DECIMAL(12,2))               AS MontoRetenido,
       CAST(MontoPagado - ROUND(MontoPagado * PorcentajeAplicado / 100, 2) AS DECIMAL(12,2)) AS MontoReembolso
FROM k;
GO

/* 11. VISTAS */
-- Seguimiento del pedido para la app: etapa, minutos restantes y hora estimada
CREATE VIEW coc.vw_SeguimientoPedido
AS
SELECT p.IdPedido, p.IdReservaHabitacion, r.IdCliente, h.Codigo AS Habitacion, p.Estado,
       CASE p.Estado WHEN 'PENDIENTE' THEN 0 WHEN 'CONFIRMADO' THEN 1 WHEN 'EN_PREPARACION' THEN 2
                     WHEN 'EMPAQUETADO' THEN 3 WHEN 'EN_CAMINO' THEN 4 WHEN 'ENTREGADO' THEN 5 ELSE -1 END AS Etapa,
       p.FechaPedido, p.Subtotal, p.CargoServicio, p.Impuesto, p.Total,
       p.MinPreparacionEst, p.MinEmpaqueEst, p.MinEntregaEst,
       x.MinutosRestantes,
       CASE WHEN p.Estado = 'ENTREGADO' THEN p.FechaEntregado
            WHEN p.Estado = 'CANCELADO' THEN NULL
            ELSE DATEADD(MINUTE, x.MinutosRestantes, SYSDATETIME()) END AS HoraEstimadaEntrega,
       CASE WHEN p.Estado = 'ENTREGADO' THEN 100 WHEN p.Estado = 'CANCELADO' THEN 0
            ELSE CAST(100 - 100.0 * x.MinutosRestantes / NULLIF(p.MinPreparacionEst + p.MinEmpaqueEst + p.MinEntregaEst, 0) AS INT) END AS Progreso,
       CAST(CASE WHEN p.Estado IN ('PENDIENTE','CONFIRMADO') THEN 1 ELSE 0 END AS BIT) AS PuedeCancelarse
FROM coc.Pedido p
JOIN hab.Habitacion h         ON h.IdHabitacion = p.IdHabitacion
JOIN res.ReservaHabitacion lin ON lin.IdReservaHabitacion = p.IdReservaHabitacion
JOIN res.Reserva r            ON r.IdReserva = lin.IdReserva
CROSS APPLY (SELECT DATEDIFF(MINUTE, p.FechaPreparacion, SYSDATETIME()) AS TPrep,
                    DATEDIFF(MINUTE, p.FechaEmpaquetado, SYSDATETIME()) AS TEmp,
                    DATEDIFF(MINUTE, p.FechaEnCamino,    SYSDATETIME()) AS TEnt) t
CROSS APPLY (SELECT CASE p.Estado
        WHEN 'PENDIENTE'      THEN p.MinPreparacionEst + p.MinEmpaqueEst + p.MinEntregaEst
        WHEN 'CONFIRMADO'     THEN p.MinPreparacionEst + p.MinEmpaqueEst + p.MinEntregaEst
        WHEN 'EN_PREPARACION' THEN IIF(p.MinPreparacionEst > t.TPrep, p.MinPreparacionEst - t.TPrep, 0) + p.MinEmpaqueEst + p.MinEntregaEst
        WHEN 'EMPAQUETADO'    THEN IIF(p.MinEmpaqueEst > t.TEmp, p.MinEmpaqueEst - t.TEmp, 0) + p.MinEntregaEst
        WHEN 'EN_CAMINO'      THEN IIF(p.MinEntregaEst > t.TEnt, p.MinEntregaEst - t.TEnt, 0)
        ELSE 0 END AS MinutosRestantes) x;
GO
CREATE VIEW hab.vw_OcupacionHoy
AS
SELECT e.Codigo AS Edificio, COUNT(*) AS TotalHabitaciones,
       SUM(CASE WHEN h.Estado = 'OCUPADA'  THEN 1 ELSE 0 END) AS Ocupadas,
       SUM(CASE WHEN h.Estado = 'LIMPIEZA' THEN 1 ELSE 0 END) AS EnLimpieza,
       SUM(CASE WHEN h.Estado IN ('MANTENIMIENTO','FUERA_SERVICIO') THEN 1 ELSE 0 END) AS FueraDeServicio,
       SUM(a.Reservada) AS ReservadasHoy,
       CAST(100.0 * SUM(a.Reservada) / COUNT(*) AS DECIMAL(5,2)) AS PorcentajeOcupacion
FROM hab.Habitacion h
JOIN hab.Piso p     ON p.IdPiso = h.IdPiso
JOIN hab.Edificio e ON e.IdEdificio = p.IdEdificio
OUTER APPLY (SELECT CASE WHEN EXISTS (
                 SELECT 1 FROM res.ReservaHabitacion lin JOIN res.Reserva r ON r.IdReserva = lin.IdReserva
                 WHERE lin.IdHabitacion = h.IdHabitacion AND lin.Estado = 'ACTIVA'
                   AND r.Estado IN ('PENDIENTE','CONFIRMADA','CHECKIN')
                   AND lin.FechaDesde <= CAST(SYSDATETIME() AS DATE) AND lin.FechaHasta > CAST(SYSDATETIME() AS DATE))
             THEN 1 ELSE 0 END AS Reservada) a
WHERE h.Activa = 1
GROUP BY e.Codigo;
GO
-- Amenidades de cada habitación: las de su tipo + los extras propios de la habitación
CREATE VIEW hab.vw_AmenidadesHabitacion
AS
SELECT h.IdHabitacion, h.Codigo AS Habitacion, a.IdAmenidad, a.Codigo, a.Nombre, a.Descripcion, CAST(0 AS BIT) AS EsExtra
FROM hab.Habitacion h
JOIN hab.TipoHabitacionAmenidad ta ON ta.IdTipoHabitacion = h.IdTipoHabitacion
JOIN hab.Amenidad a ON a.IdAmenidad = ta.IdAmenidad AND a.Activa = 1
UNION ALL
SELECT h.IdHabitacion, h.Codigo, a.IdAmenidad, a.Codigo, a.Nombre, a.Descripcion, CAST(1 AS BIT)
FROM hab.HabitacionAmenidad ha
JOIN hab.Habitacion h ON h.IdHabitacion = ha.IdHabitacion
JOIN hab.Amenidad a   ON a.IdAmenidad = ha.IdAmenidad AND a.Activa = 1
WHERE NOT EXISTS (SELECT 1 FROM hab.TipoHabitacionAmenidad ta
                  WHERE ta.IdTipoHabitacion = h.IdTipoHabitacion AND ta.IdAmenidad = ha.IdAmenidad);
GO

-- 12. DISPARADORES
---------- Seguridad ----------
CREATE TRIGGER seg.trg_Usuario_Seguridad ON seg.Usuario AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    IF EXISTS (SELECT 1 FROM deleted)
    BEGIN
        IF UPDATE(IdUsuario) THROW 50106, N'Un usuario no puede pasar a otra persona.', 1;
        -- Cambio de contraseña o desactivación: se invalidan JWT (SecurityStamp) y refresh tokens
        DECLARE @Af TABLE (IdUsuario INT PRIMARY KEY);
        INSERT @Af SELECT i.IdUsuario FROM inserted i JOIN deleted d ON d.IdUsuario = i.IdUsuario
        WHERE i.PasswordHash <> d.PasswordHash OR (d.Activo = 1 AND i.Activo = 0);
        UPDATE u SET SecurityStamp = NEWID() FROM seg.Usuario u JOIN @Af a ON a.IdUsuario = u.IdUsuario;
        UPDATE t SET FechaRevocacion = SYSDATETIME() FROM seg.RefreshToken t JOIN @Af a ON a.IdUsuario = t.IdUsuario
        WHERE t.FechaRevocacion IS NULL;
    END
    -- Bitácora: el hash JAMÁS se registra
    INSERT aud.Bitacora(Tabla, Operacion, IdRegistro, DatosAnteriores, DatosNuevos, IdUsuario)
    SELECT 'seg.Usuario', IIF(d.IdUsuario IS NULL, 'INSERT', 'UPDATE'), i.IdUsuario,
           CASE WHEN d.IdUsuario IS NOT NULL THEN (SELECT d.NombreUsuario, d.Activo FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
           (SELECT i.NombreUsuario, i.Activo, IIF(d.PasswordHash <> i.PasswordHash, 1, 0) AS PasswordCambiada
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           TRY_CAST(SESSION_CONTEXT(N'IdUsuario') AS INT)
    FROM inserted i LEFT JOIN deleted d ON d.IdUsuario = i.IdUsuario
    WHERE d.IdUsuario IS NULL OR i.PasswordHash <> d.PasswordHash OR i.Activo <> d.Activo OR i.NombreUsuario <> d.NombreUsuario;
END
GO
-- Roles sobre el usuario genérico: los de SISTEMA exigen un empleado activo; los de APP, un cliente activo
CREATE TRIGGER seg.trg_UsuarioRol_Validar ON seg.UsuarioRol AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted) AND (UPDATE(IdUsuario) OR UPDATE(IdRol))
        THROW 50107, N'Una asignación de rol no se modifica: se quita y se asigna otra.', 1;
    IF EXISTS (SELECT 1 FROM inserted i JOIN seg.Rol r ON r.IdRol = i.IdRol
               WHERE (r.Ambito = 'SISTEMA' AND NOT EXISTS (SELECT 1 FROM rh.Empleado e  WHERE e.IdEmpleado = i.IdUsuario AND e.Activo = 1))
                  OR (r.Ambito = 'APP'     AND NOT EXISTS (SELECT 1 FROM res.Cliente c  WHERE c.IdCliente  = i.IdUsuario AND c.Activo = 1)))
        THROW 50102, N'Los roles del sistema requieren un empleado activo y los roles de la app un cliente activo.', 1;
    INSERT aud.Bitacora(Tabla, Operacion, IdRegistro, DatosAnteriores, DatosNuevos, IdUsuario)
    SELECT 'seg.UsuarioRol', IIF(i.IdUsuarioRol IS NULL, 'DELETE', IIF(d.IdUsuarioRol IS NULL, 'INSERT', 'UPDATE')),
           COALESCE(i.IdUsuario, d.IdUsuario),
           CASE WHEN d.IdUsuarioRol IS NOT NULL THEN CONCAT('{"IdRol":', d.IdRol, '}') END,
           CASE WHEN i.IdUsuarioRol IS NOT NULL THEN CONCAT('{"IdRol":', i.IdRol, '}') END,
           TRY_CAST(SESSION_CONTEXT(N'IdUsuario') AS INT)
    FROM inserted i FULL OUTER JOIN deleted d ON d.IdUsuarioRol = i.IdUsuarioRol;
END
GO
-- ---------- Habitaciones ----------
CREATE TRIGGER hab.trg_Temporada_Validar ON hab.Temporada AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN hab.Temporada t ON t.IdTemporada <> i.IdTemporada
               WHERE i.Activa = 1 AND t.Activa = 1 AND t.FechaInicio <= i.FechaFin AND i.FechaInicio <= t.FechaFin)
        THROW 50140, N'La temporada se traslapa con otra temporada activa.', 1;
    -- Las reservas ya hechas no cambian: su precio por noche quedó congelado en res.ReservaHabitacionNoche
    INSERT aud.Bitacora(Tabla, Operacion, IdRegistro, DatosAnteriores, DatosNuevos, IdUsuario)
    SELECT 'hab.Temporada', IIF(d.IdTemporada IS NULL, 'INSERT', 'UPDATE'), i.IdTemporada,
           CASE WHEN d.IdTemporada IS NOT NULL THEN (SELECT d.Tipo, d.FechaInicio, d.FechaFin, d.PorcentajeAjuste, d.Activa
                                                      FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
           (SELECT i.Tipo, i.FechaInicio, i.FechaFin, i.PorcentajeAjuste, i.Activa FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           TRY_CAST(SESSION_CONTEXT(N'IdUsuario') AS INT)
    FROM inserted i LEFT JOIN deleted d ON d.IdTemporada = i.IdTemporada;
END
GO
CREATE TRIGGER hab.trg_Bloqueo_Validar ON hab.BloqueoHabitacion AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted b
               JOIN res.ReservaHabitacion lin ON lin.IdHabitacion = b.IdHabitacion
               JOIN res.Reserva r ON r.IdReserva = lin.IdReserva
               WHERE b.Activo = 1 AND lin.Estado = 'ACTIVA' AND r.Estado IN ('PENDIENTE','CONFIRMADA','CHECKIN')
                 AND lin.FechaDesde < b.FechaHasta AND b.FechaDesde < lin.FechaHasta)
        THROW 50012, N'No se puede bloquear: hay reservaciones activas en ese rango. Reubíquelas primero.', 1;
END
GO
CREATE TRIGGER hab.trg_Tarjeta_Validar ON hab.TarjetaHabitacion AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted) AND (UPDATE(TokenQRHash) OR UPDATE(IdHabitacion) OR UPDATE(CodigoTarjeta))
        THROW 50043, N'Los datos de una tarjeta emitida no se modifican: revóquela y emita otra.', 1;
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.IdTarjeta = i.IdTarjeta WHERE d.Estado <> 'ACTIVA' AND i.Estado = 'ACTIVA')
        THROW 50044, N'Una tarjeta revocada o expirada no puede reactivarse.', 1;
    IF EXISTS (SELECT 1 FROM inserted i
               JOIN res.ReservaHabitacion lin ON lin.IdReservaHabitacion = i.IdReservaHabitacion
               JOIN res.Reserva r ON r.IdReserva = lin.IdReserva
               WHERE i.Estado = 'ACTIVA' AND (lin.IdHabitacion <> i.IdHabitacion OR lin.Estado <> 'ACTIVA' OR r.Estado <> 'CHECKIN'))
        THROW 50045, N'Solo se emiten tarjetas para habitaciones con check-in activo.', 1;
    IF EXISTS (SELECT 1 FROM res.ReservaHabitacion lin
               WHERE lin.IdReservaHabitacion IN (SELECT IdReservaHabitacion FROM inserted)
                 AND (SELECT COUNT(*) FROM hab.TarjetaHabitacion t
                      WHERE t.IdReservaHabitacion = lin.IdReservaHabitacion AND t.Estado = 'ACTIVA') > lin.Adultos + lin.Ninos)
        THROW 50046, N'Ya existe una tarjeta activa por cada huésped de la habitación.', 1;
END
GO
-- ---------- Descuentos ----------
CREATE TRIGGER res.trg_Descuento_Control ON res.Descuento AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.IdDescuento = i.IdDescuento
               WHERE (i.Tipo <> d.Tipo OR i.Valor <> d.Valor OR i.AplicaA <> d.AplicaA OR i.Clase <> d.Clase
                      OR ISNULL(i.Codigo, '') <> ISNULL(d.Codigo, ''))
                 AND EXISTS (SELECT 1 FROM res.Reserva r WHERE r.IdDescuento = i.IdDescuento))
        THROW 50150, N'El descuento ya fue usado: sus condiciones no cambian. Desactívelo y cree otro.', 1;
END
GO
-- ---------- Reservas ----------
CREATE TRIGGER res.trg_Reserva_Validar ON res.Reserva AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    IF NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        IF EXISTS (SELECT 1 FROM inserted WHERE Estado <> 'PENDIENTE')
            THROW 50033, N'Toda reservación nueva inicia en estado PENDIENTE.', 1;
        IF EXISTS (SELECT 1 FROM inserted WHERE FechaEntrada < CAST(SYSDATETIME() AS DATE))
            THROW 50001, N'No se puede reservar en fechas pasadas.', 1;
    END
    ELSE
    BEGIN
        IF UPDATE(IdCliente) THROW 50034, N'No se puede cambiar el cliente de una reservación.', 1;
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.IdReserva = i.IdReserva
                   WHERE i.Estado <> d.Estado AND dbo.fn_TransicionValida('RESERVA', d.Estado, i.Estado) = 0)
            THROW 50035, N'Cambio de estado de reservación no permitido.', 1;
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.IdReserva = i.IdReserva
                   WHERE d.Estado IN ('CHECKOUT','CANCELADA','EXPIRADA','NO_SHOW')
                     AND (i.Total <> d.Total OR i.FechaEntrada <> d.FechaEntrada OR i.FechaSalida <> d.FechaSalida
                          OR ISNULL(i.IdDescuento, 0) <> ISNULL(d.IdDescuento, 0)))
            THROW 50036, N'La reservación está cerrada: sus montos, fechas y descuento ya no se modifican.', 1;
    END
    INSERT aud.Bitacora(Tabla, Operacion, IdRegistro, DatosAnteriores, DatosNuevos, IdUsuario)
    SELECT 'res.Reserva', IIF(d.IdReserva IS NULL, 'INSERT', 'UPDATE'), i.IdReserva,
           CASE WHEN d.IdReserva IS NOT NULL THEN (SELECT d.Estado, d.FechaEntrada, d.FechaSalida, d.IdDescuento, d.Total,
                                                          d.AnticipoRequerido, d.MontoPagado FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
           (SELECT i.Estado, i.FechaEntrada, i.FechaSalida, i.IdDescuento, i.Total, i.AnticipoRequerido, i.MontoPagado
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           TRY_CAST(SESSION_CONTEXT(N'IdUsuario') AS INT)
    FROM inserted i LEFT JOIN deleted d ON d.IdReserva = i.IdReserva;
END
GO
-- Corazón anti doble-reserva: capacidad, rango, fuera de servicio, traslape y bloqueos
CREATE TRIGGER res.trg_ReservaHabitacion_Validar ON res.ReservaHabitacion AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted) AND (UPDATE(IdReserva) OR UPDATE(IdHabitacion) OR UPDATE(PrecioNoche)
                                           OR UPDATE(PrecioPersonaExtra) OR UPDATE(CapacidadBase))
        THROW 50013, N'No se modifica la habitación ni el precio pactado de una línea: use el cambio de habitación.', 1;
    -- Solo se recalculó el monto: no hace falta revalidar disponibilidad
    IF EXISTS (SELECT 1 FROM deleted) AND NOT (UPDATE(FechaDesde) OR UPDATE(FechaHasta) OR UPDATE(Estado)
                                               OR UPDATE(Adultos) OR UPDATE(Ninos))
        RETURN;
    IF NOT EXISTS (SELECT 1 FROM inserted WHERE Estado = 'ACTIVA') RETURN;

    IF EXISTS (SELECT 1 FROM inserted i JOIN res.Reserva r ON r.IdReserva = i.IdReserva
               WHERE i.Estado = 'ACTIVA' AND (i.FechaDesde < r.FechaEntrada OR i.FechaHasta > r.FechaSalida
                                              OR r.Estado NOT IN ('PENDIENTE','CONFIRMADA','CHECKIN')))
        THROW 50014, N'Las fechas deben estar dentro de la reservación y ésta debe estar activa.', 1;

    IF EXISTS (SELECT 1 FROM inserted i
               JOIN hab.Habitacion h ON h.IdHabitacion = i.IdHabitacion
               JOIN hab.TipoHabitacion t ON t.IdTipoHabitacion = h.IdTipoHabitacion
               WHERE i.Estado = 'ACTIVA' AND i.Adultos + i.Ninos > t.CapacidadMaxima)
        THROW 50015, N'La cantidad de personas supera la capacidad máxima de la habitación.', 1;

    IF EXISTS (SELECT 1 FROM inserted i JOIN hab.Habitacion h ON h.IdHabitacion = i.IdHabitacion
               WHERE i.Estado = 'ACTIVA' AND (h.Activa = 0 OR h.Estado = 'FUERA_SERVICIO'))
        THROW 50016, N'La habitación está fuera de servicio.', 1;

    IF EXISTS (SELECT 1 FROM inserted i
               JOIN res.ReservaHabitacion o WITH (UPDLOCK, HOLDLOCK)
                    ON o.IdHabitacion = i.IdHabitacion AND o.IdReservaHabitacion <> i.IdReservaHabitacion
               JOIN res.Reserva r ON r.IdReserva = o.IdReserva
               WHERE i.Estado = 'ACTIVA' AND o.Estado = 'ACTIVA' AND r.Estado IN ('PENDIENTE','CONFIRMADA','CHECKIN')
                 AND o.FechaDesde < i.FechaHasta AND i.FechaDesde < o.FechaHasta)
        THROW 50017, N'La habitación ya está reservada en ese rango de fechas.', 1;

    IF EXISTS (SELECT 1 FROM inserted i JOIN hab.BloqueoHabitacion b ON b.IdHabitacion = i.IdHabitacion
               WHERE i.Estado = 'ACTIVA' AND b.Activo = 1 AND b.FechaDesde < i.FechaHasta AND i.FechaDesde < b.FechaHasta)
        THROW 50018, N'La habitación está bloqueada por mantenimiento en esas fechas.', 1;
END
GO
CREATE TRIGGER res.trg_Huesped_Capacidad ON res.Huesped AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM res.ReservaHabitacion lin
               WHERE lin.IdReservaHabitacion IN (SELECT IdReservaHabitacion FROM inserted)
                 AND (SELECT COUNT(*) FROM res.Huesped h WHERE h.IdReservaHabitacion = lin.IdReservaHabitacion) > lin.Adultos + lin.Ninos)
        THROW 50019, N'Hay más huéspedes registrados que personas en la reservación. Actualice la ocupación primero.', 1;
END
GO
CREATE TRIGGER res.trg_Pago_Procesar ON res.Pago AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    IF EXISTS (SELECT 1 FROM deleted) AND (UPDATE(Monto) OR UPDATE(IdReserva) OR UPDATE(TipoMovimiento) OR UPDATE(Metodo))
        THROW 50090, N'Un pago no se modifica: se anula y se registra uno nuevo.', 1;
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.IdPago = i.IdPago WHERE d.Anulado = 1 AND i.Anulado = 0)
        THROW 50091, N'Un pago anulado no puede reactivarse.', 1;
    IF NOT EXISTS (SELECT 1 FROM deleted) AND EXISTS (
               SELECT 1 FROM inserted i JOIN res.Reserva r ON r.IdReserva = i.IdReserva
               WHERE i.TipoMovimiento <> 'REEMBOLSO' AND r.Estado IN ('CANCELADA','EXPIRADA','NO_SHOW'))
        THROW 50092, N'No se reciben pagos en una reservación cancelada, expirada o no presentada.', 1;

    DECLARE @Res TABLE (IdReserva INT PRIMARY KEY);
    INSERT @Res SELECT DISTINCT IdReserva FROM inserted;

    IF EXISTS (SELECT 1 FROM @Res x
               CROSS APPLY (SELECT SUM(IIF(p.TipoMovimiento = 'REEMBOLSO', -p.Monto, p.Monto)) AS Neto
                            FROM res.Pago p WHERE p.IdReserva = x.IdReserva AND p.Anulado = 0) s
               WHERE s.Neto < 0)
        THROW 50093, N'El reembolso supera el monto pagado.', 1;

    UPDATE r SET MontoPagado = ISNULL(s.Neto, 0)
    FROM res.Reserva r JOIN @Res x ON x.IdReserva = r.IdReserva
    OUTER APPLY (SELECT SUM(IIF(p.TipoMovimiento = 'REEMBOLSO', -p.Monto, p.Monto)) AS Neto
                 FROM res.Pago p WHERE p.IdReserva = r.IdReserva AND p.Anulado = 0) s;

    -- Abono mínimo (PCT_ABONO_MINIMO del total), salvo que el pago cancele el saldo
    IF NOT EXISTS (SELECT 1 FROM deleted) AND EXISTS (
               SELECT 1 FROM inserted i JOIN res.Reserva r ON r.IdReserva = i.IdReserva
               WHERE i.TipoMovimiento = 'ABONO' AND r.MontoPagado < r.Total
                 AND i.Monto < ROUND(r.Total * dbo.fn_Param('PCT_ABONO_MINIMO') / 100, 2))
        THROW 50160, N'El abono es menor al mínimo permitido (parámetro PCT_ABONO_MINIMO) y no cancela el saldo.', 1;

    -- Lo pagado se aplica a las cuotas del plan de abonos en orden
    UPDATE a SET MontoPagado = d.Pagado,
                 Estado    = CASE WHEN d.Pagado >= a.MontoProgramado THEN 'PAGADO'
                                  WHEN a.FechaLimite < SYSDATETIME() THEN 'VENCIDO' ELSE 'PENDIENTE' END,
                 FechaPago = CASE WHEN d.Pagado >= a.MontoProgramado THEN ISNULL(a.FechaPago, SYSDATETIME()) END
    FROM @Res x
    JOIN res.Reserva r ON r.IdReserva = x.IdReserva AND r.Estado IN ('PENDIENTE','CONFIRMADA','CHECKIN','CHECKOUT')
    CROSS APPLY res.fn_DistribucionAbonos(x.IdReserva) d
    JOIN res.Abono a ON a.IdAbono = d.IdAbono;

    -- Anticipo cubierto -> CONFIRMADA (la habitación deja de expirar)
    DECLARE @Conf TABLE (IdReserva INT);
    UPDATE r SET Estado = 'CONFIRMADA', FechaExpiracion = NULL, FechaModificacion = SYSDATETIME()
    OUTPUT inserted.IdReserva INTO @Conf
    FROM res.Reserva r JOIN @Res x ON x.IdReserva = r.IdReserva
    WHERE r.Estado = 'PENDIENTE' AND r.MontoPagado >= r.AnticipoRequerido;

    INSERT dbo.ColaCorreo(Destinatario, Asunto, Cuerpo, Tipo, IdReferencia)
    SELECT pe.Correo, CONCAT(N'Reserva ', r.CodigoReserva, N' confirmada'),
           CONCAT(N'Recibimos su anticipo. Su reserva del ', CONVERT(CHAR(10), r.FechaEntrada, 103), N' al ',
                  CONVERT(CHAR(10), r.FechaSalida, 103), N' está confirmada. Saldo pendiente: ', FORMAT(r.SaldoTotal, 'N2'), N'.'),
           'RESERVA_CONFIRMADA', r.IdReserva
    FROM @Conf k JOIN res.Reserva r ON r.IdReserva = k.IdReserva JOIN dbo.Persona pe ON pe.IdPersona = r.IdCliente;

    -- Comprobante cubierto -> PAGADA (las notas de crédito no se pagan)
    UPDATE f SET Estado = 'PAGADA'
    FROM fac.Factura f JOIN res.Reserva r ON r.IdReserva = f.IdReserva JOIN @Res x ON x.IdReserva = r.IdReserva
    WHERE f.Estado = 'EMITIDA' AND f.TipoDocumento <> 'NC' AND r.MontoPagado >= f.Total;

    INSERT aud.Bitacora(Tabla, Operacion, IdRegistro, DatosAnteriores, DatosNuevos, IdUsuario)
    SELECT 'res.Pago', IIF(d.IdPago IS NULL, 'INSERT', 'UPDATE'), i.IdPago,
           CASE WHEN d.IdPago IS NOT NULL THEN (SELECT d.Anulado FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
           (SELECT i.IdReserva, i.TipoMovimiento, i.Metodo, i.Monto, i.Anulado FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           TRY_CAST(SESSION_CONTEXT(N'IdUsuario') AS INT)
    FROM inserted i LEFT JOIN deleted d ON d.IdPago = i.IdPago;
END
GO
-- ---------- Cocina ----------
CREATE TRIGGER coc.trg_Pedido_Validar ON coc.Pedido AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    DECLARE @IdUsuario INT = TRY_CAST(SESSION_CONTEXT(N'IdUsuario') AS INT);
    IF NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        IF EXISTS (SELECT 1 FROM inserted WHERE Estado <> 'PENDIENTE')
            THROW 50074, N'Todo pedido nuevo inicia en estado PENDIENTE.', 1;
        IF EXISTS (SELECT 1 FROM inserted i
                   JOIN res.ReservaHabitacion lin ON lin.IdReservaHabitacion = i.IdReservaHabitacion
                   JOIN res.Reserva r ON r.IdReserva = lin.IdReserva
                   WHERE lin.Estado <> 'ACTIVA' OR r.Estado <> 'CHECKIN' OR lin.IdHabitacion <> i.IdHabitacion)
            THROW 50072, N'Solo se puede pedir servicio a la habitación durante una estadía activa.', 1;
        INSERT coc.PedidoHistorial(IdPedido, EstadoAnterior, EstadoNuevo, IdUsuario)
        SELECT IdPedido, NULL, Estado, @IdUsuario FROM inserted;
        RETURN;
    END
    IF UPDATE(IdReservaHabitacion) OR UPDATE(IdHabitacion)
        THROW 50075, N'No se puede cambiar la habitación de un pedido.', 1;
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.IdPedido = i.IdPedido
               WHERE d.Estado IN ('EN_PREPARACION','EMPAQUETADO','EN_CAMINO','ENTREGADO') AND i.Estado = 'CANCELADO')
        THROW 50083, N'El pedido ya está en preparación: la cancelación está bloqueada.', 1;
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.IdPedido = i.IdPedido
               WHERE i.Estado <> d.Estado AND dbo.fn_TransicionValida('PEDIDO', d.Estado, i.Estado) = 0)
        THROW 50076, N'Cambio de estado no permitido: las etapas del pedido deben seguir su orden.', 1;

    INSERT coc.PedidoHistorial(IdPedido, EstadoAnterior, EstadoNuevo, IdUsuario)
    SELECT i.IdPedido, d.Estado, i.Estado, @IdUsuario
    FROM inserted i JOIN deleted d ON d.IdPedido = i.IdPedido WHERE i.Estado <> d.Estado;

    -- Pedido cancelado: devolver existencias
    UPDATE pm SET Stock = pm.Stock + x.Cant
    FROM coc.ProductoMenu pm
    JOIN (SELECT pd.IdProducto, SUM(pd.Cantidad) AS Cant
          FROM coc.PedidoDetalle pd
          JOIN inserted i ON i.IdPedido = pd.IdPedido
          JOIN deleted d  ON d.IdPedido = i.IdPedido
          WHERE i.Estado = 'CANCELADO' AND d.Estado <> 'CANCELADO'
          GROUP BY pd.IdProducto) x ON x.IdProducto = pm.IdProducto
    WHERE pm.Stock IS NOT NULL;
END
GO
CREATE TRIGGER coc.trg_PedidoDetalle_Validar ON coc.PedidoDetalle AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM coc.Pedido p WHERE p.Estado <> 'PENDIENTE'
               AND p.IdPedido IN (SELECT IdPedido FROM inserted UNION SELECT IdPedido FROM deleted))
        THROW 50077, N'Solo se modifica el detalle de un pedido PENDIENTE.', 1;
    IF EXISTS (SELECT 1 FROM inserted i JOIN coc.ProductoMenu pm ON pm.IdProducto = i.IdProducto WHERE pm.Disponible = 0)
        THROW 50073, N'Uno o más productos no están disponibles.', 1;

    -- Existencias en tiempo real: el CHECK Stock >= 0 impide vender lo que no hay
    UPDATE pm SET Stock = pm.Stock - n.Cant
    FROM coc.ProductoMenu pm
    JOIN (SELECT IdProducto, SUM(Cant) AS Cant
          FROM (SELECT IdProducto, CAST(Cantidad AS INT) AS Cant FROM inserted
                UNION ALL
                SELECT IdProducto, -CAST(Cantidad AS INT) FROM deleted) m
          GROUP BY IdProducto) n ON n.IdProducto = pm.IdProducto
    WHERE pm.Stock IS NOT NULL AND n.Cant <> 0;

    DECLARE @Serv DECIMAL(9,4) = dbo.fn_Param('PCT_SERVICIO'), @IVA DECIMAL(9,4) = dbo.fn_Param('PCT_IVA');
    UPDATE p SET Subtotal      = ISNULL(s.Sub, 0),
                 CargoServicio = ROUND(ISNULL(s.Sub, 0) * @Serv / 100, 2),
                 Impuesto      = ROUND(ISNULL(s.Sub, 0) * @IVA  / 100, 2)
    FROM coc.Pedido p
    OUTER APPLY (SELECT SUM(d.Subtotal) AS Sub FROM coc.PedidoDetalle d WHERE d.IdPedido = p.IdPedido) s
    WHERE p.IdPedido IN (SELECT IdPedido FROM inserted UNION SELECT IdPedido FROM deleted);
END
GO
-- ---------- Facturación electrónica ----------
CREATE TRIGGER fac.trg_Factura_Control ON fac.Factura AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM inserted) RETURN;
    IF NOT EXISTS (SELECT 1 FROM deleted)
    BEGIN
        IF EXISTS (SELECT 1 FROM inserted WHERE Estado <> 'EMITIDA' OR EstadoHacienda <> 'PENDIENTE')
            THROW 50063, N'Todo comprobante nuevo se emite en estado EMITIDA y PENDIENTE de envío a Hacienda.', 1;
        IF EXISTS (SELECT 1 FROM inserted i JOIN fac.Factura o ON o.IdFactura = i.IdFacturaReferencia
                   WHERE i.TipoDocumento = 'NC'
                     AND (o.TipoDocumento = 'NC' OR o.Estado = 'ANULADA' OR o.IdReserva <> i.IdReserva OR o.Total <> i.Total))
            THROW 50170, N'La nota de crédito debe anular por el total un comprobante vigente de la misma reservación.', 1;
    END
    ELSE
    BEGIN
        IF UPDATE(Subtotal) OR UPDATE(Descuento) OR UPDATE(Impuesto) OR UPDATE(Total) OR UPDATE(IdReserva)
           OR UPDATE(IdCliente) OR UPDATE(FechaEmision) OR UPDATE(TipoFactura) OR UPDATE(TipoDocumento)
           OR UPDATE(Consecutivo) OR UPDATE(Clave) OR UPDATE(CodigoActividad) OR UPDATE(IdFacturaReferencia)
           OR UPDATE(ReceptorNombre) OR UPDATE(ReceptorTipoId) OR UPDATE(ReceptorIdentificacion) OR UPDATE(ReceptorCorreo)
           OR UPDATE(CondicionVenta) OR UPDATE(Moneda) OR UPDATE(TipoCambio)
            THROW 50064, N'Un comprobante emitido es inmutable: solo se paga, se anula con nota de crédito o se registra su envío a Hacienda.', 1;
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.IdFactura = i.IdFactura
                   WHERE i.Estado <> d.Estado AND dbo.fn_TransicionValida('FACTURA', d.Estado, i.Estado) = 0)
            THROW 50065, N'Cambio de estado de factura no permitido.', 1;
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.IdFactura = i.IdFactura
                   WHERE i.EstadoHacienda <> d.EstadoHacienda AND dbo.fn_TransicionValida('HACIENDA', d.EstadoHacienda, i.EstadoHacienda) = 0)
            THROW 50173, N'Cambio de estado ante Hacienda no permitido.', 1;
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.IdFactura = i.IdFactura
                   WHERE d.EstadoHacienda <> 'PENDIENTE'
                     AND (ISNULL(i.XmlComprobante, 0x) <> ISNULL(d.XmlComprobante, 0x) OR ISNULL(i.MedioPago, '') <> ISNULL(d.MedioPago, '')))
            THROW 50174, N'El XML y el medio de pago de un comprobante ya enviado a Hacienda no se modifican.', 1;
        IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.IdFactura = i.IdFactura
                   WHERE i.Estado = 'ANULADA' AND d.Estado <> 'ANULADA'
                     AND NOT EXISTS (SELECT 1 FROM fac.Factura nc WHERE nc.IdFacturaReferencia = i.IdFactura AND nc.TipoDocumento = 'NC'))
            THROW 50171, N'Un comprobante solo se anula emitiendo su nota de crédito (fac.sp_AnularFactura).', 1;

        -- Anulación: liberar pedidos para refacturar y notificar al cliente por correo
        UPDATE p SET Facturado = 0
        FROM coc.Pedido p
        WHERE p.IdPedido IN (SELECT fd.IdPedido FROM fac.FacturaDetalle fd
                             JOIN inserted i ON i.IdFactura = fd.IdFactura
                             JOIN deleted d  ON d.IdFactura = i.IdFactura
                             WHERE i.Estado = 'ANULADA' AND d.Estado <> 'ANULADA');

        INSERT dbo.ColaCorreo(Destinatario, Asunto, Cuerpo, Tipo, IdReferencia)
        SELECT i.ReceptorCorreo, CONCAT(N'Anulación del comprobante ', i.Consecutivo),
               CONCAT(N'Le informamos que el comprobante ', i.Consecutivo, N' por ', FORMAT(i.Total, 'N2'),
                      N' fue anulado el ', FORMAT(i.FechaAnulacion, 'dd/MM/yyyy HH:mm'), N' mediante la nota de crédito ',
                      nc.Consecutivo, N'. Motivo: ', i.MotivoAnulacion),
               'FACTURA_ANULADA', i.IdFactura
        FROM inserted i JOIN deleted d ON d.IdFactura = i.IdFactura
        JOIN fac.Factura nc ON nc.IdFacturaReferencia = i.IdFactura AND nc.TipoDocumento = 'NC'
        WHERE i.Estado = 'ANULADA' AND d.Estado <> 'ANULADA';
    END
    INSERT aud.Bitacora(Tabla, Operacion, IdRegistro, DatosAnteriores, DatosNuevos, IdUsuario)
    SELECT 'fac.Factura', IIF(d.IdFactura IS NULL, 'INSERT', 'UPDATE'), i.IdFactura,
           CASE WHEN d.IdFactura IS NOT NULL THEN (SELECT d.Estado, d.EstadoHacienda FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
           (SELECT i.TipoDocumento, i.Consecutivo, i.Estado, i.EstadoHacienda, i.Total, i.MotivoAnulacion
            FOR JSON PATH, WITHOUT_ARRAY_WRAPPER),
           TRY_CAST(SESSION_CONTEXT(N'IdUsuario') AS INT)
    FROM inserted i LEFT JOIN deleted d ON d.IdFactura = i.IdFactura;
END
GO
CREATE TRIGGER fac.trg_FacturaDetalle_Insertar ON fac.FacturaDetalle AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM inserted i JOIN fac.Factura f ON f.IdFactura = i.IdFactura WHERE f.Estado <> 'EMITIDA')
        THROW 50066, N'No se agregan líneas a una factura pagada o anulada.', 1;
    -- El encabezado debe cuadrar con la suma de sus líneas
    IF EXISTS (SELECT 1 FROM fac.Factura f
               JOIN (SELECT IdFactura, SUM(MontoTotal) AS Sub, SUM(MontoDescuento) AS Des, SUM(MontoImpuesto) AS Imp
                     FROM fac.FacturaDetalle WHERE IdFactura IN (SELECT IdFactura FROM inserted)
                     GROUP BY IdFactura) x ON x.IdFactura = f.IdFactura
               WHERE f.Subtotal <> x.Sub OR f.Descuento <> x.Des OR f.Impuesto <> x.Imp)
        THROW 50067, N'Los totales del comprobante no coinciden con la suma de sus líneas.', 1;
END
GO
-- ---------- Planilla ----------
-- Baja del empleado: pierde los roles del sistema y sus sesiones. Si no le queda ningún rol (no es cliente), el usuario se desactiva
CREATE TRIGGER rh.trg_Empleado_Validar ON rh.Empleado AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM deleted) AND UPDATE(IdEmpleado)
        THROW 50120, N'Un empleado no puede pasar a otra persona.', 1;
    DECLARE @Baja TABLE (IdUsuario INT PRIMARY KEY);
    INSERT @Baja
    SELECT i.IdEmpleado FROM inserted i LEFT JOIN deleted d ON d.IdEmpleado = i.IdEmpleado
    WHERE i.Activo = 0 AND (d.IdEmpleado IS NULL OR d.Activo = 1)
      AND EXISTS (SELECT 1 FROM seg.Usuario u WHERE u.IdUsuario = i.IdEmpleado);
    IF NOT EXISTS (SELECT 1 FROM @Baja) RETURN;
    DELETE ur FROM seg.UsuarioRol ur
    JOIN seg.Rol r  ON r.IdRol = ur.IdRol
    JOIN @Baja b    ON b.IdUsuario = ur.IdUsuario
    WHERE r.Ambito = 'SISTEMA';
    UPDATE t SET FechaRevocacion = SYSDATETIME()
    FROM seg.RefreshToken t JOIN @Baja b ON b.IdUsuario = t.IdUsuario WHERE t.FechaRevocacion IS NULL;
    UPDATE u SET SecurityStamp = NEWID(),
                 Activo = CASE WHEN EXISTS (SELECT 1 FROM seg.UsuarioRol ur WHERE ur.IdUsuario = u.IdUsuario) THEN u.Activo ELSE 0 END
    FROM seg.Usuario u JOIN @Baja b ON b.IdUsuario = u.IdUsuario;
END
GO
CREATE TRIGGER rh.trg_Planilla_Control ON rh.Planilla AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF UPDATE(FechaInicio) OR UPDATE(FechaFin) OR UPDATE(TipoPeriodo) OR UPDATE(CreadaPor)
        THROW 50122, N'El periodo de una planilla no se modifica: anúlela y genere otra.', 1;
    IF EXISTS (SELECT 1 FROM inserted i JOIN deleted d ON d.IdPlanilla = i.IdPlanilla
               WHERE i.Estado <> d.Estado AND dbo.fn_TransicionValida('PLANILLA', d.Estado, i.Estado) = 0)
        THROW 50121, N'Cambio de estado de planilla no permitido.', 1;
END
GO
CREATE TRIGGER rh.trg_PlanillaDetalle_Control ON rh.PlanillaDetalle AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF EXISTS (SELECT 1 FROM rh.Planilla p WHERE p.Estado <> 'BORRADOR'
               AND p.IdPlanilla IN (SELECT IdPlanilla FROM inserted UNION SELECT IdPlanilla FROM deleted))
        THROW 50123, N'La planilla ya fue aprobada o pagada: su detalle no se modifica.', 1;
    IF EXISTS (SELECT 1 FROM deleted) AND (UPDATE(IdEmpleado) OR UPDATE(IdPlanilla))
        THROW 50124, N'No se cambia el empleado ni la planilla de una línea.', 1;
    INSERT aud.Bitacora(Tabla, Operacion, IdRegistro, DatosAnteriores, DatosNuevos, IdUsuario)
    SELECT 'rh.PlanillaDetalle',
           CASE WHEN i.IdPlanillaDetalle IS NULL THEN 'DELETE' WHEN d.IdPlanillaDetalle IS NULL THEN 'INSERT' ELSE 'UPDATE' END,
           COALESCE(i.IdPlanillaDetalle, d.IdPlanillaDetalle),
           CASE WHEN d.IdPlanillaDetalle IS NOT NULL THEN (SELECT d.IdEmpleado, d.SalarioBase, d.MontoHorasExtra, d.Bonificaciones,
                d.ImpuestoRenta, d.OtrasDeducciones, d.SalarioNeto FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
           CASE WHEN i.IdPlanillaDetalle IS NOT NULL THEN (SELECT i.IdEmpleado, i.SalarioBase, i.MontoHorasExtra, i.Bonificaciones,
                i.ImpuestoRenta, i.OtrasDeducciones, i.SalarioNeto FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END,
           TRY_CAST(SESSION_CONTEXT(N'IdUsuario') AS INT)
    FROM inserted i FULL OUTER JOIN deleted d ON d.IdPlanillaDetalle = i.IdPlanillaDetalle;
END
GO
-- ---------- Inmutabilidad: nada crítico se borra ----------
CREATE TRIGGER res.trg_Reserva_NoBorrar ON res.Reserva INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50900, N'Las reservaciones no se eliminan: se cancelan.', 1;
END
GO
CREATE TRIGGER res.trg_ReservaHab_NoBorrar ON res.ReservaHabitacion INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50901, N'Las líneas de reservación no se eliminan.', 1;
END
GO
CREATE TRIGGER res.trg_Noche_Inmutable ON res.ReservaHabitacionNoche INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50908, N'El precio pactado por noche es inmutable.', 1;
END
GO
CREATE TRIGGER res.trg_Pago_NoBorrar ON res.Pago INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50902, N'Los pagos no se eliminan: se anulan.', 1;
END
GO
CREATE TRIGGER res.trg_Cancelacion_Inmutable ON res.Cancelacion INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50903, N'El registro de una cancelación es inmutable.', 1;
END
GO
CREATE TRIGGER coc.trg_Pedido_NoBorrar ON coc.Pedido INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50904, N'Los pedidos no se eliminan: se cancelan.', 1;
END
GO
CREATE TRIGGER fac.trg_Factura_NoBorrar ON fac.Factura INSTEAD OF DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50905, N'Los comprobantes no se eliminan: se anulan con nota de crédito.', 1;
END
GO
CREATE TRIGGER fac.trg_FacturaDetalle_Inmutable ON fac.FacturaDetalle INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50906, N'El detalle de un comprobante es inmutable.', 1;
END
GO
CREATE TRIGGER aud.trg_Bitacora_Inmutable ON aud.Bitacora INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    THROW 50907, N'La bitácora no se modifica ni se elimina.', 1;
END
GO

-- 13. PROCEDIMIENTOS — PERSONA Y SEGURIDAD

/* Busca a la persona por su identificación o la crea. Si ya existe, el correo debe coincidir:
   evita que alguien que solo conoce una cédula ajena se "adueñe" de esa persona y de sus reservaciones. */
CREATE PROCEDURE dbo.sp_ObtenerOCrearPersona
    @TipoIdentificacion VARCHAR(15), @Identificacion VARCHAR(30), @Nombre VARCHAR(60), @Apellidos VARCHAR(100),
    @Correo VARCHAR(150), @Telefono VARCHAR(20) = NULL, @IdPersona INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    SET @IdPersona = NULL;
    SELECT @IdPersona = IdPersona FROM dbo.Persona WITH (UPDLOCK, HOLDLOCK)
    WHERE TipoIdentificacion = @TipoIdentificacion AND Identificacion = @Identificacion;
    IF @IdPersona IS NULL
    BEGIN
        INSERT dbo.Persona(TipoIdentificacion, Identificacion, Nombre, Apellidos, Correo, Telefono)
        VALUES (@TipoIdentificacion, @Identificacion, @Nombre, @Apellidos, @Correo, @Telefono);
        SET @IdPersona = SCOPE_IDENTITY();
    END
    ELSE IF NOT EXISTS (SELECT 1 FROM dbo.Persona WHERE IdPersona = @IdPersona AND Correo = @Correo)
        THROW 50180, N'La identificación ya está registrada con otro correo. Verifique los datos de la persona.', 1;
END
GO
CREATE PROCEDURE seg.sp_ExigirPermiso @IdUsuario INT, @Modulo VARCHAR(30), @Accion CHAR(1)
AS
BEGIN
    SET NOCOUNT ON;
    IF seg.fn_TienePermiso(@IdUsuario, @Modulo, @Accion) = 0
    BEGIN
        DECLARE @msg NVARCHAR(200) = CONCAT(N'Acceso denegado al módulo ', @Modulo, N'.');
        THROW 50100, @msg, 1;
    END
END
GO
/* Crea el usuario genérico de una persona (IdUsuario = IdPersona). El backend envía el HASH, nunca la contraseña.
   - Rol de ámbito APP (cliente): autorregistro desde la app, no pide permiso
   - Rol de ámbito SISTEMA: solo un usuario con SEGURIDAD; el primer ADMIN se crea sin permiso (arranque) */
CREATE PROCEDURE seg.sp_CrearUsuario
    @IdPersona INT, @NombreUsuario VARCHAR(50), @PasswordHash VARCHAR(255), @CodigoRol VARCHAR(30),
    @IdUsuarioAdmin INT = NULL, @IdUsuario INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Ambito VARCHAR(7) = (SELECT Ambito FROM seg.Rol WHERE Codigo = @CodigoRol AND Activo = 1);
    IF @Ambito IS NULL THROW 50105, N'El rol indicado no existe o está inactivo.', 1;
    IF @Ambito = 'SISTEMA'
    BEGIN
        IF EXISTS (SELECT 1 FROM seg.UsuarioRol ur JOIN seg.Rol r ON r.IdRol = ur.IdRol
                   JOIN seg.Usuario u ON u.IdUsuario = ur.IdUsuario WHERE r.Codigo = 'ADMIN' AND u.Activo = 1)
            EXEC seg.sp_ExigirPermiso @IdUsuarioAdmin, 'SEGURIDAD', 'C';
        ELSE IF @CodigoRol <> 'ADMIN'
            THROW 50104, N'Primero debe crearse el usuario administrador.', 1;
    END
    IF EXISTS (SELECT 1 FROM seg.Usuario WHERE IdUsuario = @IdPersona)
        THROW 50108, N'La persona ya tiene un usuario: asígnele el rol en lugar de crear otro usuario.', 1;
    DECLARE @tc INT = @@TRANCOUNT;
    BEGIN TRY
        IF @tc = 0 BEGIN TRAN;
        INSERT seg.Usuario(IdUsuario, NombreUsuario, PasswordHash) VALUES (@IdPersona, @NombreUsuario, @PasswordHash);
        SET @IdUsuario = @IdPersona;
        INSERT seg.UsuarioRol(IdUsuario, IdRol) SELECT @IdUsuario, IdRol FROM seg.Rol WHERE Codigo = @CodigoRol;
        IF @tc = 0 COMMIT;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO
CREATE PROCEDURE seg.sp_AsignarRol @IdUsuarioAdmin INT, @IdUsuario INT, @CodigoRol VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC seg.sp_ExigirPermiso @IdUsuarioAdmin, 'SEGURIDAD', 'E';
    IF @IdUsuarioAdmin = @IdUsuario THROW 50103, N'Un usuario no puede modificar sus propios roles.', 1;
    INSERT seg.UsuarioRol(IdUsuario, IdRol)
    SELECT @IdUsuario, r.IdRol FROM seg.Rol r
    WHERE r.Codigo = @CodigoRol AND r.Activo = 1
      AND NOT EXISTS (SELECT 1 FROM seg.UsuarioRol ur WHERE ur.IdUsuario = @IdUsuario AND ur.IdRol = r.IdRol);
    UPDATE seg.Usuario SET SecurityStamp = NEWID() WHERE IdUsuario = @IdUsuario;  -- obliga a renovar el token
END
GO
CREATE PROCEDURE seg.sp_QuitarRol @IdUsuarioAdmin INT, @IdUsuario INT, @CodigoRol VARCHAR(30)
AS
BEGIN
    SET NOCOUNT ON;
    EXEC seg.sp_ExigirPermiso @IdUsuarioAdmin, 'SEGURIDAD', 'E';
    IF @IdUsuarioAdmin = @IdUsuario THROW 50103, N'Un usuario no puede modificar sus propios roles.', 1;
    DELETE ur FROM seg.UsuarioRol ur JOIN seg.Rol r ON r.IdRol = ur.IdRol
    WHERE ur.IdUsuario = @IdUsuario AND r.Codigo = @CodigoRol;
    UPDATE seg.Usuario SET SecurityStamp = NEWID() WHERE IdUsuario = @IdUsuario;
END
GO
-- Mismo login para la app y la web: AccesoSistema / AccesoApp le dicen al backend qué puede abrir el usuario
CREATE PROCEDURE seg.sp_ObtenerUsuarioLogin @Login VARCHAR(150)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT u.IdUsuario, u.NombreUsuario, p.Correo, p.Nombre, p.Apellidos, u.PasswordHash, u.SecurityStamp, u.Activo,
           u.DebeCambiarPassword, CAST(IIF(u.BloqueadoHasta > SYSDATETIME(), 1, 0) AS BIT) AS Bloqueado, u.BloqueadoHasta,
           CAST(CASE WHEN EXISTS (SELECT 1 FROM seg.UsuarioRol ur JOIN seg.Rol r ON r.IdRol = ur.IdRol
                                  WHERE ur.IdUsuario = u.IdUsuario AND r.Activo = 1 AND r.Ambito = 'SISTEMA') THEN 1 ELSE 0 END AS BIT) AS AccesoSistema,
           CAST(CASE WHEN EXISTS (SELECT 1 FROM seg.UsuarioRol ur JOIN seg.Rol r ON r.IdRol = ur.IdRol
                                  WHERE ur.IdUsuario = u.IdUsuario AND r.Activo = 1 AND r.Ambito = 'APP') THEN 1 ELSE 0 END AS BIT) AS AccesoApp
    FROM seg.Usuario u JOIN dbo.Persona p ON p.IdPersona = u.IdUsuario
    WHERE u.NombreUsuario = @Login OR p.Correo = @Login;
END
GO
-- Un solo registro y un solo contador de intentos para la app y la web (@Origen solo informa de dónde vino)
CREATE PROCEDURE seg.sp_RegistrarIntentoLogin @Login VARCHAR(150), @Exitoso BIT, @Origen VARCHAR(3),
                                              @Ip VARCHAR(45) = NULL, @Dispositivo VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdUsuario INT,
            @Max INT = CAST(dbo.fn_Param('MAX_INTENTOS_LOGIN') AS INT),
            @Min INT = CAST(dbo.fn_Param('MIN_BLOQUEO_LOGIN') AS INT),
            @MaxIp INT = CAST(dbo.fn_Param('MAX_INTENTOS_IP') AS INT),
            @VentanaIp INT = CAST(dbo.fn_Param('MIN_VENTANA_INTENTOS_IP') AS INT);
    SELECT @IdUsuario = u.IdUsuario FROM seg.Usuario u JOIN dbo.Persona p ON p.IdPersona = u.IdUsuario
    WHERE u.NombreUsuario = @Login OR p.Correo = @Login;
    INSERT seg.IntentoLogin(LoginIngresado, IdUsuario, Origen, Exitoso, IpOrigen, Dispositivo)
    VALUES (@Login, @IdUsuario, @Origen, @Exitoso, @Ip, @Dispositivo);
    IF @IdUsuario IS NOT NULL
    BEGIN
        IF @Exitoso = 1
            UPDATE seg.Usuario SET IntentosFallidos = 0, BloqueadoHasta = NULL, UltimoAcceso = SYSDATETIME()
            WHERE IdUsuario = @IdUsuario AND (BloqueadoHasta IS NULL OR BloqueadoHasta <= SYSDATETIME());
        ELSE
            UPDATE seg.Usuario
            SET IntentosFallidos = IIF(IntentosFallidos + 1 >= @Max, 0, IntentosFallidos + 1),
                BloqueadoHasta   = IIF(IntentosFallidos + 1 >= @Max, DATEADD(MINUTE, @Min, SYSDATETIME()), BloqueadoHasta)
            WHERE IdUsuario = @IdUsuario;
    END
    -- IpBloqueada = 1: el backend debe rechazar esa IP temporalmente (fuerza bruta: MAX_INTENTOS_IP en MIN_VENTANA_INTENTOS_IP)
    SELECT u.IntentosFallidos, u.BloqueadoHasta,
           CAST(IIF((SELECT COUNT(*) FROM seg.IntentoLogin WHERE IpOrigen = @Ip AND Exitoso = 0
                     AND Fecha > DATEADD(MINUTE, -@VentanaIp, SYSDATETIME())) >= @MaxIp, 1, 0) AS BIT) AS IpBloqueada
    FROM (SELECT 1 AS x) d LEFT JOIN seg.Usuario u ON u.IdUsuario = @IdUsuario;
END
GO
CREATE PROCEDURE seg.sp_ObtenerPermisos @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT m.Codigo AS Modulo, m.Nombre,
           CAST(MAX(CAST(rm.PuedeVer    AS INT)) AS BIT) AS PuedeVer,
           CAST(MAX(CAST(rm.PuedeCrear  AS INT)) AS BIT) AS PuedeCrear,
           CAST(MAX(CAST(rm.PuedeEditar AS INT)) AS BIT) AS PuedeEditar,
           CAST(MAX(CAST(rm.PuedeAnular AS INT)) AS BIT) AS PuedeAnular
    FROM seg.Usuario u
    JOIN seg.UsuarioRol ur ON ur.IdUsuario = u.IdUsuario
    JOIN seg.Rol r         ON r.IdRol = ur.IdRol AND r.Activo = 1
    JOIN seg.RolModulo rm  ON rm.IdRol = r.IdRol
    JOIN seg.Modulo m      ON m.IdModulo = rm.IdModulo AND m.Activo = 1
    WHERE u.IdUsuario = @IdUsuario AND u.Activo = 1
    GROUP BY m.Codigo, m.Nombre;
END
GO
-- La vigencia la define DIAS_VIGENCIA_REFRESH_TOKEN; el backend usa la FechaExpiracion devuelta (por ejemplo, para la cookie)
CREATE PROCEDURE seg.sp_GuardarRefreshToken @IdUsuario INT, @TokenHash BINARY(32),
                                            @Ip VARCHAR(45) = NULL, @Dispositivo VARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Expira DATETIME2(0) = DATEADD(DAY, CAST(dbo.fn_Param('DIAS_VIGENCIA_REFRESH_TOKEN') AS INT), SYSDATETIME());
    INSERT seg.RefreshToken(IdUsuario, TokenHash, FechaExpiracion, IpOrigen, Dispositivo)
    VALUES (@IdUsuario, @TokenHash, @Expira, @Ip, @Dispositivo);
    SELECT @Expira AS FechaExpiracion;
END
GO
-- Rotación: cada refresh token sirve UNA vez. Si alguien reutiliza uno viejo (robado), se cierran todas las sesiones
CREATE PROCEDURE seg.sp_RotarRefreshToken @TokenHashActual BINARY(32), @TokenHashNuevo BINARY(32), @Ip VARCHAR(45) = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Id BIGINT, @IdUsuario INT, @Revocado DATETIME2(0), @Exp DATETIME2(0), @Disp VARCHAR(100),
            @Expira DATETIME2(0) = DATEADD(DAY, CAST(dbo.fn_Param('DIAS_VIGENCIA_REFRESH_TOKEN') AS INT), SYSDATETIME());
    BEGIN TRAN;
    SELECT @Id = IdRefreshToken, @IdUsuario = IdUsuario, @Revocado = FechaRevocacion, @Exp = FechaExpiracion, @Disp = Dispositivo
    FROM seg.RefreshToken WITH (UPDLOCK, HOLDLOCK) WHERE TokenHash = @TokenHashActual;
    IF @Id IS NULL BEGIN ROLLBACK; THROW 50110, N'Token inválido.', 1; END
    IF @Revocado IS NOT NULL
    BEGIN
        UPDATE seg.RefreshToken SET FechaRevocacion = SYSDATETIME() WHERE IdUsuario = @IdUsuario AND FechaRevocacion IS NULL;
        UPDATE seg.Usuario SET SecurityStamp = NEWID() WHERE IdUsuario = @IdUsuario;
        COMMIT;
        THROW 50111, N'Token reutilizado: por seguridad se cerraron todas las sesiones del usuario.', 1;
    END
    IF @Exp <= SYSDATETIME() OR NOT EXISTS (SELECT 1 FROM seg.Usuario WHERE IdUsuario = @IdUsuario AND Activo = 1)
    BEGIN ROLLBACK; THROW 50112, N'Sesión expirada.', 1; END
    UPDATE seg.RefreshToken SET FechaRevocacion = SYSDATETIME(), ReemplazadoPor = @TokenHashNuevo WHERE IdRefreshToken = @Id;
    INSERT seg.RefreshToken(IdUsuario, TokenHash, FechaExpiracion, IpOrigen, Dispositivo)
    VALUES (@IdUsuario, @TokenHashNuevo, @Expira, @Ip, @Disp);
    COMMIT;
    SELECT IdUsuario, SecurityStamp, @Expira AS FechaExpiracion FROM seg.Usuario WHERE IdUsuario = @IdUsuario;
END
GO
CREATE PROCEDURE seg.sp_CerrarSesion @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE seg.RefreshToken SET FechaRevocacion = SYSDATETIME() WHERE IdUsuario = @IdUsuario AND FechaRevocacion IS NULL;
END
GO

-- 14. PROCEDIMIENTOS — RESERVAS

/* Registro de cliente:
   - Con @NombreUsuario y @PasswordHash: autorregistro en la app (crea Persona + Cliente + Usuario con rol CLIENTE)
   - Sin ellos: cliente registrado en recepción (solo Persona + Cliente)
   - Si la persona ya existía (por ejemplo, es empleado), se reutiliza: no se duplican sus datos */
CREATE PROCEDURE res.sp_RegistrarCliente
    @TipoIdentificacion VARCHAR(15), @Identificacion VARCHAR(30), @Nombre VARCHAR(60), @Apellidos VARCHAR(100),
    @Correo VARCHAR(150), @Telefono VARCHAR(20) = NULL,
    @NombreUsuario VARCHAR(50) = NULL, @PasswordHash VARCHAR(255) = NULL, @IdCliente INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @IdUsuario INT;
    IF (@NombreUsuario IS NULL AND @PasswordHash IS NOT NULL) OR (@NombreUsuario IS NOT NULL AND @PasswordHash IS NULL)
        THROW 50181, N'Para crear la cuenta de la app se necesitan el nombre de usuario y la contraseña.', 1;
    BEGIN TRY
        BEGIN TRAN;
        EXEC dbo.sp_ObtenerOCrearPersona @TipoIdentificacion, @Identificacion, @Nombre, @Apellidos, @Correo, @Telefono,
             @IdPersona = @IdCliente OUTPUT;
        IF NOT EXISTS (SELECT 1 FROM res.Cliente WHERE IdCliente = @IdCliente)
            INSERT res.Cliente(IdCliente) VALUES (@IdCliente);
        IF @NombreUsuario IS NOT NULL
            EXEC seg.sp_CrearUsuario @IdPersona = @IdCliente, @NombreUsuario = @NombreUsuario, @PasswordHash = @PasswordHash,
                 @CodigoRol = 'CLIENTE', @IdUsuario = @IdUsuario OUTPUT;
        COMMIT;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH
END
GO
-- Candado global de disponibilidad: serializa reservas/cambios simultáneos (nadie gana la misma habitación)
CREATE PROCEDURE res.sp_BloquearDisponibilidad
AS
BEGIN
    DECLARE @r INT, @Espera INT = CAST(dbo.fn_Param('SEG_ESPERA_DISPONIBILIDAD') * 1000 AS INT);
    EXEC @r = sp_getapplock @Resource = N'HotelDB.Disponibilidad', @LockMode = N'Exclusive',
                            @LockOwner = N'Transaction', @LockTimeout = @Espera;
    IF @r < 0 THROW 50006, N'El sistema está procesando otra reservación. Intente nuevamente.', 1;
END
GO
-- Reglas de fechas de una estadía nueva (las usan la búsqueda y la creación de reservaciones)
CREATE PROCEDURE res.sp_ValidarFechasReserva @FechaEntrada DATE, @FechaSalida DATE
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Hoy DATE = CAST(SYSDATETIME() AS DATE), @m NVARCHAR(200),
            @MinNoches INT = CAST(dbo.fn_Param('MIN_NOCHES_RESERVA') AS INT),
            @MaxDias   INT = CAST(dbo.fn_Param('DIAS_MAX_ANTICIPACION_RESERVA') AS INT);
    IF @FechaEntrada IS NULL OR @FechaSalida IS NULL OR @FechaSalida <= @FechaEntrada OR @FechaEntrada < @Hoy
        THROW 50001, N'Rango de fechas inválido.', 1;
    IF DATEDIFF(DAY, @FechaEntrada, @FechaSalida) < @MinNoches
    BEGIN
        SET @m = CONCAT(N'La estadía mínima es de ', @MinNoches, N' noche(s).');
        THROW 50007, @m, 1;
    END
    IF DATEDIFF(DAY, @Hoy, @FechaEntrada) > @MaxDias
    BEGIN
        SET @m = CONCAT(N'Solo se puede reservar con un máximo de ', @MaxDias, N' días de anticipación.');
        THROW 50008, @m, 1;
    END
END
GO
/* Congela el precio de cada noche de una línea (tarifa base pactada × temporada).
   Si la línea viene de otra (cambio de habitación u ocupación), hereda el % de temporada que ya se había pactado. */
CREATE PROCEDURE res.sp_GenerarNoches @IdReservaHabitacion INT
AS
BEGIN
    SET NOCOUNT ON;
    INSERT res.ReservaHabitacionNoche(IdReservaHabitacion, Fecha, IdTemporada, PorcentajeAjuste, PrecioNoche, PrecioPersonaExtra)
    SELECT lin.IdReservaHabitacion, f.Fecha, aj.IdTemporada, aj.Pct,
           ROUND(lin.PrecioNoche        * (100 + aj.Pct) / 100, 2),
           ROUND(lin.PrecioPersonaExtra * (100 + aj.Pct) / 100, 2)
    FROM res.ReservaHabitacion lin
    CROSS APPLY dbo.fn_Fechas(lin.FechaDesde, lin.FechaHasta) f
    OUTER APPLY (SELECT n.IdTemporada, n.PorcentajeAjuste FROM res.ReservaHabitacionNoche n
                 WHERE n.IdReservaHabitacion = lin.IdReservaHabitacionOrigen AND n.Fecha = f.Fecha) o
    OUTER APPLY hab.fn_AjusteTemporada(f.Fecha) t
    CROSS APPLY (SELECT IIF(o.PorcentajeAjuste IS NOT NULL, o.IdTemporada, t.IdTemporada) AS IdTemporada,
                        COALESCE(o.PorcentajeAjuste, t.PorcentajeAjuste, 0)          AS Pct) aj
    WHERE lin.IdReservaHabitacion = @IdReservaHabitacion
      AND NOT EXISTS (SELECT 1 FROM res.ReservaHabitacionNoche x
                      WHERE x.IdReservaHabitacion = lin.IdReservaHabitacion AND x.Fecha = f.Fecha);
END
GO
/* Arma el plan de abonos con los parámetros y reparte lo ya pagado (FIFO):
   1) ANTICIPO = AnticipoRequerido, vence con la reservación pendiente
   2) el resto en cuotas de al menos PCT_ABONO_MINIMO % del total, hasta CANTIDAD_MAX_ABONOS cuotas en total,
      repartidas entre hoy y DIAS_LIMITE_SALDO días antes del check-in, separadas al menos DIAS_MIN_ENTRE_ABONOS días
   3) si ya no hay tiempo (o la estadía está en curso), el saldo vence al check-out */
CREATE PROCEDURE res.sp_GenerarPlanAbonos @IdReserva INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Estado VARCHAR(12), @Total DECIMAL(12,2), @Anticipo DECIMAL(12,2), @Entrada DATE, @Salida DATE,
            @LimiteAnticipo DATETIME2(0), @Ahora DATETIME2(0) = SYSDATETIME(),
            @MaxAbonos INT      = CAST(dbo.fn_Param('CANTIDAD_MAX_ABONOS') AS INT),
            @PctMin DECIMAL(9,4) = dbo.fn_Param('PCT_ABONO_MINIMO'),
            @Dias INT           = CAST(dbo.fn_Param('DIAS_LIMITE_SALDO') AS INT),
            @HoraIn INT         = CAST(dbo.fn_Param('HORA_CHECKIN') AS INT),
            @HoraOut INT        = CAST(dbo.fn_Param('HORA_CHECKOUT') AS INT),
            @DiasMin INT        = CAST(dbo.fn_Param('DIAS_MIN_ENTRE_ABONOS') AS INT);
    SELECT @Estado = Estado, @Total = Total, @Anticipo = AnticipoRequerido, @Entrada = FechaEntrada, @Salida = FechaSalida,
           @LimiteAnticipo = COALESCE(FechaExpiracion, FechaCreacion)
    FROM res.Reserva WHERE IdReserva = @IdReserva;
    IF @Estado IS NULL OR @Estado NOT IN ('PENDIENTE','CONFIRMADA','CHECKIN') RETURN;

    DELETE res.Abono WHERE IdReserva = @IdReserva;      -- el plan se rehace; lo pagado se vuelve a repartir al final
    IF @Total <= 0 RETURN;

    DECLARE @Num INT = 0, @Resto DECIMAL(12,2) = @Total - @Anticipo,
            @LimiteSaldo DATETIME2(0) = DATEADD(HOUR, @HoraIn, CAST(DATEADD(DAY, -@Dias, @Entrada) AS DATETIME2(0))),
            @AlSalir     DATETIME2(0) = DATEADD(HOUR, @HoraOut, CAST(@Salida AS DATETIME2(0)));
    IF @Anticipo > 0
    BEGIN
        SET @Num = 1;
        INSERT res.Abono(IdReserva, Numero, Concepto, MontoProgramado, FechaLimite)
        VALUES (@IdReserva, 1, 'ANTICIPO', @Anticipo, @LimiteAnticipo);
    END
    IF @Resto > 0
    BEGIN
        DECLARE @N INT = 1, @i INT = 1, @Cuota DECIMAL(12,2), @Minutos INT = 0,
                @HayTiempo BIT = IIF(@Estado <> 'CHECKIN' AND @LimiteSaldo > @Ahora, 1, 0);
        IF @HayTiempo = 1
        BEGIN
            SET @N = @MaxAbonos - @Num;
            IF @PctMin > 0 AND @N > FLOOR(@Resto * 100 / @Total / @PctMin) SET @N = FLOOR(@Resto * 100 / @Total / @PctMin);
            IF @DiasMin > 0 AND @N > DATEDIFF(DAY, @Ahora, @LimiteSaldo) / @DiasMin
                SET @N = DATEDIFF(DAY, @Ahora, @LimiteSaldo) / @DiasMin;                       -- separación mínima entre cuotas
            IF @N < 1 SET @N = 1;
            SET @Minutos = DATEDIFF(MINUTE, @Ahora, @LimiteSaldo);
        END
        SET @Cuota = ROUND(@Resto / @N, 2);
        WHILE @i <= @N
        BEGIN
            INSERT res.Abono(IdReserva, Numero, Concepto, MontoProgramado, FechaLimite)
            VALUES (@IdReserva, @Num + @i, IIF(@i = @N, 'SALDO', 'ABONO'),
                    IIF(@i = @N, @Resto - @Cuota * (@N - 1), @Cuota),
                    IIF(@HayTiempo = 1, DATEADD(MINUTE, CAST(CAST(@Minutos AS BIGINT) * @i / @N AS INT), @Ahora), @AlSalir));
            SET @i += 1;
        END
    END
    UPDATE a SET MontoPagado = d.Pagado,
                 Estado    = CASE WHEN d.Pagado >= a.MontoProgramado THEN 'PAGADO'
                                  WHEN a.FechaLimite < @Ahora THEN 'VENCIDO' ELSE 'PENDIENTE' END,
                 FechaPago = CASE WHEN d.Pagado >= a.MontoProgramado THEN @Ahora END
    FROM res.Abono a JOIN res.fn_DistribucionAbonos(@IdReserva) d ON d.IdAbono = a.IdAbono;
END
GO
-- Recalcula montos de líneas (noche por noche), descuento, impuesto, total, anticipo y plan de abonos
CREATE PROCEDURE res.sp_RecalcularReserva @IdReserva INT
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @Sub DECIMAL(12,2), @PctAnt DECIMAL(5,2), @IdDesc INT, @Desc DECIMAL(12,2),
            @Imp DECIMAL(12,2), @Tot DECIMAL(12,2), @IVA DECIMAL(9,4) = dbo.fn_Param('PCT_IVA');
    UPDATE lin SET MontoTotal = s.Monto
    FROM res.ReservaHabitacion lin
    CROSS APPLY (SELECT CAST(ISNULL(SUM(n.PrecioNoche), 0) + ISNULL(SUM(n.PrecioPersonaExtra), 0) * lin.PersonasExtra AS DECIMAL(12,2)) AS Monto
                 FROM res.ReservaHabitacionNoche n
                 WHERE n.IdReservaHabitacion = lin.IdReservaHabitacion AND n.Fecha >= lin.FechaDesde AND n.Fecha < lin.FechaHasta) s
    WHERE lin.IdReserva = @IdReserva AND lin.MontoTotal <> s.Monto;

    SELECT @PctAnt = PorcentajeAnticipo, @IdDesc = IdDescuento FROM res.Reserva WHERE IdReserva = @IdReserva;
    SELECT @Sub = ISNULL(SUM(MontoTotal), 0) FROM res.ReservaHabitacion WHERE IdReserva = @IdReserva AND Estado <> 'CANCELADA';
    SET @Desc = res.fn_MontoDescuento(@IdDesc, @Sub);
    SET @Imp  = ROUND((@Sub - @Desc) * @IVA / 100, 2);
    SET @Tot  = @Sub - @Desc + @Imp;
    UPDATE res.Reserva
    SET Subtotal = @Sub, MontoDescuento = @Desc, MontoImpuesto = @Imp, Total = @Tot,
        AnticipoRequerido = ROUND(@Tot * @PctAnt / 100, 2), FechaModificacion = SYSDATETIME()
    WHERE IdReserva = @IdReserva;
    EXEC res.sp_GenerarPlanAbonos @IdReserva;
END
GO
-- Ejecutar cada minuto (Agente SQL o servicio del backend): expira pendientes, marca no-show y abonos vencidos
CREATE PROCEDURE res.sp_MantenimientoReservas @Silencioso BIT = 0
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Af TABLE (IdReserva INT PRIMARY KEY, NuevoEstado VARCHAR(12));
    DECLARE @Venc TABLE (IdAbono INT PRIMARY KEY);
    DECLARE @tc INT = @@TRANCOUNT, @Id INT, @Monto DECIMAL(12,2), @IdFac INT,
            @PctNoShow DECIMAL(5,2) = dbo.fn_Param('PCT_PENALIZACION_NO_SHOW'), @DescNoShow VARCHAR(200);
    SET @DescNoShow = CONCAT('Penalización por no presentarse (', @PctNoShow, '% de lo pagado)');
    IF @tc = 0 BEGIN TRAN;
    UPDATE res.Reserva SET Estado = 'EXPIRADA', FechaModificacion = SYSDATETIME()
    OUTPUT inserted.IdReserva, inserted.Estado INTO @Af
    WHERE Estado = 'PENDIENTE' AND FechaExpiracion < SYSDATETIME();
    -- No-show: se retiene PCT_PENALIZACION_NO_SHOW % de lo pagado (si es menos de 100, el resto queda a favor del cliente para reembolso)
    UPDATE res.Reserva SET Estado = 'NO_SHOW', FechaModificacion = SYSDATETIME()
    OUTPUT inserted.IdReserva, inserted.Estado INTO @Af
    WHERE Estado = 'CONFIRMADA' AND FechaEntrada < CAST(SYSDATETIME() AS DATE);
    UPDATE lin SET Estado = 'CANCELADA'
    FROM res.ReservaHabitacion lin JOIN @Af a ON a.IdReserva = lin.IdReserva
    WHERE lin.Estado = 'ACTIVA';
    UPDATE ab SET Estado = 'ANULADO'
    FROM res.Abono ab JOIN @Af a ON a.IdReserva = ab.IdReserva
    WHERE ab.Estado IN ('PENDIENTE','VENCIDO');

    -- Lo retenido en un no-show se factura como penalización (antes quedaba cobrado pero sin comprobante)
    DECLARE cur CURSOR LOCAL FAST_FORWARD FOR
        SELECT r.IdReserva, x.Retenido FROM @Af a JOIN res.Reserva r ON r.IdReserva = a.IdReserva
        CROSS APPLY (SELECT CAST(ROUND(r.MontoPagado * @PctNoShow / 100, 2) AS DECIMAL(12,2)) AS Retenido) x
        WHERE a.NuevoEstado = 'NO_SHOW' AND x.Retenido > 0;
    OPEN cur;
    FETCH NEXT FROM cur INTO @Id, @Monto;
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC fac.sp_FacturarPenalizacion @Id, @Monto, @DescNoShow, NULL, @IdFac OUTPUT;
        FETCH NEXT FROM cur INTO @Id, @Monto;
    END
    CLOSE cur; DEALLOCATE cur;

    INSERT dbo.ColaCorreo(Destinatario, Asunto, Cuerpo, Tipo, IdReferencia)
    SELECT pe.Correo, CONCAT(N'Reserva ', r.CodigoReserva, N' expirada'),
           N'Su reservación expiró porque no se recibió el anticipo a tiempo. Las habitaciones fueron liberadas.',
           'RESERVA_EXPIRADA', r.IdReserva
    FROM @Af a JOIN res.Reserva r ON r.IdReserva = a.IdReserva JOIN dbo.Persona pe ON pe.IdPersona = r.IdCliente
    WHERE a.NuevoEstado = 'EXPIRADA';

    -- Cuotas del plan de abonos que vencieron sin pagarse
    UPDATE ab SET Estado = 'VENCIDO'
    OUTPUT inserted.IdAbono INTO @Venc
    FROM res.Abono ab JOIN res.Reserva r ON r.IdReserva = ab.IdReserva
    WHERE ab.Estado = 'PENDIENTE' AND ab.FechaLimite < SYSDATETIME() AND r.Estado IN ('CONFIRMADA','CHECKIN');
    INSERT dbo.ColaCorreo(Destinatario, Asunto, Cuerpo, Tipo, IdReferencia)
    SELECT pe.Correo, CONCAT(N'Abono vencido de la reserva ', r.CodigoReserva),
           CONCAT(N'El abono #', ab.Numero, N' por ', FORMAT(ab.SaldoPendiente, 'N2'), N' venció el ',
                  FORMAT(ab.FechaLimite, 'dd/MM/yyyy HH:mm'), N'. Saldo total pendiente: ', FORMAT(r.SaldoTotal, 'N2'), N'.'),
           'ABONO_VENCIDO', ab.IdAbono
    FROM @Venc v JOIN res.Abono ab ON ab.IdAbono = v.IdAbono
    JOIN res.Reserva r ON r.IdReserva = ab.IdReserva JOIN dbo.Persona pe ON pe.IdPersona = r.IdCliente;
    IF @tc = 0 COMMIT;
    IF @Silencioso = 0 SELECT NuevoEstado, COUNT(*) AS Cantidad FROM @Af GROUP BY NuevoEstado;
END
GO
-- Disponibilidad con precio por temporada, características y amenidades de cada habitación
CREATE PROCEDURE res.sp_BuscarDisponibilidad @FechaEntrada DATE, @FechaSalida DATE, @Personas TINYINT, @IdTipoHabitacion INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC res.sp_ValidarFechasReserva @FechaEntrada, @FechaSalida;
    EXEC res.sp_MantenimientoReservas @Silencioso = 1;
    SELECT h.IdHabitacion, h.Codigo, e.Nombre AS Edificio, p.Numero AS Piso, t.IdTipoHabitacion, t.Nombre AS Tipo, t.Descripcion,
           t.CapacidadBase, t.CapacidadMaxima, t.CantidadCamas, t.TipoCama, t.MetrosCuadrados,
           t.PrecioNoche AS PrecioBaseNoche, t.PrecioPersonaExtra AS PrecioBasePersonaExtra,
           hab.fn_CotizarHospedaje(t.IdTipoHabitacion, @FechaEntrada, @FechaSalida, @Personas) AS SubtotalEstimado,
           (SELECT v.Codigo, v.Nombre, v.EsExtra FROM hab.vw_AmenidadesHabitacion v
            WHERE v.IdHabitacion = h.IdHabitacion FOR JSON PATH) AS Amenidades
    FROM hab.Habitacion h
    JOIN hab.Piso p           ON p.IdPiso = h.IdPiso
    JOIN hab.Edificio e       ON e.IdEdificio = p.IdEdificio
    JOIN hab.TipoHabitacion t ON t.IdTipoHabitacion = h.IdTipoHabitacion
    WHERE h.Activa = 1 AND t.Activo = 1 AND t.CapacidadMaxima >= @Personas
      AND (@IdTipoHabitacion IS NULL OR t.IdTipoHabitacion = @IdTipoHabitacion)
      AND res.fn_HabitacionDisponible(h.IdHabitacion, @FechaEntrada, @FechaSalida, NULL) = 1
    ORDER BY t.CapacidadMaxima, t.PrecioNoche, h.Codigo;
END
GO
/* @Habitaciones (JSON): [{"IdHabitacion":null,"IdTipoHabitacion":2,"Adultos":2,"Ninos":1}, ...]
   - IdHabitacion = habitación específica elegida en la app/web
   - Si es null se asigna automáticamente la más adecuada del tipo pedido (o cualquiera con capacidad)
   @CodigoDescuento: código promocional opcional. Los descuentos no son acumulables: si el cliente es frecuente
   se aplica el que más le rebaje del hospedaje. */
CREATE PROCEDURE res.sp_CrearReserva
    @IdCliente INT, @FechaEntrada DATE, @FechaSalida DATE, @Canal VARCHAR(10), @Habitaciones VARCHAR(MAX),
    @CodigoDescuento VARCHAR(30) = NULL, @Observaciones VARCHAR(500) = NULL, @IdUsuario INT = NULL, @IdReserva INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Items TABLE (Fila INT IDENTITY(1,1) PRIMARY KEY, IdHabitacion INT NULL, IdTipoHabitacion INT NULL, Adultos INT NULL, Ninos INT NULL);
    DECLARE @IdDescCodigo INT, @IdDescFrec INT, @IdDesc INT, @Sub DECIMAL(12,2), @IdLinea INT;
    IF ISNULL(ISJSON(@Habitaciones), 0) = 0 THROW 50002, N'El detalle de habitaciones no es un JSON válido.', 1;
    INSERT @Items(IdHabitacion, IdTipoHabitacion, Adultos, Ninos)
    SELECT IdHabitacion, IdTipoHabitacion, Adultos, ISNULL(Ninos, 0)
    FROM OPENJSON(@Habitaciones) WITH (IdHabitacion INT, IdTipoHabitacion INT, Adultos INT, Ninos INT);
    IF NOT EXISTS (SELECT 1 FROM @Items) THROW 50003, N'Debe indicar al menos una habitación.', 1;
    IF EXISTS (SELECT 1 FROM @Items WHERE Adultos IS NULL OR Adultos < 1 OR Ninos < 0 OR Adultos + Ninos > 8)
        THROW 50004, N'Cada habitación necesita al menos un adulto y máximo 8 personas.', 1;
    EXEC res.sp_ValidarFechasReserva @FechaEntrada, @FechaSalida;
    IF NOT EXISTS (SELECT 1 FROM res.Cliente WHERE IdCliente = @IdCliente AND Activo = 1)
        THROW 50005, N'Cliente inexistente o inactivo.', 1;

    BEGIN TRY
        BEGIN TRAN;
        EXEC res.sp_BloquearDisponibilidad;          -- también serializa el conteo de usos de los descuentos
        EXEC res.sp_MantenimientoReservas @Silencioso = 1;

        IF @CodigoDescuento IS NOT NULL
        BEGIN
            SELECT @IdDescCodigo = IdDescuento FROM res.Descuento WHERE Codigo = @CodigoDescuento AND Clase = 'PROMOCION';
            IF @IdDescCodigo IS NULL OR res.fn_DescuentoAplicable(@IdDescCodigo, @IdCliente, @FechaEntrada, @FechaSalida, NULL) = 0
                THROW 50151, N'El código de descuento no existe, no está vigente o ya alcanzó su límite de usos.', 1;
        END

        INSERT res.Reserva(IdCliente, FechaEntrada, FechaSalida, Canal, PorcentajeAnticipo, FechaExpiracion, Observaciones, CreadoPor)
        VALUES (@IdCliente, @FechaEntrada, @FechaSalida, @Canal, dbo.fn_Param('PCT_ANTICIPO'),
                DATEADD(MINUTE, CAST(dbo.fn_Param('MIN_EXPIRA_PENDIENTE') AS INT), SYSDATETIME()), @Observaciones, @IdUsuario);
        SET @IdReserva = SCOPE_IDENTITY();

        DECLARE @Fila INT = 1, @Max INT = (SELECT MAX(Fila) FROM @Items), @IdHab INT, @IdTipo INT, @Ad INT, @Ni INT;
        WHILE @Fila <= @Max
        BEGIN
            SELECT @IdHab = IdHabitacion, @IdTipo = IdTipoHabitacion, @Ad = Adultos, @Ni = Ninos FROM @Items WHERE Fila = @Fila;
            IF @IdHab IS NOT NULL AND res.fn_HabitacionDisponible(@IdHab, @FechaEntrada, @FechaSalida, NULL) = 0
                THROW 50011, N'La habitación seleccionada ya no está disponible para esas fechas.', 1;
            IF @IdHab IS NULL
            BEGIN
                SELECT TOP (1) @IdHab = h.IdHabitacion
                FROM hab.Habitacion h JOIN hab.TipoHabitacion t ON t.IdTipoHabitacion = h.IdTipoHabitacion
                WHERE h.Activa = 1 AND t.Activo = 1 AND t.CapacidadMaxima >= @Ad + @Ni
                  AND (@IdTipo IS NULL OR t.IdTipoHabitacion = @IdTipo)
                  AND res.fn_HabitacionDisponible(h.IdHabitacion, @FechaEntrada, @FechaSalida, NULL) = 1
                ORDER BY t.CapacidadMaxima, t.PrecioNoche, h.IdHabitacion;
                IF @IdHab IS NULL
                    THROW 50010, N'No hay habitaciones disponibles para esas fechas y cantidad de personas (hotel lleno).', 1;
            END
            INSERT res.ReservaHabitacion(IdReserva, IdHabitacion, FechaDesde, FechaHasta, Adultos, Ninos, CapacidadBase, PrecioNoche, PrecioPersonaExtra)
            SELECT @IdReserva, h.IdHabitacion, @FechaEntrada, @FechaSalida, @Ad, @Ni, t.CapacidadBase, t.PrecioNoche, t.PrecioPersonaExtra
            FROM hab.Habitacion h JOIN hab.TipoHabitacion t ON t.IdTipoHabitacion = h.IdTipoHabitacion
            WHERE h.IdHabitacion = @IdHab;
            SET @IdLinea = SCOPE_IDENTITY();
            EXEC res.sp_GenerarNoches @IdLinea;
            SET @Fila += 1;
        END

        EXEC res.sp_RecalcularReserva @IdReserva;

        -- Descuento: el que más rebaje del hospedaje entre el código ingresado y el de cliente frecuente
        SELECT @Sub = Subtotal FROM res.Reserva WHERE IdReserva = @IdReserva;
        SELECT TOP (1) @IdDescFrec = d.IdDescuento FROM res.Descuento d
        WHERE d.Clase = 'CLIENTE_FRECUENTE' AND res.fn_DescuentoAplicable(d.IdDescuento, @IdCliente, @FechaEntrada, @FechaSalida, NULL) = 1
        ORDER BY res.fn_MontoDescuento(d.IdDescuento, @Sub) DESC, d.IdDescuento;
        SET @IdDesc = CASE WHEN @IdDescCodigo IS NULL THEN @IdDescFrec
                           WHEN @IdDescFrec   IS NULL THEN @IdDescCodigo
                           WHEN res.fn_MontoDescuento(@IdDescFrec, @Sub) > res.fn_MontoDescuento(@IdDescCodigo, @Sub) THEN @IdDescFrec
                           ELSE @IdDescCodigo END;
        IF @IdDesc IS NOT NULL
        BEGIN
            UPDATE res.Reserva SET IdDescuento = @IdDesc WHERE IdReserva = @IdReserva;
            EXEC res.sp_RecalcularReserva @IdReserva;
        END

        -- Si el anticipo configurado es 0%, se confirma de una vez
        UPDATE res.Reserva SET Estado = 'CONFIRMADA', FechaExpiracion = NULL
        WHERE IdReserva = @IdReserva AND AnticipoRequerido = 0;

        INSERT dbo.ColaCorreo(Destinatario, Asunto, Cuerpo, Tipo, IdReferencia)
        SELECT pe.Correo, CONCAT(N'Reserva ', r.CodigoReserva, N' registrada'),
               CONCAT(N'Su reserva del ', CONVERT(CHAR(10), r.FechaEntrada, 103), N' al ', CONVERT(CHAR(10), r.FechaSalida, 103),
                      N' fue registrada. Total: ', FORMAT(r.Total, 'N2'), N'. Anticipo requerido: ', FORMAT(r.AnticipoRequerido, 'N2'),
                      IIF(r.Estado = 'PENDIENTE', CONCAT(N', pagar antes de ', FORMAT(r.FechaExpiracion, 'dd/MM/yyyy HH:mm')), N''), N'.'),
               'RESERVA_CREADA', r.IdReserva
        FROM res.Reserva r JOIN dbo.Persona pe ON pe.IdPersona = r.IdCliente WHERE r.IdReserva = @IdReserva;
        COMMIT;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH

    SELECT r.IdReserva, r.CodigoReserva, r.Estado, r.Subtotal, d.Nombre AS Descuento, r.MontoDescuento, r.MontoImpuesto, r.Total,
           r.AnticipoRequerido, r.FechaExpiracion
    FROM res.Reserva r LEFT JOIN res.Descuento d ON d.IdDescuento = r.IdDescuento WHERE r.IdReserva = @IdReserva;
    SELECT lin.IdReservaHabitacion, h.Codigo, lin.Adultos, lin.Ninos, lin.PersonasExtra, lin.Noches, lin.MontoTotal
    FROM res.ReservaHabitacion lin JOIN hab.Habitacion h ON h.IdHabitacion = lin.IdHabitacion WHERE lin.IdReserva = @IdReserva;
    SELECT Numero, Concepto, MontoProgramado, FechaLimite, Estado FROM res.Abono WHERE IdReserva = @IdReserva ORDER BY Numero;
END
GO
/* Aplica o reemplaza el descuento de una reservación (no son acumulables).
   - Cliente desde la app: solo códigos promocionales y solo si le rebaja más que el que ya tiene
   - Personal: cualquier descuento vigente (cortesías incluidas), con permiso RESERVAS/E */
CREATE PROCEDURE res.sp_AplicarDescuento
    @IdReserva INT, @IdDescuento INT = NULL, @CodigoDescuento VARCHAR(30) = NULL,
    @IdUsuario INT = NULL, @IdClienteSolicitante INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Estado VARCHAR(12), @IdCliente INT, @Entrada DATE, @Salida DATE, @Actual INT, @Sub DECIMAL(12,2);
    IF @IdClienteSolicitante IS NULL EXEC seg.sp_ExigirPermiso @IdUsuario, 'RESERVAS', 'E';
    IF @IdDescuento IS NULL SELECT @IdDescuento = IdDescuento FROM res.Descuento WHERE Codigo = @CodigoDescuento;
    BEGIN TRY
        BEGIN TRAN;
        EXEC res.sp_BloquearDisponibilidad;
        SELECT @Estado = Estado, @IdCliente = IdCliente, @Entrada = FechaEntrada, @Salida = FechaSalida,
               @Actual = IdDescuento, @Sub = Subtotal
        FROM res.Reserva WITH (UPDLOCK, HOLDLOCK) WHERE IdReserva = @IdReserva;
        IF @Estado IS NULL THROW 50030, N'La reservación no existe.', 1;
        IF @IdClienteSolicitante IS NOT NULL AND @IdClienteSolicitante <> @IdCliente THROW 50101, N'No autorizado.', 1;
        IF @Estado NOT IN ('PENDIENTE','CONFIRMADA','CHECKIN') THROW 50021, N'La reservación no admite cambios en su estado actual.', 1;
        IF @IdClienteSolicitante IS NOT NULL AND NOT EXISTS (SELECT 1 FROM res.Descuento WHERE IdDescuento = @IdDescuento AND Clase = 'PROMOCION')
            THROW 50152, N'Desde la app solo se pueden aplicar códigos promocionales.', 1;
        IF @IdDescuento IS NULL OR res.fn_DescuentoAplicable(@IdDescuento, @IdCliente, @Entrada, @Salida, @IdReserva) = 0
            THROW 50151, N'El código de descuento no existe, no está vigente o ya alcanzó su límite de usos.', 1;
        IF @IdClienteSolicitante IS NOT NULL AND @Actual IS NOT NULL
           AND res.fn_MontoDescuento(@Actual, @Sub) >= res.fn_MontoDescuento(@IdDescuento, @Sub)
            THROW 50153, N'La reservación ya tiene un descuento igual o mejor (los descuentos no son acumulables).', 1;
        UPDATE res.Reserva SET IdDescuento = @IdDescuento, FechaModificacion = SYSDATETIME() WHERE IdReserva = @IdReserva;
        EXEC res.sp_RecalcularReserva @IdReserva;
        COMMIT;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH
    SELECT r.CodigoReserva, d.Nombre AS Descuento, r.Subtotal, r.MontoDescuento, r.MontoImpuesto, r.Total,
           r.AnticipoRequerido, r.MontoPagado, r.SaldoTotal
    FROM res.Reserva r JOIN res.Descuento d ON d.IdDescuento = r.IdDescuento WHERE r.IdReserva = @IdReserva;
END
GO
CREATE PROCEDURE res.sp_RegistrarPago
    @IdReserva INT, @TipoMovimiento VARCHAR(12), @Metodo VARCHAR(15), @Monto DECIMAL(12,2),
    @Referencia VARCHAR(50) = NULL, @IdUsuario INT = NULL, @IdFactura INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @TipoMovimiento = 'REEMBOLSO' EXEC seg.sp_ExigirPermiso @IdUsuario, 'FACTURACION', 'A';
    INSERT res.Pago(IdReserva, IdFactura, TipoMovimiento, Metodo, Monto, Referencia, RegistradoPor)
    VALUES (@IdReserva, @IdFactura, @TipoMovimiento, @Metodo, @Monto, @Referencia, @IdUsuario);
    SELECT IdReserva, CodigoReserva, Estado, Total, AnticipoRequerido, MontoPagado, SaldoAnticipo, SaldoTotal
    FROM res.Reserva WHERE IdReserva = @IdReserva;
    SELECT Numero, Concepto, MontoProgramado, MontoPagado, SaldoPendiente, FechaLimite, Estado
    FROM res.Abono WHERE IdReserva = @IdReserva ORDER BY Numero;
END
GO
/* "Vinieron 2 y ahora son 4":
   - Si caben en la habitación: recalcula el cargo por persona extra y devuelve cuánto anticipo falta
   - Si no caben: error indicando que debe cambiar de habitación o agregar otra
   - Si la estadía ya está en curso, las noches ya usadas se cobran con la ocupación anterior */
CREATE PROCEDURE res.sp_ModificarHuespedes @IdReservaHabitacion INT, @Adultos TINYINT, @Ninos TINYINT, @IdUsuario INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @IdReserva INT, @EstadoRes VARCHAR(12), @Desde DATE, @Hasta DATE, @CapMax TINYINT, @CodHab VARCHAR(10),
            @TotalAntes DECIMAL(12,2), @Hoy DATE = CAST(SYSDATETIME() AS DATE), @Nueva INT;
    IF @Adultos < 1 THROW 50022, N'Debe haber al menos un adulto.', 1;
    BEGIN TRY
        BEGIN TRAN;
        EXEC res.sp_BloquearDisponibilidad;
        SELECT @IdReserva = lin.IdReserva, @EstadoRes = r.Estado, @Desde = lin.FechaDesde, @Hasta = lin.FechaHasta,
               @CapMax = t.CapacidadMaxima, @CodHab = h.Codigo, @TotalAntes = r.Total
        FROM res.ReservaHabitacion lin
        JOIN res.Reserva r        ON r.IdReserva = lin.IdReserva
        JOIN hab.Habitacion h     ON h.IdHabitacion = lin.IdHabitacion
        JOIN hab.TipoHabitacion t ON t.IdTipoHabitacion = h.IdTipoHabitacion
        WHERE lin.IdReservaHabitacion = @IdReservaHabitacion AND lin.Estado = 'ACTIVA';
        IF @IdReserva IS NULL THROW 50020, N'La línea de reservación no existe o no está activa.', 1;
        IF @EstadoRes NOT IN ('PENDIENTE','CONFIRMADA','CHECKIN') THROW 50021, N'La reservación no admite cambios en su estado actual.', 1;
        IF @Adultos + @Ninos > @CapMax
        BEGIN
            DECLARE @m NVARCHAR(300) = CONCAT(N'La habitación ', @CodHab, N' admite máximo ', @CapMax,
                                              N' personas. Debe cambiar de habitación o agregar otra a la reservación.');
            THROW 50023, @m, 1;
        END
        IF @EstadoRes = 'CHECKIN' AND @Hoy > @Desde AND @Hoy < @Hasta
        BEGIN
            UPDATE res.ReservaHabitacion SET FechaHasta = @Hoy, Estado = 'CAMBIADA', MotivoCambio = 'Cambio de ocupación'
            WHERE IdReservaHabitacion = @IdReservaHabitacion;
            INSERT res.ReservaHabitacion(IdReserva, IdHabitacion, FechaDesde, FechaHasta, Adultos, Ninos, CapacidadBase,
                                         PrecioNoche, PrecioPersonaExtra, IdReservaHabitacionOrigen, MotivoCambio)
            SELECT IdReserva, IdHabitacion, @Hoy, @Hasta, @Adultos, @Ninos, CapacidadBase, PrecioNoche, PrecioPersonaExtra,
                   IdReservaHabitacion, 'Cambio de ocupación'
            FROM res.ReservaHabitacion WHERE IdReservaHabitacion = @IdReservaHabitacion;
            SET @Nueva = SCOPE_IDENTITY();
            EXEC res.sp_GenerarNoches @Nueva;              -- hereda el precio de temporada pactado
            UPDATE hab.TarjetaHabitacion SET IdReservaHabitacion = @Nueva
            WHERE IdReservaHabitacion = @IdReservaHabitacion AND Estado = 'ACTIVA';
        END
        ELSE
            UPDATE res.ReservaHabitacion SET Adultos = @Adultos, Ninos = @Ninos WHERE IdReservaHabitacion = @IdReservaHabitacion;

        EXEC res.sp_RecalcularReserva @IdReserva;
        COMMIT;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH

    SELECT CodigoReserva, @TotalAntes AS TotalAnterior, Total AS TotalNuevo, Total - @TotalAntes AS Diferencia,
           AnticipoRequerido, MontoPagado, SaldoAnticipo AS AnticipoAdicionalPorPagar, SaldoTotal
    FROM res.Reserva WHERE IdReserva = @IdReserva;
END
GO
-- Cambio de habitación (antes o durante la estadía). Sin @IdHabitacionNueva se asigna automáticamente
CREATE PROCEDURE res.sp_CambiarHabitacion
    @IdReservaHabitacion INT, @IdHabitacionNueva INT = NULL, @Adultos TINYINT = NULL, @Ninos TINYINT = NULL,
    @Motivo VARCHAR(200), @IdUsuario INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @IdReserva INT, @EstadoRes VARCHAR(12), @Desde DATE, @Hasta DATE, @IdHabAnt INT, @IdTipoAnt INT,
            @Ad INT, @Ni INT, @Efectiva DATE, @Hoy DATE = CAST(SYSDATETIME() AS DATE), @TotalAntes DECIMAL(12,2), @Nueva INT;
    BEGIN TRY
        BEGIN TRAN;
        EXEC res.sp_BloquearDisponibilidad;
        SELECT @IdReserva = lin.IdReserva, @EstadoRes = r.Estado, @Desde = lin.FechaDesde, @Hasta = lin.FechaHasta,
               @IdHabAnt = lin.IdHabitacion, @IdTipoAnt = h.IdTipoHabitacion,
               @Ad = ISNULL(@Adultos, lin.Adultos), @Ni = ISNULL(@Ninos, lin.Ninos), @TotalAntes = r.Total
        FROM res.ReservaHabitacion lin
        JOIN res.Reserva r    ON r.IdReserva = lin.IdReserva
        JOIN hab.Habitacion h ON h.IdHabitacion = lin.IdHabitacion
        WHERE lin.IdReservaHabitacion = @IdReservaHabitacion AND lin.Estado = 'ACTIVA';
        IF @IdReserva IS NULL THROW 50020, N'La línea de reservación no existe o no está activa.', 1;
        IF @EstadoRes NOT IN ('PENDIENTE','CONFIRMADA','CHECKIN') THROW 50021, N'La reservación no admite cambios en su estado actual.', 1;
        SET @Efectiva = IIF(@EstadoRes = 'CHECKIN' AND @Hoy > @Desde, @Hoy, @Desde);
        IF @Efectiva >= @Hasta THROW 50024, N'La estadía en esa habitación ya terminó.', 1;
        IF @IdHabitacionNueva = @IdHabAnt THROW 50025, N'La habitación nueva debe ser distinta a la actual.', 1;

        IF @IdHabitacionNueva IS NOT NULL
        BEGIN
            IF res.fn_HabitacionDisponible(@IdHabitacionNueva, @Efectiva, @Hasta, NULL) = 0
                THROW 50011, N'La habitación seleccionada no está disponible para esas fechas.', 1;
        END
        ELSE
        BEGIN
            SELECT TOP (1) @IdHabitacionNueva = h.IdHabitacion
            FROM hab.Habitacion h JOIN hab.TipoHabitacion t ON t.IdTipoHabitacion = h.IdTipoHabitacion
            WHERE h.Activa = 1 AND t.Activo = 1 AND h.IdHabitacion <> @IdHabAnt AND t.CapacidadMaxima >= @Ad + @Ni
              AND (@EstadoRes <> 'CHECKIN' OR h.Estado = 'DISPONIBLE')
              AND res.fn_HabitacionDisponible(h.IdHabitacion, @Efectiva, @Hasta, NULL) = 1
            ORDER BY IIF(t.IdTipoHabitacion = @IdTipoAnt, 0, 1), t.CapacidadMaxima, t.PrecioNoche, h.IdHabitacion;
            IF @IdHabitacionNueva IS NULL THROW 50010, N'No hay habitaciones disponibles para el cambio (hotel lleno).', 1;
        END
        IF @EstadoRes = 'CHECKIN' AND EXISTS (SELECT 1 FROM hab.Habitacion WHERE IdHabitacion = @IdHabitacionNueva AND Estado <> 'DISPONIBLE')
            THROW 50026, N'La habitación nueva no está lista (ocupada, en limpieza o mantenimiento).', 1;

        IF @Efectiva = @Desde
            UPDATE res.ReservaHabitacion SET Estado = 'CANCELADA', MotivoCambio = @Motivo WHERE IdReservaHabitacion = @IdReservaHabitacion;
        ELSE
            UPDATE res.ReservaHabitacion SET Estado = 'CAMBIADA', FechaHasta = @Efectiva, MotivoCambio = @Motivo WHERE IdReservaHabitacion = @IdReservaHabitacion;

        INSERT res.ReservaHabitacion(IdReserva, IdHabitacion, FechaDesde, FechaHasta, Adultos, Ninos, CapacidadBase,
                                     PrecioNoche, PrecioPersonaExtra, IdReservaHabitacionOrigen, MotivoCambio)
        SELECT @IdReserva, h.IdHabitacion, @Efectiva, @Hasta, @Ad, @Ni, t.CapacidadBase, t.PrecioNoche, t.PrecioPersonaExtra,
               @IdReservaHabitacion, @Motivo
        FROM hab.Habitacion h JOIN hab.TipoHabitacion t ON t.IdTipoHabitacion = h.IdTipoHabitacion
        WHERE h.IdHabitacion = @IdHabitacionNueva;
        SET @Nueva = SCOPE_IDENTITY();
        EXEC res.sp_GenerarNoches @Nueva;                  -- tarifa del tipo nuevo con el % de temporada ya pactado

        -- Las tarjetas/QR de la habitación anterior dejan de abrir
        UPDATE hab.TarjetaHabitacion SET Estado = 'REVOCADA', FechaRevocacion = SYSDATETIME()
        WHERE IdReservaHabitacion = @IdReservaHabitacion AND Estado = 'ACTIVA';
        IF @EstadoRes = 'CHECKIN'
        BEGIN
            UPDATE hab.Habitacion SET Estado = 'LIMPIEZA' WHERE IdHabitacion = @IdHabAnt;
            UPDATE hab.Habitacion SET Estado = 'OCUPADA'  WHERE IdHabitacion = @IdHabitacionNueva;
        END
        EXEC res.sp_RecalcularReserva @IdReserva;

        INSERT dbo.ColaCorreo(Destinatario, Asunto, Cuerpo, Tipo, IdReferencia)
        SELECT pe.Correo, CONCAT(N'Cambio en su reserva ', r.CodigoReserva),
               CONCAT(N'Su habitación fue cambiada a la ', h.Codigo, N' desde el ', CONVERT(CHAR(10), @Efectiva, 103),
                      N'. Nuevo total: ', FORMAT(r.Total, 'N2'), N'.'), 'CAMBIO_RESERVA', r.IdReserva
        FROM res.Reserva r JOIN dbo.Persona pe ON pe.IdPersona = r.IdCliente
        CROSS JOIN hab.Habitacion h WHERE r.IdReserva = @IdReserva AND h.IdHabitacion = @IdHabitacionNueva;
        COMMIT;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH

    SELECT r.CodigoReserva, h.Codigo AS HabitacionNueva, @TotalAntes AS TotalAnterior, r.Total AS TotalNuevo,
           r.Total - @TotalAntes AS Diferencia, r.AnticipoRequerido, r.MontoPagado,
           r.SaldoAnticipo AS AnticipoAdicionalPorPagar, r.SaldoTotal
    FROM res.Reserva r CROSS JOIN hab.Habitacion h
    WHERE r.IdReserva = @IdReserva AND h.IdHabitacion = @IdHabitacionNueva;
END
GO
-- Vista previa para mostrar al cliente ANTES de confirmar la cancelación
CREATE PROCEDURE res.sp_SimularCancelacion @IdReserva INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM res.fn_CalculoCancelacion(@IdReserva, SYSDATETIME());
END
GO
CREATE PROCEDURE res.sp_CancelarReserva
    @IdReserva INT, @Motivo VARCHAR(300), @IdUsuario INT = NULL, @IdClienteSolicitante INT = NULL,
    @MetodoReembolso VARCHAR(15) = 'TRANSFERENCIA'
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Ahora DATETIME2(0) = SYSDATETIME(), @Estado VARCHAR(12), @IdCliente INT, @IdFactura INT,
            @Retenido DECIMAL(12,2), @Desc VARCHAR(200);
    DECLARE @Calc TABLE (HorasAntelacion INT, IdPolitica INT, Politica VARCHAR(80), PorcentajePenalizacion DECIMAL(5,2),
                         EsFrecuente BIT, PorcentajeAplicado DECIMAL(5,2), MontoPagado DECIMAL(12,2),
                         MontoRetenido DECIMAL(12,2), MontoReembolso DECIMAL(12,2));
    IF @IdClienteSolicitante IS NULL EXEC seg.sp_ExigirPermiso @IdUsuario, 'RESERVAS', 'A';
    BEGIN TRY
        BEGIN TRAN;
        SELECT @Estado = Estado, @IdCliente = IdCliente FROM res.Reserva WITH (UPDLOCK, HOLDLOCK) WHERE IdReserva = @IdReserva;
        IF @Estado IS NULL THROW 50030, N'La reservación no existe.', 1;
        IF @IdClienteSolicitante IS NOT NULL AND @IdClienteSolicitante <> @IdCliente THROW 50101, N'No autorizado.', 1;
        IF @Estado = 'CHECKIN' THROW 50031, N'El huésped ya ingresó: no se cancela, se hace check-out.', 1;
        IF @Estado NOT IN ('PENDIENTE','CONFIRMADA') THROW 50032, N'La reservación ya está cerrada o cancelada.', 1;

        INSERT @Calc SELECT HorasAntelacion, IdPolitica, Politica, PorcentajePenalizacion, EsFrecuente, PorcentajeAplicado,
                            MontoPagado, MontoRetenido, MontoReembolso
                     FROM res.fn_CalculoCancelacion(@IdReserva, @Ahora);

        INSERT res.Cancelacion(IdReserva, FechaCancelacion, HorasAntelacion, IdPolitica, PorcentajePolitica, EraClienteFrecuente,
                               PorcentajeAplicado, MontoPagado, MontoRetenido, MontoReembolso, Motivo, CanceladoPor)
        SELECT @IdReserva, @Ahora, HorasAntelacion, IdPolitica, PorcentajePenalizacion, EsFrecuente,
               PorcentajeAplicado, MontoPagado, MontoRetenido, MontoReembolso, @Motivo, @IdUsuario
        FROM @Calc;

        UPDATE res.ReservaHabitacion SET Estado = 'CANCELADA' WHERE IdReserva = @IdReserva AND Estado = 'ACTIVA';
        UPDATE res.Reserva SET Estado = 'CANCELADA', FechaModificacion = @Ahora WHERE IdReserva = @IdReserva;
        UPDATE res.Abono SET Estado = 'ANULADO' WHERE IdReserva = @IdReserva AND Estado IN ('PENDIENTE','VENCIDO');

        INSERT res.Pago(IdReserva, TipoMovimiento, Metodo, Monto, Referencia, RegistradoPor)
        SELECT @IdReserva, 'REEMBOLSO', @MetodoReembolso, MontoReembolso, 'CANCELACION', @IdUsuario
        FROM @Calc WHERE MontoReembolso > 0;

        -- Lo retenido se factura como penalización (ya está pagado con el anticipo)
        SELECT @Retenido = MontoRetenido,
               @Desc = CONCAT('Penalización por cancelación (', PorcentajeAplicado, '% del monto pagado)')
        FROM @Calc;
        IF @Retenido > 0
            EXEC fac.sp_FacturarPenalizacion @IdReserva, @Retenido, @Desc, @IdUsuario, @IdFactura OUTPUT;

        INSERT dbo.ColaCorreo(Destinatario, Asunto, Cuerpo, Tipo, IdReferencia)
        SELECT pe.Correo, CONCAT(N'Cancelación de la reserva ', r.CodigoReserva),
               CONCAT(N'Su reserva ', r.CodigoReserva, N' fue cancelada con ', k.HorasAntelacion, N' horas de anticipación. ',
                      N'Monto pagado: ', FORMAT(k.MontoPagado, 'N2'), N'. Penalización: ', k.PorcentajeAplicado, N'% (',
                      FORMAT(k.MontoRetenido, 'N2'), N'). Reembolso: ', FORMAT(k.MontoReembolso, 'N2'), N'.',
                      IIF(k.EsFrecuente = 1, N' Se aplicó el beneficio de cliente frecuente.', N'')),
               'RESERVA_CANCELADA', r.IdReserva
        FROM res.Reserva r JOIN dbo.Persona pe ON pe.IdPersona = r.IdCliente CROSS JOIN @Calc k
        WHERE r.IdReserva = @IdReserva;
        COMMIT;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH
    SELECT * FROM @Calc;
END
GO

-- 15. PROCEDIMIENTOS — HABITACIONES, RECEPCIÓN Y TARJETAS

-- Asigna o quita una amenidad a un tipo de habitación (todas sus habitaciones) o a una habitación puntual
CREATE PROCEDURE hab.sp_ConfigurarAmenidad @IdAmenidad INT, @Asignar BIT, @IdTipoHabitacion INT = NULL, @IdHabitacion INT = NULL, @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC seg.sp_ExigirPermiso @IdUsuario, 'HABITACIONES', 'E';
    IF (@IdTipoHabitacion IS NULL AND @IdHabitacion IS NULL) OR (@IdTipoHabitacion IS NOT NULL AND @IdHabitacion IS NOT NULL)
        THROW 50141, N'Indique el tipo de habitación o la habitación (solo uno de los dos).', 1;
    IF @IdTipoHabitacion IS NOT NULL
    BEGIN
        IF @Asignar = 1
            INSERT hab.TipoHabitacionAmenidad(IdTipoHabitacion, IdAmenidad)
            SELECT @IdTipoHabitacion, @IdAmenidad
            WHERE NOT EXISTS (SELECT 1 FROM hab.TipoHabitacionAmenidad WHERE IdTipoHabitacion = @IdTipoHabitacion AND IdAmenidad = @IdAmenidad);
        ELSE
            DELETE hab.TipoHabitacionAmenidad WHERE IdTipoHabitacion = @IdTipoHabitacion AND IdAmenidad = @IdAmenidad;
    END
    ELSE
    BEGIN
        IF @Asignar = 1
            INSERT hab.HabitacionAmenidad(IdHabitacion, IdAmenidad)
            SELECT @IdHabitacion, @IdAmenidad
            WHERE NOT EXISTS (SELECT 1 FROM hab.HabitacionAmenidad WHERE IdHabitacion = @IdHabitacion AND IdAmenidad = @IdAmenidad);
        ELSE
            DELETE hab.HabitacionAmenidad WHERE IdHabitacion = @IdHabitacion AND IdAmenidad = @IdAmenidad;
    END
END
GO
CREATE PROCEDURE hab.sp_CambiarEstadoHabitacion @IdHabitacion INT, @Estado VARCHAR(15), @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC seg.sp_ExigirPermiso @IdUsuario, 'HABITACIONES', 'E';
    IF @Estado = 'OCUPADA' THROW 50047, N'El estado OCUPADA solo lo asigna el check-in.', 1;
    IF EXISTS (SELECT 1 FROM res.ReservaHabitacion lin JOIN res.Reserva r ON r.IdReserva = lin.IdReserva
               WHERE lin.IdHabitacion = @IdHabitacion AND lin.Estado = 'ACTIVA' AND r.Estado = 'CHECKIN')
        THROW 50048, N'La habitación tiene un huésped hospedado: haga el cambio de habitación o el check-out primero.', 1;
    IF @Estado = 'FUERA_SERVICIO' AND EXISTS (
               SELECT 1 FROM res.ReservaHabitacion lin JOIN res.Reserva r ON r.IdReserva = lin.IdReserva
               WHERE lin.IdHabitacion = @IdHabitacion AND lin.Estado = 'ACTIVA' AND r.Estado IN ('PENDIENTE','CONFIRMADA'))
        THROW 50049, N'Hay reservaciones futuras en esta habitación: reubíquelas antes de ponerla fuera de servicio.', 1;
    UPDATE hab.Habitacion SET Estado = @Estado WHERE IdHabitacion = @IdHabitacion;
END
GO
CREATE PROCEDURE hab.sp_CheckIn @IdReserva INT, @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC seg.sp_ExigirPermiso @IdUsuario, 'RECEPCION', 'E';
    DECLARE @Estado VARCHAR(12), @Entrada DATE, @Salida DATE, @Hoy DATE = CAST(SYSDATETIME() AS DATE);
    BEGIN TRY
        BEGIN TRAN;
        SELECT @Estado = Estado, @Entrada = FechaEntrada, @Salida = FechaSalida
        FROM res.Reserva WITH (UPDLOCK) WHERE IdReserva = @IdReserva;
        IF @Estado IS NULL THROW 50030, N'La reservación no existe.', 1;
        IF @Estado <> 'CONFIRMADA' THROW 50040, N'Solo se hace check-in de reservaciones CONFIRMADAS (anticipo pagado).', 1;
        IF @Hoy < @Entrada OR @Hoy >= @Salida THROW 50041, N'El check-in solo puede hacerse dentro de las fechas reservadas.', 1;
        IF EXISTS (SELECT 1 FROM res.ReservaHabitacion lin JOIN hab.Habitacion h ON h.IdHabitacion = lin.IdHabitacion
                   WHERE lin.IdReserva = @IdReserva AND lin.Estado = 'ACTIVA' AND lin.FechaDesde <= @Hoy AND h.Estado <> 'DISPONIBLE')
            THROW 50042, N'Alguna habitación asignada no está lista. Asigne otra con el cambio de habitación.', 1;
        UPDATE res.Reserva SET Estado = 'CHECKIN', FechaModificacion = SYSDATETIME() WHERE IdReserva = @IdReserva;
        UPDATE h SET Estado = 'OCUPADA'
        FROM hab.Habitacion h JOIN res.ReservaHabitacion lin ON lin.IdHabitacion = h.IdHabitacion
        WHERE lin.IdReserva = @IdReserva AND lin.Estado = 'ACTIVA' AND lin.FechaDesde <= @Hoy;
        COMMIT;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH
    SELECT lin.IdReservaHabitacion, h.Codigo, lin.Adultos + lin.Ninos AS Personas
    FROM res.ReservaHabitacion lin JOIN hab.Habitacion h ON h.IdHabitacion = lin.IdHabitacion
    WHERE lin.IdReserva = @IdReserva AND lin.Estado = 'ACTIVA';
END
GO
/* Tarjeta / QR: el backend genera un token aleatorio (32 bytes), lo pone en el QR y envía SOLO su SHA-256.
   Si alguien roba la base, los hashes no sirven para abrir habitaciones. */
CREATE PROCEDURE hab.sp_EmitirTarjeta @IdReservaHabitacion INT, @TokenQRHash BINARY(32), @CodigoTarjeta VARCHAR(20), @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC seg.sp_ExigirPermiso @IdUsuario, 'RECEPCION', 'C';
    INSERT hab.TarjetaHabitacion(IdReservaHabitacion, IdHabitacion, CodigoTarjeta, TokenQRHash, ValidaDesde, ValidaHasta, EmitidaPor)
    SELECT lin.IdReservaHabitacion, lin.IdHabitacion, @CodigoTarjeta, @TokenQRHash, SYSDATETIME(),
           DATEADD(HOUR, CAST(dbo.fn_Param('HORA_CHECKOUT') AS INT), CAST(lin.FechaHasta AS DATETIME2(0))), @IdUsuario
    FROM res.ReservaHabitacion lin WHERE lin.IdReservaHabitacion = @IdReservaHabitacion;
    IF @@ROWCOUNT = 0 THROW 50020, N'La línea de reservación no existe.', 1;
    SELECT CAST(SCOPE_IDENTITY() AS INT) AS IdTarjeta;
END
GO
CREATE PROCEDURE hab.sp_RevocarTarjeta @IdTarjeta INT, @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC seg.sp_ExigirPermiso @IdUsuario, 'RECEPCION', 'E';
    UPDATE hab.TarjetaHabitacion SET Estado = 'REVOCADA', FechaRevocacion = SYSDATETIME() WHERE IdTarjeta = @IdTarjeta AND Estado = 'ACTIVA';
END
GO
-- Lo llama la cerradura/lector o la app al escanear el QR
CREATE PROCEDURE hab.sp_ValidarAcceso @TokenQRHash BINARY(32), @IdHabitacion INT, @Medio VARCHAR(10) = 'QR'
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @IdTarjeta INT, @Motivo VARCHAR(100), @Ahora DATETIME2(0) = SYSDATETIME(), @Hasta DATETIME2(0);
    SELECT @IdTarjeta = t.IdTarjeta, @Hasta = t.ValidaHasta,
           @Motivo = CASE WHEN t.Estado <> 'ACTIVA'                              THEN 'Tarjeta revocada o expirada'
                          WHEN t.IdHabitacion <> @IdHabitacion                   THEN 'La tarjeta no corresponde a esta habitación'
                          WHEN @Ahora NOT BETWEEN t.ValidaDesde AND t.ValidaHasta THEN 'Fuera del periodo de validez'
                          WHEN lin.Estado <> 'ACTIVA' OR r.Estado <> 'CHECKIN'   THEN 'La estadía no está activa'
                          ELSE NULL END
    FROM hab.TarjetaHabitacion t
    JOIN res.ReservaHabitacion lin ON lin.IdReservaHabitacion = t.IdReservaHabitacion
    JOIN res.Reserva r ON r.IdReserva = lin.IdReserva
    WHERE t.TokenQRHash = @TokenQRHash;
    IF @IdTarjeta IS NULL SET @Motivo = 'Tarjeta desconocida';
    IF @IdTarjeta IS NOT NULL AND @Ahora > @Hasta
        UPDATE hab.TarjetaHabitacion SET Estado = 'EXPIRADA' WHERE IdTarjeta = @IdTarjeta AND Estado = 'ACTIVA';
    INSERT hab.AccesoHabitacion(IdTarjeta, IdHabitacion, Medio, Permitido, Motivo)
    VALUES (@IdTarjeta, @IdHabitacion, @Medio, IIF(@Motivo IS NULL, 1, 0), @Motivo);
    SELECT CAST(IIF(@Motivo IS NULL, 1, 0) AS BIT) AS Permitido, ISNULL(@Motivo, 'Acceso concedido') AS Mensaje;
END
GO

-- 16. PROCEDIMIENTOS — FACTURACIÓN ELECTRÓNICA

/* Consecutivo (20) = sucursal(3) + terminal(5) + tipo de comprobante(2) + número(10)
   Clave (50)       = 506 + ddMMyy + identificación del emisor(12) + consecutivo(20) + situación(1) + código de seguridad(8)
   El UPDATE bloquea la fila del consecutivo hasta el fin de la transacción: no hay huecos ni números repetidos. */
CREATE PROCEDURE fac.sp_ReservarNumeracion @TipoDocumento VARCHAR(2), @Fecha DATETIME2(0),
                                           @Consecutivo CHAR(20) OUTPUT, @Clave CHAR(50) OUTPUT
AS
BEGIN
    SET NOCOUNT ON;
    IF @@TRANCOUNT = 0 THROW 50175, N'La numeración de comprobantes debe reservarse dentro de una transacción.', 1;
    DECLARE @n BIGINT;
    UPDATE fac.ConsecutivoDocumento SET @n = Ultimo = Ultimo + 1 WHERE TipoDocumento = @TipoDocumento;
    IF @n IS NULL THROW 50176, N'El tipo de comprobante no tiene consecutivo configurado.', 1;
    SET @Consecutivo = CONCAT(RIGHT(CONCAT('000',   CAST(dbo.fn_Param('FE_SUCURSAL') AS INT)), 3),
                              RIGHT(CONCAT('00000', CAST(dbo.fn_Param('FE_TERMINAL') AS INT)), 5),
                              CASE @TipoDocumento WHEN 'FE' THEN '01' WHEN 'NC' THEN '03' WHEN 'TE' THEN '04' END,
                              RIGHT(CONCAT('0000000000', @n), 10));
    SET @Clave = CONCAT('506', FORMAT(@Fecha, 'ddMMyy'),
                        RIGHT(CONCAT('000000000000', CAST(dbo.fn_Param('FE_IDENTIFICACION_EMISOR') AS BIGINT)), 12),
                        @Consecutivo, '1',                                              -- situación 1 = normal
                        RIGHT(CONCAT('00000000', ABS(CHECKSUM(NEWID())) % 100000000), 8));
END
GO
/* Emite un comprobante (FE, TE o NC) a partir de sus líneas. Lo usan los demás procedimientos, no el API.
   - FE si el receptor tiene cédula o DIMEX; TE si tiene pasaporte; NC si anula otro comprobante
   - Los montos del encabezado se calculan con las mismas fórmulas que las columnas de FacturaDetalle */
CREATE PROCEDURE fac.sp_EmitirComprobante
    @IdReserva INT, @TipoFactura VARCHAR(12), @Lineas fac.tp_LineaFactura READONLY, @IdUsuario INT,
    @IdFacturaReferencia INT, @RazonReferencia VARCHAR(180), @IdFactura INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Ahora DATETIME2(0) = SYSDATETIME(), @TipoDoc VARCHAR(2), @Cons CHAR(20), @Clave CHAR(50), @TipoIdRec VARCHAR(15);
    IF @@TRANCOUNT = 0 THROW 50175, N'La emisión de comprobantes debe hacerse dentro de una transacción.', 1;
    IF NOT EXISTS (SELECT 1 FROM @Lineas) THROW 50172, N'Un comprobante necesita al menos una línea.', 1;
    SELECT @TipoIdRec = pe.TipoIdentificacion
    FROM res.Reserva r JOIN dbo.Persona pe ON pe.IdPersona = r.IdCliente WHERE r.IdReserva = @IdReserva;
    SET @TipoDoc = CASE WHEN @IdFacturaReferencia IS NOT NULL THEN 'NC'
                        WHEN @TipoIdRec IN ('CEDULA','DIMEX') THEN 'FE' ELSE 'TE' END;
    EXEC fac.sp_ReservarNumeracion @TipoDoc, @Ahora, @Cons OUTPUT, @Clave OUTPUT;

    INSERT fac.Factura(TipoDocumento, Consecutivo, Clave, CodigoActividad, IdReserva, IdCliente,
                       ReceptorNombre, ReceptorTipoId, ReceptorIdentificacion, ReceptorCorreo, TipoFactura,
                       IdFacturaReferencia, CodigoReferencia, RazonReferencia, FechaEmision,
                       Subtotal, Descuento, Impuesto, Total, EmitidaPor)
    SELECT @TipoDoc, @Cons, @Clave, RIGHT(CONCAT('000000', CAST(dbo.fn_Param('FE_CODIGO_ACTIVIDAD') AS INT)), 6),
           r.IdReserva, r.IdCliente,
           -- la nota de crédito conserva el receptor del comprobante que anula
           COALESCE(o.ReceptorNombre, CONCAT(pe.Nombre, ' ', pe.Apellidos)), COALESCE(o.ReceptorTipoId, pe.TipoIdentificacion),
           COALESCE(o.ReceptorIdentificacion, pe.Identificacion), COALESCE(o.ReceptorCorreo, pe.Correo), @TipoFactura,
           @IdFacturaReferencia, IIF(@IdFacturaReferencia IS NULL, NULL, '01'), @RazonReferencia, @Ahora,
           t.Sub, t.Des, t.Imp, t.Sub - t.Des + t.Imp, @IdUsuario
    FROM res.Reserva r
    JOIN dbo.Persona pe ON pe.IdPersona = r.IdCliente
    LEFT JOIN fac.Factura o ON o.IdFactura = @IdFacturaReferencia
    CROSS JOIN (SELECT SUM(CAST(Cantidad * PrecioUnitario AS DECIMAL(12,2))) AS Sub,
                       SUM(MontoDescuento) AS Des,
                       SUM(CAST(ROUND((CAST(Cantidad * PrecioUnitario AS DECIMAL(12,2)) - MontoDescuento) * PorcentajeImpuesto / 100, 2)
                                AS DECIMAL(12,2))) AS Imp
                FROM @Lineas) t
    WHERE r.IdReserva = @IdReserva;
    SET @IdFactura = SCOPE_IDENTITY();

    INSERT fac.FacturaDetalle(IdFactura, NumeroLinea, TipoLinea, CodigoCabys, Descripcion, Cantidad, UnidadMedida, PrecioUnitario,
                              IdDescuento, PorcentajeDescuento, MontoDescuento, NaturalezaDescuento, PorcentajeImpuesto,
                              IdReservaHabitacion, IdPedido)
    SELECT @IdFactura, ROW_NUMBER() OVER (ORDER BY Orden), TipoLinea, CodigoCabys, Descripcion, Cantidad, UnidadMedida, PrecioUnitario,
           IdDescuento, PorcentajeDescuento, MontoDescuento, NaturalezaDescuento, PorcentajeImpuesto, IdReservaHabitacion, IdPedido
    FROM @Lineas;
END
GO
-- Penalización ya cobrada con lo pagado (cancelación o no-show): se emite y queda PAGADA
CREATE PROCEDURE fac.sp_FacturarPenalizacion @IdReserva INT, @Monto DECIMAL(12,2), @Descripcion VARCHAR(200),
                                             @IdUsuario INT, @IdFactura INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @L fac.tp_LineaFactura;
    INSERT @L(TipoLinea, Descripcion, Cantidad, PrecioUnitario) VALUES ('PENALIZACION', @Descripcion, 1, @Monto);
    EXEC fac.sp_EmitirComprobante @IdReserva, 'PENALIZACION', @L, @IdUsuario, NULL, NULL, @IdFactura OUTPUT;
    UPDATE fac.Factura SET Estado = 'PAGADA' WHERE IdFactura = @IdFactura AND Estado = 'EMITIDA';
END
GO
/* Factura de la estadía con detalle para Hacienda:
   - Hospedaje: una línea por habitación y tramo de tarifa (temporada alta, baja o regular)
   - Servicio a la habitación: una línea por producto (13% IVA) + una línea de cargo por servicio (sin IVA)
   - El descuento de la reservación se aplica POR LÍNEA según a qué aplica; si es un monto fijo se prorratea */
CREATE PROCEDURE fac.sp_GenerarFacturaEstadia @IdReserva INT, @IdUsuario INT = NULL, @IdFactura INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @tc INT = @@TRANCOUNT;
    DECLARE @L fac.tp_LineaFactura;
    DECLARE @Eleg TABLE (Orden INT PRIMARY KEY, Bruto DECIMAL(12,2));
    DECLARE @IVA DECIMAL(5,2) = dbo.fn_Param('PCT_IVA'), @PctServ DECIMAL(5,2) = dbo.fn_Param('PCT_SERVICIO'),
            @IdDesc INT, @TipoDesc VARCHAR(10), @ValorDesc DECIMAL(12,2), @AplicaA VARCHAR(19), @NomDesc VARCHAR(80),
            @Base DECIMAL(12,2), @Fijo DECIMAL(12,2);
    BEGIN TRY
        IF @tc = 0 BEGIN TRAN;
        IF NOT EXISTS (SELECT 1 FROM res.Reserva WHERE IdReserva = @IdReserva AND Estado IN ('CHECKIN','CHECKOUT'))
            THROW 50060, N'Solo se factura una estadía en curso o finalizada.', 1;
        IF EXISTS (SELECT 1 FROM fac.Factura WHERE IdReserva = @IdReserva AND Estado <> 'ANULADA' AND TipoDocumento <> 'NC')
            THROW 50061, N'La reservación ya tiene un comprobante vigente. Anúlelo antes de emitir otro.', 1;

        -- Hospedaje y personas extra: tramos continuos de noches con el mismo precio pactado
        WITH n AS (
            SELECT lin.IdReservaHabitacion, h.Codigo, t.CodigoCabys, lin.PersonasExtra,
                   x.Fecha, x.IdTemporada, x.PrecioNoche, x.PrecioPersonaExtra,
                   DATEDIFF(DAY, '20000101', x.Fecha)
                   - ROW_NUMBER() OVER (PARTITION BY lin.IdReservaHabitacion, x.IdTemporada, x.PrecioNoche, x.PrecioPersonaExtra
                                        ORDER BY x.Fecha) AS Tramo
            FROM res.ReservaHabitacion lin
            JOIN hab.Habitacion h     ON h.IdHabitacion = lin.IdHabitacion
            JOIN hab.TipoHabitacion t ON t.IdTipoHabitacion = h.IdTipoHabitacion
            JOIN res.ReservaHabitacionNoche x ON x.IdReservaHabitacion = lin.IdReservaHabitacion
                                             AND x.Fecha >= lin.FechaDesde AND x.Fecha < lin.FechaHasta
            WHERE lin.IdReserva = @IdReserva AND lin.Estado <> 'CANCELADA'
        ), g AS (
            SELECT IdReservaHabitacion, Codigo, CodigoCabys, PersonasExtra, IdTemporada, PrecioNoche, PrecioPersonaExtra,
                   MIN(Fecha) AS Desde, DATEADD(DAY, 1, MAX(Fecha)) AS Hasta, COUNT(*) AS Noches
            FROM n
            GROUP BY IdReservaHabitacion, Codigo, CodigoCabys, PersonasExtra, IdTemporada, PrecioNoche, PrecioPersonaExtra, Tramo
        )
        INSERT @L(TipoLinea, CodigoCabys, Descripcion, Cantidad, PrecioUnitario, PorcentajeImpuesto, IdReservaHabitacion)
        SELECT z.TipoLinea, z.CodigoCabys, z.Descripcion, z.Cantidad, z.PrecioUnitario, @IVA, z.IdReservaHabitacion
        FROM (SELECT 1 AS Ord, g.IdReservaHabitacion, g.Desde, 'HOSPEDAJE' AS TipoLinea, g.CodigoCabys,
                     CONCAT('Hospedaje hab. ', g.Codigo, ISNULL(' - ' + tm.Nombre, ''), ' (', CONVERT(CHAR(10), g.Desde, 103),
                            ' - ', CONVERT(CHAR(10), g.Hasta, 103), ')') AS Descripcion,
                     CAST(g.Noches AS DECIMAL(10,2)) AS Cantidad, g.PrecioNoche AS PrecioUnitario
              FROM g LEFT JOIN hab.Temporada tm ON tm.IdTemporada = g.IdTemporada
              UNION ALL
              SELECT 2, g.IdReservaHabitacion, g.Desde, 'PERSONA_EXTRA', g.CodigoCabys,
                     CONCAT('Persona(s) extra hab. ', g.Codigo, ': ', g.PersonasExtra, ' x ', g.Noches, ' noche(s)',
                            ISNULL(' - ' + tm.Nombre, '')),
                     CAST(g.Noches * g.PersonasExtra AS DECIMAL(10,2)), g.PrecioPersonaExtra
              FROM g LEFT JOIN hab.Temporada tm ON tm.IdTemporada = g.IdTemporada
              WHERE g.PersonasExtra > 0 AND g.PrecioPersonaExtra > 0) z
        ORDER BY z.IdReservaHabitacion, z.Desde, z.Ord;

        -- Servicio a la habitación
        INSERT @L(TipoLinea, CodigoCabys, Descripcion, Cantidad, PrecioUnitario, PorcentajeImpuesto, IdPedido)
        SELECT s.TipoLinea, s.CodigoCabys, s.Descripcion, s.Cantidad, s.PrecioUnitario, s.PctImp, s.IdPedido
        FROM (SELECT p.IdPedido, 1 AS Ord, pd.IdPedidoDetalle AS Sub, 'SERVICIO_HABITACION' AS TipoLinea, pm.CodigoCabys,
                     LEFT(CONCAT('Pedido #', p.IdPedido, ': ', CAST(pm.Nombre AS VARCHAR(80))), 200) AS Descripcion,
                     CAST(pd.Cantidad AS DECIMAL(10,2)) AS Cantidad, pd.PrecioUnitario, @IVA AS PctImp
              FROM coc.Pedido p
              JOIN res.ReservaHabitacion lin ON lin.IdReservaHabitacion = p.IdReservaHabitacion
              JOIN coc.PedidoDetalle pd ON pd.IdPedido = p.IdPedido
              JOIN coc.ProductoMenu pm  ON pm.IdProducto = pd.IdProducto
              WHERE lin.IdReserva = @IdReserva AND p.Estado = 'ENTREGADO' AND p.Facturado = 0
              UNION ALL
              SELECT p.IdPedido, 2, 0, 'CARGO_SERVICIO', NULL,
                     CONCAT('Cargo por servicio ', @PctServ, '% - pedido #', p.IdPedido), 1, p.CargoServicio, 0
              FROM coc.Pedido p
              JOIN res.ReservaHabitacion lin ON lin.IdReservaHabitacion = p.IdReservaHabitacion
              WHERE lin.IdReserva = @IdReserva AND p.Estado = 'ENTREGADO' AND p.Facturado = 0 AND p.CargoServicio > 0) s
        ORDER BY s.IdPedido, s.Ord, s.Sub;

        -- Descuento por línea
        SELECT @IdDesc = d.IdDescuento, @TipoDesc = d.Tipo, @ValorDesc = d.Valor, @AplicaA = d.AplicaA, @NomDesc = d.Nombre
        FROM res.Reserva r JOIN res.Descuento d ON d.IdDescuento = r.IdDescuento WHERE r.IdReserva = @IdReserva;
        IF @IdDesc IS NOT NULL
        BEGIN
            INSERT @Eleg(Orden, Bruto)
            SELECT Orden, CAST(Cantidad * PrecioUnitario AS DECIMAL(12,2)) FROM @L
            WHERE CAST(Cantidad * PrecioUnitario AS DECIMAL(12,2)) > 0
              AND (   (TipoLinea IN ('HOSPEDAJE','PERSONA_EXTRA') AND @AplicaA IN ('HOSPEDAJE','TODO'))
                   OR (TipoLinea = 'SERVICIO_HABITACION'         AND @AplicaA IN ('SERVICIO_HABITACION','TODO')));
            IF @TipoDesc = 'PORCENTAJE'
                UPDATE l SET IdDescuento = @IdDesc, PorcentajeDescuento = @ValorDesc,
                             MontoDescuento = ROUND(e.Bruto * @ValorDesc / 100, 2), NaturalezaDescuento = @NomDesc
                FROM @L l JOIN @Eleg e ON e.Orden = l.Orden;
            ELSE
            BEGIN
                SELECT @Base = ISNULL(SUM(Bruto), 0) FROM @Eleg;
                SET @Fijo = IIF(@ValorDesc > @Base, @Base, @ValorDesc);
                IF @Base > 0
                BEGIN
                    UPDATE l SET IdDescuento = @IdDesc, MontoDescuento = ROUND(@Fijo * e.Bruto / @Base, 2), NaturalezaDescuento = @NomDesc
                    FROM @L l JOIN @Eleg e ON e.Orden = l.Orden;
                    -- el residuo del redondeo va a la línea más grande
                    UPDATE @L SET MontoDescuento = MontoDescuento + (@Fijo - (SELECT SUM(MontoDescuento) FROM @L))
                    WHERE Orden = (SELECT TOP (1) Orden FROM @Eleg ORDER BY Bruto DESC, Orden);
                    UPDATE l SET PorcentajeDescuento = ROUND(l.MontoDescuento * 100 / e.Bruto, 2)
                    FROM @L l JOIN @Eleg e ON e.Orden = l.Orden;
                END
            END
        END

        EXEC fac.sp_EmitirComprobante @IdReserva, 'ESTADIA', @L, @IdUsuario, NULL, NULL, @IdFactura OUTPUT;
        UPDATE coc.Pedido SET Facturado = 1 WHERE IdPedido IN (SELECT IdPedido FROM @L WHERE IdPedido IS NOT NULL);
        UPDATE f SET Estado = 'PAGADA' FROM fac.Factura f JOIN res.Reserva r ON r.IdReserva = f.IdReserva
        WHERE f.IdFactura = @IdFactura AND r.MontoPagado >= f.Total;

        INSERT dbo.ColaCorreo(Destinatario, Asunto, Cuerpo, Tipo, IdReferencia)
        SELECT f.ReceptorCorreo, CONCAT(IIF(f.TipoDocumento = 'FE', N'Factura electrónica ', N'Tiquete electrónico '), f.Consecutivo),
               CONCAT(N'Gracias por su estadía. Total facturado: ', FORMAT(f.Total, 'N2'), N'. Clave: ', f.Clave, N'. Puede verla en la app.'),
               'FACTURA_EMITIDA', f.IdFactura
        FROM fac.Factura f WHERE f.IdFactura = @IdFactura;
        IF @tc = 0 COMMIT;
    END TRY
    BEGIN CATCH
        IF @tc = 0 AND @@TRANCOUNT > 0 ROLLBACK;
        THROW;
    END CATCH
END
GO
-- Salida anticipada: se cobran solo las noches usadas (mínimo 1)
CREATE PROCEDURE hab.sp_CheckOut @IdReserva INT, @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC seg.sp_ExigirPermiso @IdUsuario, 'RECEPCION', 'E';
    DECLARE @Estado VARCHAR(12), @Entrada DATE, @Salida DATE, @Corte DATE, @IdCliente INT, @IdFactura INT,
            @Hoy DATE = CAST(SYSDATETIME() AS DATE);
    BEGIN TRY
        BEGIN TRAN;
        SELECT @Estado = Estado, @Entrada = FechaEntrada, @Salida = FechaSalida, @IdCliente = IdCliente
        FROM res.Reserva WITH (UPDLOCK) WHERE IdReserva = @IdReserva;
        IF @Estado IS NULL OR @Estado <> 'CHECKIN' THROW 50050, N'Solo se hace check-out de una reservación con check-in.', 1;
        IF EXISTS (SELECT 1 FROM coc.Pedido p JOIN res.ReservaHabitacion lin ON lin.IdReservaHabitacion = p.IdReservaHabitacion
                   WHERE lin.IdReserva = @IdReserva AND p.Estado NOT IN ('ENTREGADO','CANCELADO'))
            THROW 50051, N'Hay pedidos de servicio a la habitación sin entregar.', 1;

        SET @Corte = IIF(@Hoy < @Salida, @Hoy, @Salida);
        IF @Corte <= @Entrada SET @Corte = DATEADD(DAY, 1, @Entrada);
        IF @Corte < @Salida
        BEGIN
            UPDATE res.ReservaHabitacion SET Estado = 'CANCELADA' WHERE IdReserva = @IdReserva AND Estado = 'ACTIVA' AND FechaDesde >= @Corte;
            UPDATE res.ReservaHabitacion SET FechaHasta = @Corte WHERE IdReserva = @IdReserva AND Estado = 'ACTIVA' AND FechaHasta > @Corte;
            UPDATE res.Reserva SET FechaSalida = @Corte WHERE IdReserva = @IdReserva;
        END
        UPDATE res.ReservaHabitacion SET Estado = 'FINALIZADA' WHERE IdReserva = @IdReserva AND Estado = 'ACTIVA';
        EXEC res.sp_RecalcularReserva @IdReserva;
        EXEC fac.sp_GenerarFacturaEstadia @IdReserva, @IdUsuario, @IdFactura OUTPUT;

        UPDATE res.Reserva SET Estado = 'CHECKOUT', FechaModificacion = SYSDATETIME() WHERE IdReserva = @IdReserva;
        UPDATE h SET Estado = 'LIMPIEZA' FROM hab.Habitacion h
        WHERE h.Estado = 'OCUPADA' AND EXISTS (SELECT 1 FROM res.ReservaHabitacion lin
                                              WHERE lin.IdReserva = @IdReserva AND lin.IdHabitacion = h.IdHabitacion AND lin.Estado = 'FINALIZADA');
        UPDATE t SET Estado = 'EXPIRADA', FechaRevocacion = SYSDATETIME()
        FROM hab.TarjetaHabitacion t JOIN res.ReservaHabitacion lin ON lin.IdReservaHabitacion = t.IdReservaHabitacion
        WHERE lin.IdReserva = @IdReserva AND t.Estado = 'ACTIVA';
        UPDATE res.Cliente
        SET EstadiasCompletadas = EstadiasCompletadas + 1,
            EsFrecuente = IIF(EstadiasCompletadas + 1 >= dbo.fn_Param('ESTADIAS_CLIENTE_FRECUENTE'), 1, EsFrecuente)
        WHERE IdCliente = @IdCliente;
        COMMIT;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH

    SELECT f.IdFactura, f.TipoDocumento, f.Consecutivo, f.Clave, f.Subtotal, f.Descuento, f.Impuesto, f.Total, f.Estado, r.MontoPagado,
           IIF(f.Total > r.MontoPagado, f.Total - r.MontoPagado, 0) AS SaldoPorCobrar,
           IIF(r.MontoPagado > f.Total, r.MontoPagado - f.Total, 0) AS SaldoAFavorCliente
    FROM fac.Factura f JOIN res.Reserva r ON r.IdReserva = f.IdReserva WHERE f.IdFactura = @IdFactura;
END
GO
-- Anulación = nota de crédito por el total que referencia al comprobante original
CREATE PROCEDURE fac.sp_AnularFactura @IdFactura INT, @Motivo VARCHAR(180), @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC seg.sp_ExigirPermiso @IdUsuario, 'FACTURACION', 'A';
    DECLARE @IdReserva INT, @TipoFactura VARCHAR(12), @Estado VARCHAR(10), @TipoDoc VARCHAR(2), @IdNC INT;
    DECLARE @L fac.tp_LineaFactura;
    BEGIN TRY
        BEGIN TRAN;
        SELECT @IdReserva = IdReserva, @TipoFactura = TipoFactura, @Estado = Estado, @TipoDoc = TipoDocumento
        FROM fac.Factura WITH (UPDLOCK, HOLDLOCK) WHERE IdFactura = @IdFactura;
        IF @Estado IS NULL OR @Estado = 'ANULADA' THROW 50062, N'La factura no existe o ya está anulada.', 1;
        IF @TipoDoc = 'NC' THROW 50171, N'Una nota de crédito no se anula.', 1;

        INSERT @L(TipoLinea, CodigoCabys, Descripcion, Cantidad, UnidadMedida, PrecioUnitario, IdDescuento, PorcentajeDescuento,
                  MontoDescuento, NaturalezaDescuento, PorcentajeImpuesto, IdReservaHabitacion, IdPedido)
        SELECT TipoLinea, CodigoCabys, Descripcion, Cantidad, UnidadMedida, PrecioUnitario, IdDescuento, PorcentajeDescuento,
               MontoDescuento, NaturalezaDescuento, PorcentajeImpuesto, IdReservaHabitacion, IdPedido
        FROM fac.FacturaDetalle WHERE IdFactura = @IdFactura ORDER BY NumeroLinea;
        EXEC fac.sp_EmitirComprobante @IdReserva, @TipoFactura, @L, @IdUsuario, @IdFactura, @Motivo, @IdNC OUTPUT;

        UPDATE fac.Factura SET Estado = 'ANULADA', MotivoAnulacion = @Motivo, FechaAnulacion = SYSDATETIME(), AnuladaPor = @IdUsuario
        WHERE IdFactura = @IdFactura;     -- el trigger libera los pedidos y encola el correo al cliente
        COMMIT;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH
    SELECT IdFactura AS IdNotaCredito, Consecutivo, Clave, Total FROM fac.Factura WHERE IdFactura = @IdNC;
END
GO
-- Lo usa el servicio del backend que firma y envía los comprobantes a Hacienda
CREATE PROCEDURE fac.sp_RegistrarEstadoHacienda
    @IdFactura INT, @EstadoHacienda VARCHAR(10), @XmlComprobante VARBINARY(MAX) = NULL, @XmlRespuesta VARBINARY(MAX) = NULL,
    @Mensaje VARCHAR(500) = NULL, @MedioPago CHAR(2) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    UPDATE fac.Factura
    SET EstadoHacienda         = @EstadoHacienda,
        XmlComprobante         = ISNULL(@XmlComprobante, XmlComprobante),
        MedioPago              = ISNULL(@MedioPago, MedioPago),
        XmlRespuesta           = ISNULL(@XmlRespuesta, XmlRespuesta),
        MensajeHacienda        = ISNULL(@Mensaje, MensajeHacienda),
        FechaEnvioHacienda     = IIF(@EstadoHacienda = 'ENVIADA', SYSDATETIME(), FechaEnvioHacienda),
        FechaRespuestaHacienda = IIF(@EstadoHacienda IN ('ACEPTADA','RECHAZADA'), SYSDATETIME(), FechaRespuestaHacienda)
    WHERE IdFactura = @IdFactura;
    IF @@ROWCOUNT = 0 THROW 50177, N'El comprobante no existe.', 1;
END
GO

-- 17. PROCEDIMIENTOS — COCINA
-- @Items (JSON): [{"IdProducto":3,"Cantidad":2}, ...]
CREATE PROCEDURE coc.sp_CrearPedido @IdReservaHabitacion INT, @Items VARCHAR(MAX), @Notas VARCHAR(300) = NULL,
                                    @IdClienteSolicitante INT = NULL, @IdPedido INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    DECLARE @Det TABLE (IdProducto INT PRIMARY KEY, Cantidad INT NOT NULL);
    DECLARE @IdHab INT, @IdCliente INT, @EstadoRes VARCHAR(12), @EstadoLin VARCHAR(10), @MinPrep INT, @Cola INT;
    IF ISNULL(ISJSON(@Items), 0) = 0 THROW 50070, N'Detalle del pedido inválido.', 1;
    INSERT @Det(IdProducto, Cantidad)
    SELECT IdProducto, SUM(Cantidad) FROM OPENJSON(@Items) WITH (IdProducto INT, Cantidad INT)
    WHERE IdProducto IS NOT NULL GROUP BY IdProducto;
    IF NOT EXISTS (SELECT 1 FROM @Det) OR EXISTS (SELECT 1 FROM @Det WHERE Cantidad NOT BETWEEN 1 AND 50)
        THROW 50071, N'Cantidades inválidas (1 a 50 por producto).', 1;
    SELECT @IdHab = lin.IdHabitacion, @IdCliente = r.IdCliente, @EstadoRes = r.Estado, @EstadoLin = lin.Estado
    FROM res.ReservaHabitacion lin JOIN res.Reserva r ON r.IdReserva = lin.IdReserva
    WHERE lin.IdReservaHabitacion = @IdReservaHabitacion;
    IF @IdHab IS NULL OR @EstadoRes <> 'CHECKIN' OR @EstadoLin <> 'ACTIVA'
        THROW 50072, N'Solo se puede pedir servicio a la habitación durante una estadía activa.', 1;
    IF @IdClienteSolicitante IS NOT NULL AND @IdClienteSolicitante <> @IdCliente THROW 50101, N'No autorizado.', 1;
    BEGIN TRY
        BEGIN TRAN;
        -- Verificación en tiempo real: bloquea los productos para que dos pedidos no se lleven la última unidad
        IF EXISTS (SELECT 1 FROM @Det d LEFT JOIN coc.ProductoMenu p WITH (UPDLOCK, HOLDLOCK) ON p.IdProducto = d.IdProducto
                   WHERE p.IdProducto IS NULL OR p.Disponible = 0 OR (p.Stock IS NOT NULL AND p.Stock < d.Cantidad))
            THROW 50073, N'Uno o más productos no están disponibles o no hay existencias suficientes.', 1;
        SELECT @MinPrep = MAX(p.MinutosPreparacion) FROM @Det d JOIN coc.ProductoMenu p ON p.IdProducto = d.IdProducto;
        SELECT @Cola = COUNT(*) FROM coc.Pedido WHERE Estado IN ('CONFIRMADO','EN_PREPARACION');
        INSERT coc.Pedido(IdReservaHabitacion, IdHabitacion, Notas, MinPreparacionEst, MinEmpaqueEst, MinEntregaEst)
        VALUES (@IdReservaHabitacion, @IdHab, @Notas,
                @MinPrep + @Cola * CAST(dbo.fn_Param('MIN_POR_PEDIDO_EN_COLA') AS INT),
                CAST(dbo.fn_Param('MIN_EMPAQUE') AS INT), CAST(dbo.fn_Param('MIN_ENTREGA') AS INT));
        SET @IdPedido = SCOPE_IDENTITY();
        INSERT coc.PedidoDetalle(IdPedido, IdProducto, Cantidad, PrecioUnitario)
        SELECT @IdPedido, d.IdProducto, d.Cantidad, p.Precio FROM @Det d JOIN coc.ProductoMenu p ON p.IdProducto = d.IdProducto;
        COMMIT;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH
    SELECT * FROM coc.vw_SeguimientoPedido WHERE IdPedido = @IdPedido;
END
GO
-- Cocina: CONFIRMADO, EN_PREPARACION, EMPAQUETADO  |  Meseros: EN_CAMINO, ENTREGADO
CREATE PROCEDURE coc.sp_CambiarEstadoPedido @IdPedido INT, @EstadoNuevo VARCHAR(15), @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @EstadoNuevo = 'CANCELADO' THROW 50080, N'Para cancelar use coc.sp_CancelarPedido.', 1;
    DECLARE @Modulo VARCHAR(30) = IIF(@EstadoNuevo IN ('EN_CAMINO','ENTREGADO'), 'SERVICIO_HABITACION', 'COCINA'), @Actual VARCHAR(15);
    EXEC seg.sp_ExigirPermiso @IdUsuario, @Modulo, 'E';
    SELECT @Actual = Estado FROM coc.Pedido WHERE IdPedido = @IdPedido;
    IF @Actual IS NULL THROW 50081, N'El pedido no existe.', 1;
    UPDATE coc.Pedido
    SET Estado           = @EstadoNuevo,
        FechaConfirmado  = IIF(@EstadoNuevo = 'CONFIRMADO',     SYSDATETIME(), FechaConfirmado),
        FechaPreparacion = IIF(@EstadoNuevo = 'EN_PREPARACION', SYSDATETIME(), FechaPreparacion),
        FechaEmpaquetado = IIF(@EstadoNuevo = 'EMPAQUETADO',    SYSDATETIME(), FechaEmpaquetado),
        FechaEnCamino    = IIF(@EstadoNuevo = 'EN_CAMINO',      SYSDATETIME(), FechaEnCamino),
        FechaEntregado   = IIF(@EstadoNuevo = 'ENTREGADO',      SYSDATETIME(), FechaEntregado),
        IdUsuarioCocina  = IIF(@Modulo = 'COCINA', @IdUsuario, IdUsuarioCocina),
        IdUsuarioEntrega = IIF(@Modulo = 'SERVICIO_HABITACION', @IdUsuario, IdUsuarioEntrega)
    WHERE IdPedido = @IdPedido AND Estado = @Actual;          -- concurrencia: si otro lo cambió, no se pisa
    IF @@ROWCOUNT = 0 THROW 50082, N'Otro usuario cambió el pedido al mismo tiempo. Actualice la pantalla.', 1;
    SELECT * FROM coc.vw_SeguimientoPedido WHERE IdPedido = @IdPedido;
END
GO
CREATE PROCEDURE coc.sp_CancelarPedido @IdPedido INT, @Motivo VARCHAR(200), @IdClienteSolicitante INT = NULL, @IdUsuario INT = NULL
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF @IdClienteSolicitante IS NULL EXEC seg.sp_ExigirPermiso @IdUsuario, 'COCINA', 'A';
    DECLARE @Estado VARCHAR(15), @IdCliente INT;
    BEGIN TRY
        BEGIN TRAN;
        SELECT @Estado = p.Estado, @IdCliente = r.IdCliente
        FROM coc.Pedido p WITH (UPDLOCK, HOLDLOCK)
        JOIN res.ReservaHabitacion lin ON lin.IdReservaHabitacion = p.IdReservaHabitacion
        JOIN res.Reserva r ON r.IdReserva = lin.IdReserva
        WHERE p.IdPedido = @IdPedido;
        IF @Estado IS NULL THROW 50081, N'El pedido no existe.', 1;
        IF @IdClienteSolicitante IS NOT NULL AND @IdClienteSolicitante <> @IdCliente THROW 50101, N'No autorizado.', 1;
        IF @Estado NOT IN ('PENDIENTE','CONFIRMADO')
            THROW 50083, N'El pedido ya está en preparación: la cancelación está bloqueada.', 1;
        UPDATE coc.Pedido SET Estado = 'CANCELADO', FechaCancelado = SYSDATETIME(), MotivoCancelacion = @Motivo
        WHERE IdPedido = @IdPedido;
        COMMIT;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH
END
GO

-- 18. PROCEDIMIENTOS — EMPLEADOS Y PLANILLA

/* Registra al empleado sobre su Persona (si ya era cliente, se reutiliza la misma persona).
   Arranque: mientras no exista un ADMIN activo se permite registrar al primer empleado (el administrador). */
CREATE PROCEDURE rh.sp_RegistrarEmpleado
    @TipoIdentificacion VARCHAR(15), @Identificacion VARCHAR(30), @Nombre VARCHAR(60), @Apellidos VARCHAR(100),
    @Correo VARCHAR(150), @Telefono VARCHAR(20) = NULL, @IdPuesto INT, @TipoSalario VARCHAR(10), @MontoSalario DECIMAL(12,2),
    @CuentaIBAN VARCHAR(22) = NULL, @FechaIngreso DATE, @IdUsuarioAdmin INT = NULL, @IdEmpleado INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    IF EXISTS (SELECT 1 FROM seg.UsuarioRol ur JOIN seg.Rol r ON r.IdRol = ur.IdRol
               JOIN seg.Usuario u ON u.IdUsuario = ur.IdUsuario WHERE r.Codigo = 'ADMIN' AND u.Activo = 1)
        EXEC seg.sp_ExigirPermiso @IdUsuarioAdmin, 'PLANILLA', 'C';
    BEGIN TRY
        BEGIN TRAN;
        EXEC dbo.sp_ObtenerOCrearPersona @TipoIdentificacion, @Identificacion, @Nombre, @Apellidos, @Correo, @Telefono,
             @IdPersona = @IdEmpleado OUTPUT;
        IF EXISTS (SELECT 1 FROM rh.Empleado WHERE IdEmpleado = @IdEmpleado)
            THROW 50182, N'La persona ya está registrada como empleado.', 1;
        INSERT rh.Empleado(IdEmpleado, IdPuesto, TipoSalario, MontoSalario, CuentaIBAN, FechaIngreso)
        VALUES (@IdEmpleado, @IdPuesto, @TipoSalario, @MontoSalario, @CuentaIBAN, @FechaIngreso);
        COMMIT;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH
END
GO
CREATE PROCEDURE rh.sp_GenerarPlanilla @TipoPeriodo VARCHAR(10), @FechaInicio DATE, @FechaFin DATE, @FechaPago DATE,
                                       @IdUsuario INT, @IdPlanilla INT OUTPUT
AS
BEGIN
    SET NOCOUNT ON; SET XACT_ABORT ON;
    EXEC seg.sp_ExigirPermiso @IdUsuario, 'PLANILLA', 'C';
    IF (@TipoPeriodo = 'QUINCENAL' AND DATEDIFF(DAY, @FechaInicio, @FechaFin) NOT BETWEEN 12 AND 16)
    OR (@TipoPeriodo = 'MENSUAL'   AND DATEDIFF(DAY, @FechaInicio, @FechaFin) NOT BETWEEN 27 AND 31)
        THROW 50125, N'El rango de fechas no corresponde al tipo de periodo.', 1;
    DECLARE @PctCCSS DECIMAL(5,2) = dbo.fn_Param('PCT_CCSS_OBRERO'),
            @Factor  DECIMAL(5,2) = IIF(@TipoPeriodo = 'QUINCENAL', 0.5, 1),
            @FactorExtra DECIMAL(5,2) = dbo.fn_Param('FACTOR_HORA_EXTRA'),
            @HorasMes    DECIMAL(6,2) = dbo.fn_Param('HORAS_MES_SALARIO');
    IF ISNULL(@HorasMes, 0) <= 0 OR ISNULL(@FactorExtra, 0) <= 0
        THROW 50129, N'Revise los parámetros HORAS_MES_SALARIO y FACTOR_HORA_EXTRA: deben ser mayores que cero.', 1;
    BEGIN TRY
        BEGIN TRAN;
        INSERT rh.Planilla(TipoPeriodo, FechaInicio, FechaFin, FechaPago, CreadaPor)
        VALUES (@TipoPeriodo, @FechaInicio, @FechaFin, @FechaPago, @IdUsuario);
        SET @IdPlanilla = SCOPE_IDENTITY();
        -- Mensual: salario × factor del periodo | Por hora: horas aprobadas × tarifa
        -- Extras: FACTOR_HORA_EXTRA × valor de la hora (hora mensual = salario / HORAS_MES_SALARIO)
        INSERT rh.PlanillaDetalle(IdPlanilla, IdEmpleado, SalarioBase, HorasOrdinarias, HorasExtra, MontoHorasExtra, PorcentajeCCSS)
        SELECT @IdPlanilla, e.IdEmpleado,
               CAST(IIF(e.TipoSalario = 'MENSUAL', e.MontoSalario * @Factor, ISNULL(hh.Ord, 0) * e.MontoSalario) AS DECIMAL(12,2)),
               ISNULL(hh.Ord, 0), ISNULL(hh.Ext, 0),
               CAST(ROUND(ISNULL(hh.Ext, 0) * IIF(e.TipoSalario = 'MENSUAL', e.MontoSalario / @HorasMes, e.MontoSalario) * @FactorExtra, 2) AS DECIMAL(12,2)),
               @PctCCSS
        FROM rh.Empleado e
        OUTER APPLY (SELECT SUM(r.HorasOrdinarias) AS Ord, SUM(r.HorasExtra) AS Ext FROM rh.RegistroHoras r
                     WHERE r.IdEmpleado = e.IdEmpleado AND r.Aprobado = 1 AND r.Fecha BETWEEN @FechaInicio AND @FechaFin) hh
        WHERE e.Activo = 1 AND e.FechaIngreso <= @FechaFin AND (e.FechaSalida IS NULL OR e.FechaSalida >= @FechaInicio);
        COMMIT;
    END TRY
    BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH
    SELECT pd.IdPlanillaDetalle, CONCAT(pe.Nombre, ' ', pe.Apellidos) AS Empleado, pu.Nombre AS Puesto,
           pd.SalarioBase, pd.MontoHorasExtra, pd.Bonificaciones, pd.SalarioBruto, pd.DeduccionCCSS, pd.ImpuestoRenta, pd.SalarioNeto
    FROM rh.PlanillaDetalle pd
    JOIN rh.Empleado e    ON e.IdEmpleado = pd.IdEmpleado
    JOIN dbo.Persona pe   ON pe.IdPersona = e.IdEmpleado
    JOIN rh.Puesto pu     ON pu.IdPuesto = e.IdPuesto
    WHERE pd.IdPlanilla = @IdPlanilla;
END
GO
CREATE PROCEDURE rh.sp_AprobarPlanilla @IdPlanilla INT, @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC seg.sp_ExigirPermiso @IdUsuario, 'PLANILLA', 'A';
    IF EXISTS (SELECT 1 FROM rh.Planilla WHERE IdPlanilla = @IdPlanilla AND CreadaPor = @IdUsuario)
        THROW 50126, N'Quien genera la planilla no puede aprobarla.', 1;
    UPDATE rh.Planilla SET Estado = 'APROBADA', AprobadaPor = @IdUsuario, FechaAprobacion = SYSDATETIME()
    WHERE IdPlanilla = @IdPlanilla AND Estado = 'BORRADOR';
    IF @@ROWCOUNT = 0 THROW 50127, N'La planilla no existe o no está en borrador.', 1;
END
GO
CREATE PROCEDURE rh.sp_PagarPlanilla @IdPlanilla INT, @IdUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    EXEC seg.sp_ExigirPermiso @IdUsuario, 'PLANILLA', 'E';
    UPDATE rh.Planilla SET Estado = 'PAGADA' WHERE IdPlanilla = @IdPlanilla AND Estado = 'APROBADA';
    IF @@ROWCOUNT = 0 THROW 50128, N'La planilla debe estar APROBADA para pagarse.', 1;
END
GO


-- 19. DATOS INICIALES

INSERT dbo.Parametro(Clave, Valor, Descripcion) VALUES
-- Reservas
('MIN_NOCHES_RESERVA',               1,    'Estadía mínima en noches'),
('DIAS_MAX_ANTICIPACION_RESERVA',  365,    'Con cuántos días de anticipación como máximo se puede reservar'),
('MIN_EXPIRA_PENDIENTE',            30,    'Minutos para pagar el anticipo antes de liberar la habitación'),
('SEG_ESPERA_DISPONIBILIDAD',       15,    'Segundos que una reserva espera a que termine otra simultánea antes de rechazarse'),
('HORA_CHECKIN',                    15,    'Hora de check-in (base del cálculo de cancelación)'),
('HORA_CHECKOUT',                   12,    'Hora de check-out (vencimiento de tarjetas)'),
('ESTADIAS_CLIENTE_FRECUENTE',       5,    'Estadías completadas para ser cliente frecuente'),
('PCT_DESC_PENALIZACION_FRECUENTE', 50,    '% de rebaja sobre la penalización por cancelar (cliente frecuente)'),
('PCT_PENALIZACION_NO_SHOW',       100,    '% de lo pagado que se retiene si el cliente no se presenta'),
-- Anticipo y abonos
('PCT_ANTICIPO',                    30,    '% del total que se cobra como anticipo para confirmar (primer abono)'),
('CANTIDAD_MAX_ABONOS',              3,    'Cantidad máxima de cuotas del plan de abonos (incluye el anticipo)'),
('PCT_ABONO_MINIMO',                20,    '% mínimo del total que debe tener cada abono (salvo el que cancela el saldo)'),
('DIAS_MIN_ENTRE_ABONOS',            1,    'Días mínimos de separación entre cuotas del plan de abonos'),
('DIAS_LIMITE_SALDO',                3,    'Días antes del check-in en que el saldo debe estar pagado'),
-- Impuestos y cargos
('PCT_IVA',                         13,    'IVA'),
('PCT_SERVICIO',                    10,    'Cargo por servicio en alimentos'),
-- Seguridad
('MAX_INTENTOS_LOGIN',               5,    'Intentos fallidos antes de bloquear la cuenta (app y web)'),
('MIN_BLOQUEO_LOGIN',               15,    'Minutos de bloqueo de la cuenta'),
('MAX_INTENTOS_IP',                 20,    'Intentos fallidos desde una misma IP que la marcan como bloqueada (fuerza bruta)'),
('MIN_VENTANA_INTENTOS_IP',         10,    'Minutos hacia atrás en que se cuentan los intentos fallidos por IP'),
('DIAS_VIGENCIA_REFRESH_TOKEN',      7,    'Días de vigencia de una sesión (refresh token)'),
-- Cocina
('MIN_EMPAQUE',                      5,    'Minutos estimados de empaquetado'),
('MIN_ENTREGA',                     10,    'Minutos estimados de entrega a la habitación'),
('MIN_POR_PEDIDO_EN_COLA',           3,    'Minutos extra por cada pedido que la cocina tiene en curso'),
-- Planilla
('PCT_CCSS_OBRERO',              10.67,    'Cuota obrera CCSS (verificar el porcentaje vigente)'),
('FACTOR_HORA_EXTRA',              1.5,    'Multiplicador del valor de la hora extra'),
('HORAS_MES_SALARIO',              240,    'Horas del mes para sacar el valor de la hora de un salario mensual'),
-- Factura electrónica: VALORES DE EJEMPLO, reemplazar por los datos reales del hotel inscritos en Hacienda
('FE_IDENTIFICACION_EMISOR', 3101000000,   'Cédula jurídica del hotel (emisor de los comprobantes)'),
('FE_CODIGO_ACTIVIDAD',         551001,    'Código de actividad económica del hotel ante Hacienda'),
('FE_SUCURSAL',                      1,    'Número de sucursal para el consecutivo'),
('FE_TERMINAL',                      1,    'Número de terminal / punto de venta para el consecutivo');

INSERT dbo.TransicionEstado(Entidad, EstadoOrigen, EstadoDestino) VALUES
('RESERVA','PENDIENTE','CONFIRMADA'), ('RESERVA','PENDIENTE','CANCELADA'), ('RESERVA','PENDIENTE','EXPIRADA'),
('RESERVA','CONFIRMADA','CHECKIN'),   ('RESERVA','CONFIRMADA','CANCELADA'), ('RESERVA','CONFIRMADA','NO_SHOW'),
('RESERVA','CHECKIN','CHECKOUT'),
('PEDIDO','PENDIENTE','CONFIRMADO'),  ('PEDIDO','PENDIENTE','CANCELADO'),
('PEDIDO','CONFIRMADO','EN_PREPARACION'), ('PEDIDO','CONFIRMADO','CANCELADO'),
('PEDIDO','EN_PREPARACION','EMPAQUETADO'), ('PEDIDO','EMPAQUETADO','EN_CAMINO'), ('PEDIDO','EN_CAMINO','ENTREGADO'),
('FACTURA','EMITIDA','PAGADA'), ('FACTURA','EMITIDA','ANULADA'), ('FACTURA','PAGADA','ANULADA'),
('HACIENDA','PENDIENTE','ENVIADA'), ('HACIENDA','ENVIADA','ACEPTADA'), ('HACIENDA','ENVIADA','RECHAZADA'),
('PLANILLA','BORRADOR','APROBADA'), ('PLANILLA','BORRADOR','ANULADA'),
('PLANILLA','APROBADA','PAGADA'),   ('PLANILLA','APROBADA','ANULADA');

-- Módulos de la web de administración
INSERT seg.Modulo(Codigo, Nombre) VALUES
('SEGURIDAD', 'Usuarios y permisos'), ('RESERVAS', 'Reservaciones'), ('RECEPCION', 'Recepción / Check-in'),
('HABITACIONES', 'Habitaciones'), ('COCINA', 'Cocina'), ('SERVICIO_HABITACION', 'Servicio a la habitación'),
('FACTURACION', 'Facturación'), ('PLANILLA', 'Planilla'), ('REPORTES', 'Reportes');

INSERT seg.Rol(Codigo, Nombre, Ambito) VALUES
('ADMIN', 'Administrador', 'SISTEMA'), ('RECEPCIONISTA', 'Recepcionista', 'SISTEMA'), ('COCINERO', 'Cocinero', 'SISTEMA'),
('MESERO', 'Mesero', 'SISTEMA'), ('CONTADOR', 'Contador', 'SISTEMA'), ('CLIENTE', 'Cliente (app)', 'APP');

INSERT seg.RolModulo(IdRol, IdModulo, PuedeVer, PuedeCrear, PuedeEditar, PuedeAnular)
SELECT r.IdRol, m.IdModulo, 1, 1, 1, 1 FROM seg.Rol r CROSS JOIN seg.Modulo m WHERE r.Codigo = 'ADMIN'
UNION ALL
SELECT r.IdRol, m.IdModulo, v.Ver, v.Crear, v.Editar, v.Anular
FROM (VALUES ('RECEPCIONISTA','RESERVAS',1,1,1,1), ('RECEPCIONISTA','RECEPCION',1,1,1,0),
             ('RECEPCIONISTA','HABITACIONES',1,0,1,0), ('RECEPCIONISTA','FACTURACION',1,1,0,0),
             ('COCINERO','COCINA',1,1,1,1),
             ('MESERO','SERVICIO_HABITACION',1,0,1,0),
             ('CONTADOR','FACTURACION',1,1,1,1), ('CONTADOR','PLANILLA',1,1,1,1), ('CONTADOR','REPORTES',1,0,0,0)
     ) v(Rol, Modulo, Ver, Crear, Editar, Anular)
JOIN seg.Rol r ON r.Codigo = v.Rol
JOIN seg.Modulo m ON m.Codigo = v.Modulo;

-- Infraestructura: 4 edificios × 6 pisos × 10 habitaciones = 240
INSERT hab.Edificio(Numero, Codigo, Nombre) VALUES (1,'A','Edificio A'), (2,'B','Edificio B'), (3,'C','Edificio C'), (4,'D','Edificio D');
INSERT hab.Piso(IdEdificio, Numero)
SELECT e.IdEdificio, p.n FROM hab.Edificio e CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6)) p(n);

INSERT hab.TipoHabitacion(Nombre, CapacidadBase, CapacidadMaxima, CantidadCamas, TipoCama, MetrosCuadrados,
                          PrecioNoche, PrecioPersonaExtra, Descripcion) VALUES
(N'Sencilla', 1, 2, 1, 'INDIVIDUAL', 18,  35000, 10000, N'Cama individual'),
(N'Doble',    2, 3, 1, 'QUEEN',      24,  55000, 12000, N'Cama queen o dos individuales'),
(N'Familiar', 2, 4, 2, 'QUEEN',      32,  75000, 12000, N'Dos camas queen'),
(N'Suite',    2, 4, 1, 'KING',       45, 120000, 15000, N'Sala y jacuzzi');

INSERT hab.Habitacion(IdPiso, NumeroEnPiso, Codigo, IdTipoHabitacion)
SELECT pi.IdPiso, n.n, CONCAT(e.Codigo, '-', pi.Numero, RIGHT(CONCAT('0', n.n), 2)), t.IdTipoHabitacion
FROM hab.Piso pi
JOIN hab.Edificio e ON e.IdEdificio = pi.IdEdificio
CROSS JOIN (VALUES (1),(2),(3),(4),(5),(6),(7),(8),(9),(10)) n(n)
JOIN hab.TipoHabitacion t ON t.Nombre = CASE WHEN pi.Numero <= 2 THEN N'Sencilla' WHEN pi.Numero <= 4 THEN N'Doble'
                                             WHEN pi.Numero = 5 THEN N'Familiar' ELSE N'Suite' END;

INSERT hab.Amenidad(Codigo, Nombre) VALUES
('WIFI', N'Wi-Fi'), ('AIRE_ACONDICIONADO', N'Aire acondicionado'), ('TV', N'Televisión'), ('CAJA_FUERTE', N'Caja fuerte'),
('MINIBAR', N'Minibar'), ('CAFETERA', N'Cafetera'), ('JACUZZI', N'Jacuzzi'), ('BALCON', N'Balcón'), ('SALA', N'Sala de estar');

INSERT hab.TipoHabitacionAmenidad(IdTipoHabitacion, IdAmenidad)
SELECT t.IdTipoHabitacion, a.IdAmenidad
FROM (VALUES (N'Sencilla','WIFI'), (N'Sencilla','AIRE_ACONDICIONADO'), (N'Sencilla','TV'),
             (N'Doble','WIFI'), (N'Doble','AIRE_ACONDICIONADO'), (N'Doble','TV'), (N'Doble','CAJA_FUERTE'),
             (N'Familiar','WIFI'), (N'Familiar','AIRE_ACONDICIONADO'), (N'Familiar','TV'), (N'Familiar','CAJA_FUERTE'), (N'Familiar','MINIBAR'),
             (N'Suite','WIFI'), (N'Suite','AIRE_ACONDICIONADO'), (N'Suite','TV'), (N'Suite','CAJA_FUERTE'), (N'Suite','MINIBAR'),
             (N'Suite','CAFETERA'), (N'Suite','JACUZZI'), (N'Suite','BALCON'), (N'Suite','SALA')) v(Tipo, Amenidad)
JOIN hab.TipoHabitacion t ON t.Nombre = v.Tipo
JOIN hab.Amenidad a       ON a.Codigo = v.Amenidad;

-- Temporadas de ejemplo (ajustar al calendario real del hotel)
INSERT hab.Temporada(Nombre, Tipo, FechaInicio, FechaFin, PorcentajeAjuste) VALUES
('Fin y principio de año 2026-2027', 'ALTA', '2026-12-15', '2027-01-15',  25),
('Semana Santa 2027',                'ALTA', '2027-03-21', '2027-03-28',  20),
('Temporada lluviosa 2027',          'BAJA', '2027-09-01', '2027-10-31', -15);

INSERT res.Descuento(Codigo, Nombre, Clase, Tipo, Valor, AplicaA, IdTemporada, MinNoches, UsosMaximos)
SELECT NULL, 'Cliente frecuente', 'CLIENTE_FRECUENTE', 'PORCENTAJE', 10, 'HOSPEDAJE', NULL, NULL, NULL
UNION ALL
SELECT 'LLUVIOSA3', 'Promoción temporada lluviosa (3+ noches)', 'PROMOCION', 'PORCENTAJE', 10, 'TODO', t.IdTemporada, 3, 100
FROM hab.Temporada t WHERE t.Nombre = 'Temporada lluviosa 2027';

INSERT fac.ConsecutivoDocumento(TipoDocumento, Ultimo) VALUES ('FE', 0), ('TE', 0), ('NC', 0);

INSERT res.PoliticaCancelacion(Nombre, HorasMinimas, PorcentajePenalizacion) VALUES
('72 horas o más antes',     72,   0),
('Entre 24 y 72 horas antes', 24,  50),
('Menos de 24 horas',          0, 100);

INSERT coc.CategoriaMenu(Nombre) VALUES (N'Desayunos'), (N'Platos fuertes'), (N'Bebidas'), (N'Postres');
INSERT coc.ProductoMenu(IdCategoria, Nombre, Precio, MinutosPreparacion, Stock)
SELECT c.IdCategoria, v.Nombre, v.Precio, v.Minutos, v.Stock
FROM (VALUES (N'Desayunos', N'Gallo pinto completo', 4500, 15, NULL),
             (N'Desayunos', N'Panqueques con frutas', 4000, 12, NULL),
             (N'Platos fuertes', N'Casado de pollo', 6500, 20, NULL),
             (N'Platos fuertes', N'Filete de res', 12500, 25, 30),
             (N'Bebidas', N'Jugo natural', 1800, 5, NULL),
             (N'Postres', N'Tres leches', 2800, 3, 20)) v(Categoria, Nombre, Precio, Minutos, Stock)
JOIN coc.CategoriaMenu c ON c.Nombre = v.Categoria;

INSERT rh.Puesto(Nombre, IdRol)
SELECT v.Nombre, r.IdRol
FROM (VALUES ('Administrador','ADMIN'), ('Recepcionista','RECEPCIONISTA'), ('Cocinero','COCINERO'),
             ('Mesero','MESERO'), ('Contador','CONTADOR'), ('Camarista',NULL), ('Mantenimiento',NULL)) v(Nombre, Rol)
LEFT JOIN seg.Rol r ON r.Codigo = v.Rol;
GO
/* Arranque del sistema (ejecutar desde el backend con el hash real):
   DECLARE @Id INT;
   EXEC rh.sp_RegistrarEmpleado 'CEDULA', '101110111', 'Nombre', 'Apellidos', 'admin@hotel.com', NULL,
        @IdPuesto = 1, @TipoSalario = 'MENSUAL', @MontoSalario = 1000000, @FechaIngreso = '2026-01-01', @IdEmpleado = @Id OUTPUT;
   EXEC seg.sp_CrearUsuario @IdPersona = @Id, @NombreUsuario = 'admin', @PasswordHash = '<hash BCrypt>',
        @CodigoRol = 'ADMIN', @IdUsuario = @Id OUTPUT;                                                            */


-- 20. SEGURIDAD DE LA BASE: el API NO toca tablas críticas directamente

CREATE ROLE rol_api;
GO
-- Escrituras críticas SOLO por procedimientos (que validan permisos y reglas)
GRANT EXECUTE ON SCHEMA::seg TO rol_api;
GRANT EXECUTE ON SCHEMA::res TO rol_api;
GRANT EXECUTE ON SCHEMA::hab TO rol_api;
GRANT EXECUTE ON SCHEMA::coc TO rol_api;
GRANT EXECUTE ON SCHEMA::fac TO rol_api;
GRANT EXECUTE ON SCHEMA::rh  TO rol_api;
GRANT EXECUTE ON dbo.fn_Param TO rol_api;
-- Procedimientos internos: solo los llaman otros procedimientos (el encadenamiento de propiedad los sigue permitiendo)
DENY EXECUTE ON res.sp_RecalcularReserva    TO rol_api;
DENY EXECUTE ON res.sp_GenerarNoches        TO rol_api;
DENY EXECUTE ON res.sp_GenerarPlanAbonos    TO rol_api;
DENY EXECUTE ON res.sp_BloquearDisponibilidad TO rol_api;
DENY EXECUTE ON fac.sp_ReservarNumeracion   TO rol_api;
DENY EXECUTE ON fac.sp_EmitirComprobante    TO rol_api;
DENY EXECUTE ON fac.sp_FacturarPenalizacion TO rol_api;
-- Lectura para consultas y pantallas
GRANT SELECT ON SCHEMA::res TO rol_api;
GRANT SELECT ON SCHEMA::hab TO rol_api;
GRANT SELECT ON SCHEMA::coc TO rol_api;
GRANT SELECT ON SCHEMA::fac TO rol_api;
GRANT SELECT ON SCHEMA::rh  TO rol_api;
GRANT SELECT ON dbo.Persona   TO rol_api;
GRANT SELECT ON dbo.Parametro TO rol_api;
GRANT SELECT, UPDATE ON dbo.ColaCorreo TO rol_api;          -- el servicio de correo marca ENVIADO/ERROR
-- CRUD directo solo en catálogos y datos de contacto
GRANT UPDATE ON dbo.Persona (Nombre, Apellidos, Correo, Telefono) TO rol_api;
GRANT UPDATE ON res.Cliente (Activo)          TO rol_api;
GRANT INSERT, UPDATE ON res.Huesped           TO rol_api;
GRANT INSERT, UPDATE ON res.Descuento         TO rol_api;
GRANT INSERT, UPDATE ON hab.TipoHabitacion    TO rol_api;
GRANT INSERT, UPDATE ON hab.Amenidad          TO rol_api;
GRANT INSERT, UPDATE ON hab.Temporada         TO rol_api;
GRANT INSERT, UPDATE ON hab.BloqueoHabitacion TO rol_api;
GRANT INSERT, UPDATE ON coc.CategoriaMenu     TO rol_api;
GRANT INSERT, UPDATE ON coc.ProductoMenu      TO rol_api;
GRANT INSERT, UPDATE ON rh.Puesto             TO rol_api;
GRANT UPDATE ON rh.Empleado (IdPuesto, TipoSalario, MontoSalario, CuentaIBAN, FechaSalida, Activo) TO rol_api;
GRANT INSERT, UPDATE ON rh.RegistroHoras      TO rol_api;
GRANT UPDATE ON rh.PlanillaDetalle (Bonificaciones, ImpuestoRenta, OtrasDeducciones) TO rol_api;
-- Prohibiciones explícitas
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::seg TO rol_api;   -- usuarios/hash/tokens solo vía procedimientos
DENY SELECT, INSERT, UPDATE, DELETE ON SCHEMA::aud TO rol_api;   -- la bitácora no la toca el API
DENY DELETE ON SCHEMA::res TO rol_api;
DENY DELETE ON SCHEMA::hab TO rol_api;
DENY DELETE ON SCHEMA::coc TO rol_api;
DENY DELETE ON SCHEMA::fac TO rol_api;
DENY DELETE ON SCHEMA::rh  TO rol_api;
DENY DELETE ON dbo.Persona TO rol_api;
DENY VIEW DEFINITION TO rol_api;                                 -- no puede leer el código de procedimientos/triggers
GO
/* Se va ejecutar UNA sola vez. La contraseña sale de un gestor de secretos o variable de entorno,
   NUNCA de un .txt, del repositorio ni del appsettings.json subido a Git:

CREATE LOGIN hotel_api WITH PASSWORD = N'<<CONTRASEÑA_LARGA_ALEATORIA>>', CHECK_POLICY = ON, DEFAULT_DATABASE = HotelDB;
CREATE USER hotel_api FOR LOGIN hotel_api;
ALTER ROLE rol_api ADD MEMBER hotel_api;
*/
