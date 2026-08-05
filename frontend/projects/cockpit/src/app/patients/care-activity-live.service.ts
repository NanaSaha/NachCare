import { Injectable, OnDestroy, inject, signal } from '@angular/core';
import { createConsumer } from '@rails/actioncable';
import { API_ORIGIN } from 'shared';
import { TokenStore } from '../auth/token-store';

// See triage/flags-live.service.ts for the established pattern this
// mirrors — @rails/actioncable ships no types (triage/actioncable.d.ts).
interface CableSubscription {
  unsubscribe(): void;
}
interface CableConsumer {
  subscriptions: { create(params: unknown, mixin: unknown): CableSubscription };
  disconnect(): void;
}

export interface CareActivityUpdate {
  type: 'check_in' | 'medication_dose';
  id: number;
  episode_ref: number;
  occurred_at: string;
  // check_in
  effective_date?: string;
  weight_kg?: string | null;
  // medication_dose
  medication_name?: string;
  scheduled_date?: string;
  scheduled_time?: string;
  status?: string;
}

/**
 * Nurse requirement #3 (ADR-0010): live caregiver activity (check-ins,
 * medication doses) on the patient-detail page — one stream per episode
 * (see backend CareActivityChannel), unlike FlagsChannel's one-per-site
 * triage-queue stream.
 */
@Injectable({ providedIn: 'root' })
export class CareActivityLiveService implements OnDestroy {
  private readonly apiOrigin = inject(API_ORIGIN);
  private readonly tokenStore = inject(TokenStore);

  readonly lastUpdate = signal<CareActivityUpdate | null>(null);

  private consumer: CableConsumer | null = null;
  private subscription: CableSubscription | null = null;

  connect(episodeId: number): void {
    if (this.consumer) return;

    const token = this.tokenStore.token();
    if (!token) return;

    const wsOrigin = this.apiOrigin.replace(/^http/, 'ws');
    const consumer: CableConsumer = createConsumer(`${wsOrigin}/cable?token=${encodeURIComponent(token)}`);
    this.consumer = consumer;
    this.subscription = consumer.subscriptions.create(
      { channel: 'CareActivityChannel', episode_id: episodeId },
      { received: (data: CareActivityUpdate) => this.lastUpdate.set(data) }
    );
  }

  disconnect(): void {
    this.subscription?.unsubscribe();
    this.consumer?.disconnect();
    this.consumer = null;
    this.subscription = null;
  }

  ngOnDestroy(): void {
    this.disconnect();
  }
}
