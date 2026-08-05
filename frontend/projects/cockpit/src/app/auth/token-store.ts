import { Injectable, signal } from '@angular/core';

const STORAGE_KEY = 'nachcare.cockpit.token';

/**
 * Session-only by design: cockpit staff sessions shouldn't outlive the
 * browser tab on a shared ward workstation. devise-jwt issues the token
 * via the Authorization response header, not the body — see AuthService.
 */
@Injectable({ providedIn: 'root' })
export class TokenStore {
  readonly token = signal<string | null>(sessionStorage.getItem(STORAGE_KEY));

  set(token: string): void {
    sessionStorage.setItem(STORAGE_KEY, token);
    this.token.set(token);
  }

  clear(): void {
    sessionStorage.removeItem(STORAGE_KEY);
    this.token.set(null);
  }
}
