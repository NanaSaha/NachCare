import { Component, effect, inject } from '@angular/core';
import { RouterLink, RouterLinkActive, RouterOutlet } from '@angular/router';
import { TranslatePipe } from '@ngx-translate/core';
import { AuthService } from './auth/auth.service';
import { NurseAlertsBell } from './nav/nurse-alerts-bell';
import { NurseAlertsService } from './nav/nurse-alerts.service';

@Component({
  selector: 'app-root',
  imports: [ RouterOutlet, RouterLink, RouterLinkActive, TranslatePipe, NurseAlertsBell ],
  templateUrl: './app.html',
  styleUrl: './app.css'
})
export class App {
  protected readonly auth = inject(AuthService);
  private readonly nurseAlerts = inject(NurseAlertsService);

  // Product-owner feedback item #4 (ADR-0011): connected here, at the app
  // root, not inside any one routed page component — this is what makes
  // the nav bell keep receiving alerts no matter which cockpit screen the
  // nurse has open, unlike the per-episode CareActivityChannel connection
  // (patient-detail.ts) which only lives while that one page is mounted.
  constructor() {
    effect(() => {
      if (this.auth.isAuthenticated()) {
        this.nurseAlerts.connect();
      } else {
        this.nurseAlerts.disconnect();
      }
    });
  }
}
