export type Role = 'jefe' | 'administrador' | 'cocinero';

export interface SessionUser {
  readonly id: string;
  readonly username: string;
  readonly firstName: string;
  readonly photoUrl?: string | null;
  readonly roles: readonly Role[];
  readonly roleLabel: string;
}
