import { inject } from '@angular/core';
import { CanActivateChildFn, CanActivateFn, Router } from '@angular/router';
import { canAccessModule, HOTEL_MODULES } from '../navigation/module-catalog';
import { SESSION_GATEWAY } from './session-gateway';

// Estos guards solo simulan la navegación. El backend deberá autorizar cada operación.
export const sessionGuard: CanActivateFn = () => {
  return inject(SESSION_GATEWAY).user() ? true : inject(Router).createUrlTree(['/login']);
};

export const moduleGuard: CanActivateChildFn = (route) => {
  const user = inject(SESSION_GATEWAY).user();
  const router = inject(Router);

  if (!user) {
    return router.createUrlTree(['/login']);
  }

  const module = HOTEL_MODULES.find((item) => item.path === route.routeConfig?.path);
  return module && canAccessModule(module, user.roles)
    ? true
    : router.createUrlTree(['/dashboard']);
};
