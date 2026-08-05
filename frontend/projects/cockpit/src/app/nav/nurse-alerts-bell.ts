import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { RouterLink } from '@angular/router';
import { TranslatePipe } from '@ngx-translate/core';
import { NurseAlert, NurseAlertsService } from './nurse-alerts.service';

// Product-owner feedback item #4 (ADR-0011): persistent nav bell/badge,
// visible from every cockpit screen (mounted once in app.html, not inside
// any routed page), fed by NurseAlertsService's site-wide ActionCable
// stream. Opening the dropdown clears the unread badge — see
// NurseAlertsService.markSeen() for the exact (deliberately simple,
// session-only) "read" semantics.
@Component({
  selector: 'app-nurse-alerts-bell',
  imports: [ RouterLink, TranslatePipe, DatePipe ],
  templateUrl: './nurse-alerts-bell.html',
  styleUrl: './nurse-alerts-bell.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class NurseAlertsBell {
  protected readonly nurseAlerts = inject(NurseAlertsService);

  readonly open = signal(false);

  toggle(): void {
    const next = !this.open();
    this.open.set(next);
    if (next) this.nurseAlerts.markSeen();
  }

  close(): void {
    this.open.set(false);
  }

  descriptionKey(alert: NurseAlert): string {
    if (alert.type === 'medication_dose') return `nurseAlerts.item.dose.${alert.status ?? 'taken'}`;

    return `nurseAlerts.item.${alert.type}`;
  }
}
