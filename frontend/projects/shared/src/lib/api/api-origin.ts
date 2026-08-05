import { InjectionToken, Provider } from '@angular/core';

/** Backend origin (e.g. http://localhost:3001), set per-app from environment.ts. */
export const API_ORIGIN = new InjectionToken<string>('API_ORIGIN');

export function provideApiOrigin(origin: string): Provider {
  return { provide: API_ORIGIN, useValue: origin };
}
