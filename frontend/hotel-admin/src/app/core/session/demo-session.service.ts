import { Injectable, signal } from '@angular/core';
import { SessionUser } from '../models/user';
import { SessionGateway } from './session-gateway';

export const DEMO_USERS: readonly SessionUser[] = [
  { id: 'demo-jefe', username: 'jefe', firstName: 'Carlos', roles: ['jefe'], roleLabel: 'Jefe general' },
  { id: 'demo-admin', username: 'administrador', firstName: 'Andrea', roles: ['administrador'], roleLabel: 'Administrador' },
  { id: 'demo-cocina', username: 'cocinero', firstName: 'Pepito', roles: ['cocinero'], roleLabel: 'Cocinero' },
];

/** Solo demostración: no autentica identidades ni ofrece seguridad de producción.
 * La contraseña no se verifica ni se almacena. La sesión vive únicamente en memoria.
 * Sustituir el proveedor SESSION_GATEWAY al integrar la autenticación del backend.
 */
@Injectable({ providedIn: 'root' })
export class DemoSessionService implements SessionGateway {
  private readonly currentUser = signal<SessionUser | null>(null);
  readonly user = this.currentUser.asReadonly();

  async signIn(username: string, password: string): Promise<boolean> {
    const user = DEMO_USERS.find((candidate) => candidate.username === username.trim().toLowerCase());

    if (!user || !password.trim()) {
      return false;
    }

    this.currentUser.set(user);
    return true;
  }

  signOut(): void {
    this.currentUser.set(null);
  }
}
