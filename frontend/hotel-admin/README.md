# Sistema de Gestión Hotelera — segundo avance web — Angular + Ionic

Interfaz administrativa Angular 22.2.3 con componentes standalone, rutas diferidas,
TypeScript estricto, SCSS e Ionic Angular 9.0.14. No se comunica con servicios externos.

Ionic se configura con `provideIonicAngular` en `app.config.ts`, envuelve la aplicación
con `IonApp` y se utiliza mediante `IonAvatar` y `IonButton`. En Ionic 9 los componentes
standalone se importan desde `@ionic/angular`. Solo se incorpora `core.css`; se conserva
la tipografía, los colores, el layout y el desplazamiento del documento web. No se
añaden normalizaciones, utilidades ni paletas de modo oscuro que alteren el diseño.

La dependencia directa nueva es `@ionic/angular@9.0.14`; npm resuelve sus dependencias
transitivas, incluidos `@ionic/core` e `ionicons`. No se incorpora Capacitor ni Zone.js.
Los peerDependencies instalados admiten Angular >=18 y RxJS >=7.5; el proyecto conserva
Angular 22.2.3 y RxJS 7.8.2. `zone.js` está declarado como peer opcional por Ionic.

## Ejecutar

Requisito: Node.js compatible con Angular 22 (ver `engines` en package.json).
Verificado con Node 24.21.0 y npm 11.19.0.

```powershell
cd C:\Users\jafet\Documents\GitHub\SISTEMA-DE-RESERVACIONES-Y-GESTION-HOTELERA\frontend\hotel-admin
npm.cmd ci
npm.cmd start
```

Abrir http://localhost:4200. Para detener el servidor, presionar Ctrl+C.

```powershell
npm.cmd run build
npm.cmd run typecheck
npm.cmd test
```

La compilación web queda en `dist/hotel-admin/browser`. En un alojamiento futuro,
las rutas deben devolver index.html cuando se accede directamente a una URL interna.

## Demostración

| Usuario | Nombre | Rol | Acceso visual |
| --- | --- | --- | --- |
| jefe | Carlos | Jefe general | Los 25 módulos |
| administrador | Andrea | Administrador | Los 25 módulos |
| cocinero | Pepito | Cocinero | Dashboard, perfil, notificaciones, restaurante, cocina y servicio a la habitación |

Introducir cualquier contraseña de prueba no vacía. **No introducir contraseñas reales.**
La contraseña no se valida ni almacena. La sesión solo vive en memoria: al recargar,
se vuelve al login. Cerrar sesión borra el usuario y redirige al login.
Esta simulación no proporciona autenticación ni autorización de producción.

El saludo aparece únicamente en el dashboard, según la hora local del dispositivo.
Se actualiza cada segundo y libera su temporizador al abandonar el componente.
Junto al saludo se muestra el avatar del usuario actual. `UserAvatarComponent` recibe
identificador, nombre y URL opcional: usa iniciales si no hay foto o si falla la imagen.
No se asignan fotografías de personas a los usuarios de demostración.
El dashboard del jefe conserva la frase solicitada y cuatro botones deshabilitados.
Los demás módulos muestran únicamente su título; Habitaciones tiene su vista propia.

## Habitaciones

La página tiene filtros de edificio, piso, tipo y estado. Los tipos Sencilla, Doble,
Familiar y Suite proceden del catálogo inicial del SQL existente. Los estados usan
los códigos del CHECK `CK_Habitacion_Estado`. Estos catálogos se inspeccionaron en modo
de lectura; no se realizó ninguna conexión a SQL Server.

Los filtros guardan selecciones locales tipadas. No ejecutan búsquedas ni alteran las
tarjetas de muestra: la página indica expresamente que es una vista de diseño sin
datos reales ni consulta de disponibilidad. Las tres tarjetas no son habitaciones.

`RoomCardComponent` recibe opcionalmente un `RoomCardData`: código, tipo, ubicación,
capacidad, precio y moneda, estado y URL de imagen. Sin datos presenta etiquetas
neutras y guiones, sin inventar precios ni estados. Las fotografías mantienen una
proporción 4:3 y `object-fit: cover`; si faltan o fallan se muestra el marcador neutro.
El botón Ionic «Ver detalles» permanece deshabilitado en ambos casos.

La cuadrícula usa consultas al contenedor para calcular las columnas según el espacio
real que deja el menú: una en móvil, dos en tablet y tres o cuatro en escritorio.
No se implementa carga de fotos, detalle, CRUD ni disponibilidad.

## Estructura

```text
src/
  app/
    core/
      models/          # Usuario y múltiples roles
      navigation/      # Catálogo de los 25 módulos y acceso visual
      session/         # Contrato de sesión, proveedor demo y guards
    features/
      login/
      dashboard/
      module-page/     # Título de los módulos sin funcionalidad
      rooms/
        models/
        room-card/
        room-filters/
    layout/
      header/
      sidebar/
      shell/
    shared/
      greeting/        # Componente y reglas del saludo
      icon/            # SVG propios
      user-avatar/     # IonAvatar, fotografía o iniciales
    app.component.*
    app.config.ts
    app.routes.ts
    app.spec.ts
  index.html
  main.ts
  styles.scss
```

Cada componente visual tiene HTML y SCSS separados. El componente raíz
contiene IonApp y el outlet de Angular Router, sin estilos propios. Las páginas sin funcionalidad
comparten componente por diseño; cada módulo conserva su ruta y título independientes.

## Integración posterior

`SESSION_GATEWAY` separa la UI del proveedor temporal `DemoSessionService`.
Su contrato asíncrono permite sustituir el proveedor por un servicio HTTP que adapte
las respuestas reales de ASP.NET Core a `SessionUser`. Los roles se representan como
una colección para admitir empleados con varias funciones.

No se han inventado endpoints ni contratos HTTP. Al integrar el backend habrá que
acordar sus DTO, permisos y gestión de tokens, registrar HttpClient e interceptores
y sustituir los guards demostrativos. Los guards del cliente solo orientan la
navegación: la autorización deberá validarse en el servidor, como indica la
[documentación de Angular](https://angular.dev/guide/routing/route-guards).

Se revisaron las rutas diferidas, separación de componentes, servicios y guard de
Tetris como referencia técnica. No se copiaron su lógica, estética, dependencias
móviles, transporte HTTP ni integración SignalR.

El backend .NET 10, la solución y el SQL existentes no se modifican. No se generan
APK/AAB ni se ejecutan operaciones de escritura de Git.


## Verificaciones del segundo avance

`npm.cmd run build`, `npm.cmd run typecheck` y `npm.cmd test`.
La suite cuenta con 25 pruebas en cuatro archivos. Se actualizaron las expectativas
del primer avance para comprobar el saludo exclusivo del dashboard, las 25 rutas,
los tres usuarios y el cierre de sesión. Se añadieron pruebas de avatar, imágenes
fallidas, catálogos, selecciones tipadas y presentación de tarjetas sin datos ficticios.
Consultar `ENTREGA.md` para el inventario del segundo avance y sus verificaciones.
