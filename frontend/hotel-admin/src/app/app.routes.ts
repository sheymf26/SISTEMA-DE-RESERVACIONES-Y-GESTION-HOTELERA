import { Route, Routes } from '@angular/router';
import { HOTEL_MODULES } from './core/navigation/module-catalog';
import { moduleGuard, sessionGuard } from './core/session/session.guard';

function modulePage(path: string): NonNullable<Route['loadComponent']> {
  switch (path) {
    case 'dashboard':
      return () => import('./features/dashboard/dashboard.component').then((page) => page.DashboardComponent);
    case 'habitaciones':
      return () => import('./features/rooms/rooms.component').then((page) => page.RoomsComponent);
    default:
      return () => import('./features/module-page/module-page.component').then((page) => page.ModulePageComponent);
  }
}

export const routes: Routes = [
  {
    path: 'login',
    title: 'Iniciar sesión · Gestión Hotelera',
    loadComponent: () => import('./features/login/login.component').then((module) => module.LoginComponent),
  },
  {
    path: '',
    canActivate: [sessionGuard],
    canActivateChild: [moduleGuard],
    loadComponent: () => import('./layout/shell/shell.component').then((module) => module.ShellComponent),
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'dashboard' },
      ...HOTEL_MODULES.map((module) => ({
        path: module.path,
        title: `${module.label} · Gestión Hotelera`,
        data: { label: module.label },
        loadComponent: modulePage(module.path),
      })),
    ],
  },
  { path: '**', redirectTo: 'dashboard' },
];
