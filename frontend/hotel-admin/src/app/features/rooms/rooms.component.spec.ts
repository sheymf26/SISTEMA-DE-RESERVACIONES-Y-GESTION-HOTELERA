import { TestBed } from '@angular/core/testing';
import { provideIonicAngular } from '@ionic/angular';
import { beforeEach, describe, expect, it } from 'vitest';
import { RoomCardData } from './models/room';
import { RoomCardComponent } from './room-card/room-card.component';
import { RoomFiltersComponent } from './room-filters/room-filters.component';
import { RoomsComponent } from './rooms.component';

describe('Diseño de habitaciones', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideIonicAngular({ _testing: true })] });
  });

  it('muestra tres vistas neutras sin códigos, precios ni disponibilidad ficticios', () => {
    const fixture = TestBed.createComponent(RoomsComponent);
    fixture.detectChanges();
    const element: HTMLElement = fixture.nativeElement;
    expect(element.querySelectorAll('app-room-card')).toHaveLength(3);
    expect(element.querySelector('app-greeting')).toBeNull();
    expect(element.querySelector('.design-note')?.textContent).toContain('sin datos reales');
    expect(element.querySelector('.rooms-grid')?.textContent).not.toMatch(/₡|\$|Disponible|Ocupada|A-101/);
    const buttons = element.querySelectorAll<HTMLElement & { readonly disabled: boolean }>('ion-button');
    expect(buttons).toHaveLength(3);
    for (const button of buttons) {
      expect(button.disabled).toBe(true);
    }
  });

  it('mantiene las opciones del catálogo SQL y conserva selecciones tipadas', async () => {
    const fixture = TestBed.createComponent(RoomFiltersComponent);
    fixture.detectChanges();
    await fixture.whenStable();
    const element: HTMLElement = fixture.nativeElement;
    expect(Array.from(element.querySelectorAll('#room-type option')).map((option) => option.textContent?.trim()))
      .toEqual(['Todos los tipos', 'Sencilla', 'Doble', 'Familiar', 'Suite']);
    expect(element.querySelectorAll('#room-building option')).toHaveLength(5);
    expect(element.querySelectorAll('#room-floor option')).toHaveLength(7);
    expect(element.querySelectorAll('#room-status option')).toHaveLength(6);
    const floor = element.querySelector<HTMLSelectElement>('#room-floor')!;
    floor.selectedIndex = 3;
    floor.dispatchEvent(new Event('change'));
    fixture.detectChanges();
    expect(fixture.componentInstance.filters().floor).toBe(3);
    expect(fixture.componentInstance.filters().status).toBe('');
  });

  it('recibe datos externos tipados sin implementar acciones de negocio', () => {
    // Fixture exclusivo de la prueba: no se incorpora al catálogo de la aplicación.
    const room: RoomCardData = {
      id: 'fixture',
      code: 'PRUEBA',
      typeName: 'Sencilla',
      buildingName: 'Edificio de prueba',
      floor: 2,
      guestCapacity: 2,
      pricePerNight: 123,
      currency: 'CRC',
      status: 'LIMPIEZA',
      photoUrl: '/habitacion-prueba.jpg',
    };
    const fixture = TestBed.createComponent(RoomCardComponent);
    fixture.componentRef.setInput('room', room);
    fixture.detectChanges();
    const element: HTMLElement = fixture.nativeElement;
    expect(element.querySelector('h2')?.textContent).toBe('PRUEBA');
    expect(element.querySelector('.status')?.textContent).toBe('Limpieza');
    expect(element.querySelector('.price')?.textContent).toContain('123');
    const image = element.querySelector('img')!;
    expect(image.getAttribute('src')).toBe('/habitacion-prueba.jpg');
    image.dispatchEvent(new Event('error'));
    fixture.detectChanges();
    expect(element.querySelector('img')).toBeNull();
    expect(element.querySelector('.photo-placeholder')).not.toBeNull();
  });
});
