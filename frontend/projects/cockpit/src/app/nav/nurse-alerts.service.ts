import { Injectable, OnDestroy, inject, signal } from '@angular/core';
import { createConsumer } from '@rails/actioncable';
import { API_ORIGIN } from 'shared';
import { TokenStore } from '../auth/token-store';

// @rails/actioncable ships no TypeScript types — see
// triage/flags-live.service.ts / patients/care-activity-live.service.ts for
// the established pattern this mirrors.
interface CableSubscription {
  unsubscribe(): void;
}
interface CableConsumer {
  subscriptions: { create(params: unknown, mixin: unknown): CableSubscription };
  disconnect(): void;
}

export interface NurseAlert {
  type: 'check_in' | 'medication_dose' | 'caregiver_message';
  episode_ref: number;
  patient_id: string;
  pseudonym_code: string;
  initials: string;
  occurred_at: string;
  status?: string;
}

const MAX_ALERTS = 20;

/**
 * Product-owner feedback item #4 (ADR-0011): a real cross-app nurse alert.
 * Unlike `CareActivityLiveService` (one stream per episode, connected only
 * while a specific patient-detail page is open) this connects once, app-
 * wide, for the whole cockpit session — see `App`'s constructor effect,
 * which calls connect()/disconnect() off `AuthService.isAuthenticated()`
 * rather than any one page component's lifecycle, so the nav bell keeps
 * receiving alerts no matter which screen the nurse is looking at.
 *
 * Scope, honestly stated (see docs/adr/0011-*.md): unread state is
 * in-memory for the current browser session only — a page reload clears
 * `alerts`/`unreadCount` back to empty. No server-side "read" persistence
 * was built for this pass.
 */
@Injectable({ providedIn: 'root' })
export class NurseAlertsService implements OnDestroy {
  private readonly apiOrigin = inject(API_ORIGIN);
  private readonly tokenStore = inject(TokenStore);

  readonly alerts = signal<NurseAlert[]>([]);
  readonly unreadCount = signal(0);

  private consumer: CableConsumer | null = null;
  private subscription: CableSubscription | null = null;

  connect(): void {
    if (this.consumer) return;

    const token = this.tokenStore.token();
    if (!token) return;

    const wsOrigin = this.apiOrigin.replace(/^http/, 'ws');
    const consumer: CableConsumer = createConsumer(`${wsOrigin}/cable?token=${encodeURIComponent(token)}`);
    this.consumer = consumer;
    this.subscription = consumer.subscriptions.create(
      { channel: 'NurseAlertsChannel' },
      {
        received: (data: NurseAlert) => {
          this.alerts.update((list) => [ data, ...list ].slice(0, MAX_ALERTS));
          this.unreadCount.update((n) => n + 1);
        },
      }
    );
  }

  disconnect(): void {
    this.subscription?.unsubscribe();
    this.consumer?.disconnect();
    this.consumer = null;
    this.subscription = null;
  }

  /** Opening the bell dropdown clears the unread badge (simple "seen it" semantics, not per-item read tracking). */
  markSeen(): void {
    this.unreadCount.set(0);
  }

  ngOnDestroy(): void {
    this.disconnect();
  }
}
