import { TestBed } from '@angular/core/testing';
import { Router, provideRouter } from '@angular/router';
import { RouterTestingHarness } from '@angular/router/testing';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { provideIonicAngular } from '@ionic/angular';
import { routes } from './app.routes';
import { HOTEL_MODULES } from './core/navigation/module-catalog';
import { DemoSessionService } from './core/session/demo-session.service';
import { SESSION_GATEWAY } from './core/session/session-gateway';
import { LoginComponent } from './features/login/login.component';
import { ShellComponent } from './layout/shell/shell.component';

describe('Frontend hotelero con Ionic', () => {
  let session: DemoSessionService;

  beforeEach(() => {
    vi.stubGlobal('matchMedia', vi.fn().mockImplementation(() => ({
      matches: false,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    })));

    TestBed.configureTestingModule({
      providers: [
        provideRouter(routes),
        provideIonicAngular({ mode: 'md', _testing: true }),
        { provide: SESSION_GATEWAY, useExisting: DemoSessionService },
      ],
    });

    session = TestBed.inject(DemoSessionService);
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllGlobals();
  });

  it('redirige al login cuando no hay sesión', async () => {
    const harness = await RouterTestingHarness.create('/habitaciones');
    expect(TestBed.inject(Router).url).toBe('/login');
    expect(harness.routeNativeElement?.querySelector('h2')?.textContent).toBe('Inicia sesión');
  });

  it.each([
    ['jefe', 'Carlos'],
    ['administrador', 'Andrea'],
    ['cocinero', 'Pepito'],
  ])('permite ingresar como %s y muestra el nombre %s', async (username, name) => {
    const harness = await RouterTestingHarness.create();
    const login = await harness.navigateByUrl('/login', LoginComponent);
    login.username = username;
    login.password = 'prueba-temporal';
    await login.signIn();
    harness.detectChanges();

    expect(TestBed.inject(Router).url).toBe('/dashboard');
    expect(harness.routeNativeElement?.querySelector('main h1')?.textContent).toContain(name);
    expect(login.password).toBe('');
  });

  it('rechaza usuarios desconocidos y contraseñas vacías', async () => {
    expect(await session.signIn('desconocido', 'prueba')).toBe(false);
    expect(await session.signIn('jefe', '   ')).toBe(false);
    expect(session.user()).toBeNull();
  });

  it('permite mostrar y ocultar la contraseña', async () => {
    const harness = await RouterTestingHarness.create();
    await harness.navigateByUrl('/login', LoginComponent);
    const element = harness.routeNativeElement!;
    const button = element.querySelector<HTMLButtonElement>('.show-password')!;
    expect(element.querySelector<HTMLInputElement>('#password')?.type).toBe('password');
    button.click();
    harness.detectChanges();
    expect(element.querySelector<HTMLInputElement>('#password')?.type).toBe('text');
    button.click();
    harness.detectChanges();
    expect(element.querySelector<HTMLInputElement>('#password')?.type).toBe('password');
  });

  it('abre los 25 módulos y limita el saludo al dashboard', async () => {
    await session.signIn('administrador', 'prueba');
    const harness = await RouterTestingHarness.create();
    expect(HOTEL_MODULES).toHaveLength(25);

    for (const module of HOTEL_MODULES) {
      await harness.navigateByUrl(`/${module.path}`);
      harness.detectChanges();
      const element = harness.routeNativeElement!;
      const main = element.querySelector('main')!;

      expect(TestBed.inject(Router).url).toBe(`/${module.path}`);
      expect(element.querySelector('.module-name')?.textContent).toBe(module.label);
      expect(element.querySelector('a[aria-current="page"]')?.textContent).toContain(module.label);
      if (module.path === 'dashboard') {
        expect(main.querySelector('h1')?.textContent).toMatch(/^¡(Buenos días|Buenas tardes|Buenas noches), Andrea!$/);
        expect(main.querySelector('app-user-avatar')?.textContent?.trim()).toBe('A');
      } else {
        expect(main.querySelector('h1')?.textContent).toBe(module.label);
        expect(main.querySelector('app-greeting, app-user-avatar')).toBeNull();

        if (module.path === 'habitaciones') {
          expect(main.querySelectorAll('app-room-card')).toHaveLength(3);
          expect(main.querySelectorAll('select')).toHaveLength(4);
          expect(main.textContent).toContain('Vista de diseño');
          expect(main.querySelector('.rooms-grid')?.textContent).not.toMatch(/Disponible|Ocupada/);
        } else {
          expect(main.textContent?.trim()).toBe(module.label);
          expect(main.querySelectorAll('button, table, form, canvas')).toHaveLength(0);
        }
      }
    }
  });

  it('muestra solo al jefe la frase y cuatro botones sin acciones', async () => {
    await session.signIn('jefe', 'prueba');
    const harness = await RouterTestingHarness.create('/dashboard');
    const main = harness.routeNativeElement!.querySelector('main')!;
    expect(main.querySelector('p')?.textContent).toBe('Estas son las estadísticas generales de tu hotel.');
    const buttons = main.querySelectorAll<HTMLButtonElement>('button');
    expect(buttons).toHaveLength(4);

    for (const button of buttons) {
      expect(button.disabled).toBe(true);
      button.click();
    }

    expect(TestBed.inject(Router).url).toBe('/dashboard');
    await harness.navigateByUrl('/reservaciones');
    expect(harness.routeNativeElement!.querySelector('main app-greeting, main p, main button')).toBeNull();
  });

  it('filtra el menú del cocinero y redirige los módulos no asignados', async () => {
    await session.signIn('cocinero', 'prueba');
    const harness = await RouterTestingHarness.create('/cocina');
    expect(harness.routeNativeElement!.querySelectorAll('nav a')).toHaveLength(6);
    expect(harness.routeNativeElement!.querySelector('main h1')?.textContent).toBe('Cocina');
    expect(harness.routeNativeElement!.querySelector('app-greeting')).toBeNull();
    await harness.navigateByUrl('/pagos');
    expect(TestBed.inject(Router).url).toBe('/dashboard');
  });

  it('cierra sesión y vuelve a impedir la navegación interna', async () => {
    await session.signIn('jefe', 'prueba');
    const harness = await RouterTestingHarness.create();
    const shell = await harness.navigateByUrl('/dashboard', ShellComponent);
    await shell.signOut();
    expect(session.user()).toBeNull();
    expect(TestBed.inject(Router).url).toBe('/login');
    await harness.navigateByUrl('/cocina');
    expect(TestBed.inject(Router).url).toBe('/login');
  });

  it('actualiza el saludo al cambiar la hora con la pantalla abierta', async () => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 10, 24, 11, 59, 59));
    await session.signIn('administrador', 'prueba');
    const harness = await RouterTestingHarness.create('/dashboard');
    expect(harness.routeNativeElement!.querySelector('h1')?.textContent).toContain('Buenos días');
    vi.advanceTimersByTime(1000);
    harness.detectChanges();
    expect(harness.routeNativeElement!.querySelector('h1')?.textContent).toContain('Buenas tardes');
  });

  it('abre y cierra el menú compacto y restaura el foco con Escape', async () => {
    vi.stubGlobal('matchMedia', vi.fn().mockImplementation(() => ({
      matches: true,
      addEventListener: vi.fn(),
      removeEventListener: vi.fn(),
    })));
    await session.signIn('administrador', 'prueba');
    const harness = await RouterTestingHarness.create('/dashboard');
    const element = harness.routeNativeElement!;
    expect(element.querySelector('aside.sidebar')?.hasAttribute('inert')).toBe(true);
    element.querySelector<HTMLButtonElement>('.menu-button')!.click();
    harness.detectChanges();
    expect(element.querySelector('.sidebar.open')).not.toBeNull();
    document.dispatchEvent(new KeyboardEvent('keydown', { key: 'Escape' }));
    harness.detectChanges();
    expect(element.querySelector('.sidebar.open')).toBeNull();
  });
});
