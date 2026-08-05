import { inject } from '@angular/core';
import { CanActivateFn, Router } from '@angular/router';
import { DeviceTokenStore } from './device-token-store';

export const deviceAuthGuard: CanActivateFn = () => {
  if (inject(DeviceTokenStore).token() !== null) return true;

  return inject(Router).createUrlTree([ '/activate' ]);
};
