# Segundo avance — Angular + Ionic

Se conserva la aplicación existente, su identidad visual, el login temporal,
el menú por roles y las 25 rutas. El saludo solo aparece en el dashboard, con
avatar reutilizable obtenido del usuario actual. Habitaciones incorpora filtros,
modelos tipados y tarjetas de diseño neutras. Los demás módulos muestran su título.

## Dependencias

- Nueva dependencia directa: `@ionic/angular` 9.0.14.
- `@ionic/core` 9.0.14 y las demás dependencias de Ionic se resuelven en package-lock.
- Angular permanece en 22.2.3; no se añade Capacitor, Ionic CLI ni Zone.js.
- Integración efectiva: `provideIonicAngular`, `IonApp`, `IonAvatar`, `IonButton`
  y estilos esenciales `core.css`, adaptados a los colores existentes.

## Verificaciones realizadas

- Compilación Angular de producción correcta, dentro del presupuesto configurado.
- TypeScript estricto sin errores.
- 25 pruebas aprobadas en cuatro archivos; se conservan los casos anteriores,
  actualizados al saludo exclusivo del dashboard y al contenido de Habitaciones.
- Navegación de las 25 rutas, selección activa, login de los tres roles, acceso sin
  sesión, filtrado por rol, contraseña visible/oculta y cierre de sesión.
- Saludos en todos sus límites horarios y actualización con la pantalla abierta.
- Avatar recibe identificador y nombre; fotografía opcional, iniciales y fallback
  ante error de imagen, con recuperación al recibir una URL nueva.
- Catálogos de tipos y estados coinciden con el SQL existente; filtros con selección
  local y sin búsquedas ni resultados simulados.
- Tarjetas sin datos reales; componente preparado para recibir datos tipados y foto.
- Revisión visual en navegador a 1440 × 1000, 768 × 1024 y 390 × 844.
- Tres columnas en escritorio, dos en tablet y una en móvil; sin desbordamiento
  horizontal. Menú compacto funcional y dashboard con avatar junto al saludo.
- Botones nativos de Ionic deshabilitados, confirmados también en su Shadow DOM.
- Dashboard administrativo solo con saludo y avatar; jefe conserva frase y botones.
- Reservaciones mantiene solo su título. Sin errores ni advertencias de consola
  durante la revisión final. Se verificó el cierre de sesión en el navegador.
- Backend, solución y SQL comparados por SHA-256 con el inicio de este avance.
- No se generó Android ni se ejecutaron comandos de escritura de Git.

No se probaron API, JWT, base de datos ni operaciones de negocio: están fuera del alcance.
Los campos de fotografía solo reciben una URL; no realizan cargas al servidor.

## Ejecutar

```powershell
cd C:\Users\jafet\Documents\GitHub\SISTEMA-DE-RESERVACIONES-Y-GESTION-HOTELERA\frontend\hotel-admin
npm.cmd ci
npm.cmd start
```

Abrir http://localhost:4200. Si ya hay un servidor Angular en ese puerto, usar el
existente o detenerlo antes de ejecutar otro. Para verificar:

```powershell
npm.cmd run build
npm.cmd run typecheck
npm.cmd test
```

## Archivos nuevos de este avance

Rutas relativas a `frontend/hotel-admin/`:

```text
src/app/features/rooms/models/room.ts
src/app/features/rooms/room-card/room-card.component.html
src/app/features/rooms/room-card/room-card.component.scss
src/app/features/rooms/room-card/room-card.component.ts
src/app/features/rooms/room-filters/room-filters.component.html
src/app/features/rooms/room-filters/room-filters.component.scss
src/app/features/rooms/room-filters/room-filters.component.ts
src/app/features/rooms/rooms.component.html
src/app/features/rooms/rooms.component.scss
src/app/features/rooms/rooms.component.spec.ts
src/app/features/rooms/rooms.component.ts
src/app/shared/user-avatar/user-avatar.component.html
src/app/shared/user-avatar/user-avatar.component.scss
src/app/shared/user-avatar/user-avatar.component.spec.ts
src/app/shared/user-avatar/user-avatar.component.ts
```

## Archivos modificados en este avance

```text
ENTREGA.md
README.md
package-lock.json
package.json
src/app/app.component.html
src/app/app.component.ts
src/app/app.config.ts
src/app/app.routes.ts
src/app/app.spec.ts
src/app/core/models/user.ts
src/app/features/dashboard/dashboard.component.html
src/app/features/dashboard/dashboard.component.scss
src/app/features/dashboard/dashboard.component.ts
src/app/features/module-page/module-page.component.html
src/app/features/module-page/module-page.component.scss
src/app/features/module-page/module-page.component.ts
src/styles.scss
```
