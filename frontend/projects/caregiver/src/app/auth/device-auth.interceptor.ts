import { HttpInterceptorFn } from '@angular/common/http';
import { inject } from '@angular/core';
import { DeviceTokenStore } from './device-token-store';

export const deviceAuthInterceptor: HttpInterceptorFn = (req, next) => {
  const token = inject(DeviceTokenStore).token();
  if (!token) return next(req);

  return next(req.clone({ setHeaders: { Authorization: `Bearer ${token}` } }));
};
