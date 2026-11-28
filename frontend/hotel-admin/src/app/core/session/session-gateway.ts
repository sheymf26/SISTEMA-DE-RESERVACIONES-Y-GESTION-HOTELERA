import { InjectionToken, Signal } from '@angular/core';
import { SessionUser } from '../models/user';

export interface SessionGateway {
  readonly user: Signal<SessionUser | null>;
  signIn(username: string, password: string): Promise<boolean>;
  signOut(): void;
}

export const SESSION_GATEWAY = new InjectionToken<SessionGateway>('SESSION_GATEWAY');
