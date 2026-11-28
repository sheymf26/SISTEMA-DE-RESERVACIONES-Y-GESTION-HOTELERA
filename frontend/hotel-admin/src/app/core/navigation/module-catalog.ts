import { Role } from '../models/user';

export interface HotelModule {
  readonly path: string;
  readonly label: string;
  readonly icon: string;
  readonly roles: readonly Role[];
}

export interface NavigationGroup {
  readonly label: string;
  readonly modules: readonly HotelModule[];
}

const management: readonly Role[] = ['jefe', 'administrador'];
const everyone: readonly Role[] = [...management, 'cocinero'];

// Catálogo compartido por rutas y menú; admite usuarios con varios roles.
export const NAVIGATION_GROUPS: readonly NavigationGroup[] = [
  {
    label: 'General',
    modules: [
      { path: 'dashboard', label: 'Dashboard', icon: 'home', roles: everyone },
      { path: 'mi-perfil', label: 'Mi perfil', icon: 'user', roles: everyone },
      { path: 'notificaciones', label: 'Notificaciones', icon: 'bell', roles: everyone },
    ],
  },
  {
    label: 'Administración hotelera',
    modules: [
      { path: 'habitaciones', label: 'Habitaciones', icon: 'bed', roles: management },
      { path: 'edificios-y-pisos', label: 'Edificios y pisos', icon: 'building', roles: management },
      { path: 'reservaciones', label: 'Reservaciones', icon: 'calendar', roles: management },
      { path: 'recepcion', label: 'Recepción', icon: 'desk', roles: management },
      { path: 'check-in-check-out', label: 'Check-in y Check-out', icon: 'arrows', roles: management },
      { path: 'clientes', label: 'Clientes', icon: 'users', roles: management },
      { path: 'huespedes', label: 'Huéspedes', icon: 'user', roles: management },
    ],
  },
  {
    label: 'Restaurante y servicios',
    modules: [
      { path: 'restaurante', label: 'Restaurante', icon: 'utensils', roles: everyone },
      { path: 'cocina', label: 'Cocina', icon: 'chef', roles: everyone },
      { path: 'cocteleria', label: 'Coctelería', icon: 'glass', roles: management },
      { path: 'servicio-a-la-habitacion', label: 'Servicio a la habitación', icon: 'tray', roles: everyone },
      { path: 'parqueos', label: 'Parqueos', icon: 'car', roles: management },
      { path: 'limpieza', label: 'Limpieza', icon: 'sparkles', roles: management },
      { path: 'mantenimiento', label: 'Mantenimiento', icon: 'tool', roles: management },
    ],
  },
  {
    label: 'Administración financiera',
    modules: [
      { path: 'pagos', label: 'Pagos', icon: 'wallet', roles: management },
      { path: 'facturacion', label: 'Facturación', icon: 'receipt', roles: management },
      { path: 'nomina', label: 'Nómina', icon: 'wallet', roles: management },
      { path: 'reportes', label: 'Reportes', icon: 'chart', roles: management },
    ],
  },
  {
    label: 'Gestión administrativa',
    modules: [
      { path: 'empleados', label: 'Empleados', icon: 'users', roles: management },
      { path: 'usuarios-y-permisos', label: 'Usuarios y permisos', icon: 'shield', roles: management },
      { path: 'aprobaciones', label: 'Aprobaciones', icon: 'check', roles: management },
      { path: 'configuracion-general', label: 'Configuración general', icon: 'settings', roles: management },
    ],
  },
];

export const HOTEL_MODULES = NAVIGATION_GROUPS.flatMap((group) => group.modules);

export function canAccessModule(module: HotelModule, roles: readonly Role[]): boolean {
  return roles.some((role) => module.roles.includes(role));
}
