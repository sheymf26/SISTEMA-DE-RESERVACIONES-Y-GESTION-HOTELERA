import { TestBed } from '@angular/core/testing';
import { provideIonicAngular } from '@ionic/angular';
import { beforeEach, describe, expect, it } from 'vitest';
import { UserAvatarComponent } from './user-avatar.component';

describe('Avatar reutilizable', () => {
  beforeEach(() => {
    TestBed.configureTestingModule({ providers: [provideIonicAngular({ _testing: true })] });
  });

  it('recibe identificador y nombre, y usa iniciales sin una fotografía', () => {
    const fixture = TestBed.createComponent(UserAvatarComponent);
    fixture.componentRef.setInput('userId', 'usuario-prueba');
    fixture.componentRef.setInput('name', 'María Sol');
    fixture.detectChanges();
    const avatar = fixture.nativeElement.querySelector('ion-avatar') as HTMLElement;
    expect(avatar.dataset['userId']).toBe('usuario-prueba');
    expect(avatar.getAttribute('aria-label')).toBe('Avatar de María Sol');
    expect(avatar.textContent?.trim()).toBe('MS');
    expect(avatar.querySelector('img')).toBeNull();
  });

  it('presenta la foto recibida y vuelve a iniciales si falla', () => {
    const fixture = TestBed.createComponent(UserAvatarComponent);
    fixture.componentRef.setInput('userId', 'usuario-prueba');
    fixture.componentRef.setInput('name', 'Lucía');
    fixture.componentRef.setInput('photoUrl', '/foto-prueba.jpg');
    fixture.detectChanges();
    const image = fixture.nativeElement.querySelector('img') as HTMLImageElement;
    expect(image.getAttribute('src')).toBe('/foto-prueba.jpg');
    image.dispatchEvent(new Event('error'));
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('img')).toBeNull();
    expect(fixture.nativeElement.textContent.trim()).toBe('L');
    fixture.componentRef.setInput('photoUrl', '/otra-foto.jpg');
    fixture.detectChanges();
    expect(fixture.nativeElement.querySelector('img')?.getAttribute('src')).toBe('/otra-foto.jpg');
  });
});
