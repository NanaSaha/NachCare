import { Injectable, signal } from '@angular/core';

const STORAGE_KEY = 'nachcare.caregiver.device_token';

/**
 * localStorage, not sessionStorage: the device token is meant to be
 * long-lived (Section 2: "activation-code exchange -> long-lived device
 * token") — a caregiver shouldn't have to re-activate every time they
 * close the PWA.
 */
@Injectable({ providedIn: 'root' })
export class DeviceTokenStore {
  readonly token = signal<string | null>(localStorage.getItem(STORAGE_KEY));

  set(token: string): void {
    localStorage.setItem(STORAGE_KEY, token);
    this.token.set(token);
  }

  clear(): void {
    localStorage.removeItem(STORAGE_KEY);
    this.token.set(null);
  }
}
