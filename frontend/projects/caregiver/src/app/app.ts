import { Component, effect, inject } from '@angular/core';
import { RouterOutlet } from '@angular/router';
import { DeviceTokenStore } from './auth/device-token-store';
import { PushSubscriptionService } from './push/push-subscription.service';
import { LanguageService } from './language/language.service';
import { BottomNav } from './nav/bottom-nav';

@Component({
  selector: 'app-root',
  imports: [ RouterOutlet, BottomNav ],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class App {
  private readonly deviceTokenStore = inject(DeviceTokenStore);
  private readonly pushSubscriptionService = inject(PushSubscriptionService);
  private readonly languageService = inject(LanguageService);

  constructor() {
    // Keeps the service worker's IndexedDB config fresh on every token
    // change (activation, sign-out) — the SW's push handler can't read
    // this any other way (see sw-config-store.ts).
    effect(() => {
      this.deviceTokenStore.token();
      void this.pushSubscriptionService.syncConfig();
    });

    // Restores the caregiver's saved language + text direction on every
    // boot/reload (Section 8/M6, ADR-0008 #8/#9) — previously only ever
    // set transiently during the onboarding step's language click.
    effect(() => {
      if (this.deviceTokenStore.token()) void this.languageService.restore();
    });
  }
}
