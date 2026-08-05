import { DatePipe } from '@angular/common';
import { ChangeDetectionStrategy, Component, OnInit, computed, inject, signal } from '@angular/core';
import { TranslatePipe } from '@ngx-translate/core';
import { AuthService } from '../auth/auth.service';
import { RiskModelService, RiskModelStatus } from './risk-model.service';

const PROMOTING_ROLES = new Set([ 'physician', 'site_admin', 'sysadmin' ]);

// UC-21: the real gate-evaluation computation, shown honestly, plus the
// MD/ADM-gated promotion decision (including the explicit dev/demo
// override — never hidden, always distinguishable in the audit trail).
@Component({
  selector: 'app-risk-model',
  imports: [ TranslatePipe, DatePipe ],
  templateUrl: './risk-model.html',
  styleUrl: './risk-model.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class RiskModel implements OnInit {
  private readonly riskModelService = inject(RiskModelService);
  private readonly auth = inject(AuthService);

  readonly status = signal<RiskModelStatus | null>(null);
  readonly loading = signal(true);
  readonly promoting = signal(false);
  readonly overrideChecked = signal(false);

  readonly canPromote = computed(() => {
    const role = this.auth.currentUser()?.role;
    return !!role && PROMOTING_ROLES.has(role);
  });

  async ngOnInit(): Promise<void> {
    // A fresh navigation/reload starts with an empty currentUser() signal
    // (it's only populated by signIn() or an explicit load) — without this,
    // reload() below reads a null site_ref and bails before ever clearing
    // `loading`, leaving the page stuck on "Loading…" forever.
    await this.auth.loadCurrentUser();
    await this.reload();
  }

  async reload(): Promise<void> {
    const siteRef = this.auth.currentUser()?.site_ref;
    if (!siteRef) {
      this.loading.set(false);
      return;
    }

    this.loading.set(true);
    this.status.set(await this.riskModelService.status(siteRef));
    this.loading.set(false);
  }

  async promote(): Promise<void> {
    const siteRef = this.auth.currentUser()?.site_ref;
    if (!siteRef) return;

    this.promoting.set(true);
    try {
      await this.riskModelService.promote(siteRef, this.overrideChecked());
      await this.reload();
    } finally {
      this.promoting.set(false);
    }
  }

  asPercent(rate: number | null): string {
    return rate === null ? '—' : `${(rate * 100).toFixed(1)}%`;
  }
}
