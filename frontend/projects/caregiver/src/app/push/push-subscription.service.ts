import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';
import { environment } from '../../environments/environment';
import { DeviceTokenStore } from '../auth/device-token-store';
import { saveSwConfig } from './sw-config-store';

const SUBSCRIBE_TIMEOUT_MS = 15_000;

function urlBase64ToUint8Array(base64: string): Uint8Array<ArrayBuffer> {
  const padding = '='.repeat((4 - (base64.length % 4)) % 4);
  const base64Safe = (base64 + padding).replace(/-/g, '+').replace(/_/g, '/');
  const raw = atob(base64Safe);
  const bytes = new Uint8Array(raw.length);
  for (let i = 0; i < raw.length; i++) bytes[i] = raw.charCodeAt(i);
  return bytes;
}

function withTimeout<T>(promise: Promise<T>, ms: number): Promise<T> {
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error(`timed out after ${ms}ms`)), ms);
    promise.then(
      (value) => { clearTimeout(timer); resolve(value); },
      (err) => { clearTimeout(timer); reject(err); },
    );
  });
}

/**
 * Registers the plain sw.js (public/sw.js — not an Angular-CLI ngsw), asks
 * for Notification permission, subscribes via PushManager, and hands the
 * subscription to the backend. Also mirrors the device token + API origin
 * into IndexedDB on every app load a token exists, since the service
 * worker's push handler runs independently of any open tab and can't read
 * localStorage or Angular DI (see sw-config-store.ts).
 */
@Injectable({ providedIn: 'root' })
export class PushSubscriptionService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);
  private readonly deviceTokenStore = inject(DeviceTokenStore);

  async syncConfig(): Promise<void> {
    const deviceToken = this.deviceTokenStore.token();
    if (!deviceToken || !('serviceWorker' in navigator)) return;
    await saveSwConfig({ apiOrigin: this.apiOrigin, deviceToken });
  }

  // Best-effort by design: push permission may be denied, unsupported
  // (e.g. iOS PWA not yet added to home screen), or the underlying push
  // service may simply hang (observed against real push infrastructure,
  // not just a theoretical case — hence the explicit timeout below).
  // Callers must never await/throw on this or let it block onboarding or
  // check-in — in-app flows work without push.
  async subscribe(): Promise<boolean> {
    if (!('serviceWorker' in navigator) || !('PushManager' in window)) return false;

    try {
      await this.syncConfig();

      // Only prompt if permission is still undecided — re-requesting when
      // already granted/denied is a needless prompt.
      const permission = Notification.permission === 'default'
        ? await Notification.requestPermission()
        : Notification.permission;
      if (permission !== 'granted') return false;

      await navigator.serviceWorker.register('/sw.js');
      // `.ready` resolves only once a worker is installed *and* active —
      // `register()` alone can resolve before that, which makes
      // `pushManager.subscribe()` fail with "no active Service Worker".
      const registration = await navigator.serviceWorker.ready;
      const subscription = await withTimeout(
        registration.pushManager.subscribe({
          userVisibleOnly: true,
          applicationServerKey: urlBase64ToUint8Array(environment.vapidPublicKey),
        }),
        SUBSCRIBE_TIMEOUT_MS,
      );

      const json = subscription.toJSON();
      await firstValueFrom(
        this.http.patch(`${this.apiOrigin}/api/v1/caregiver/push_subscription`, {
          subscription: { endpoint: json.endpoint, keys: json.keys },
        }),
      );
      return true;
    } catch (e) {
      console.warn('[PushSubscriptionService] subscribe failed (non-fatal):', e);
      return false;
    }
  }
}
