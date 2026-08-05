import { Injectable, OnDestroy, inject, signal } from '@angular/core';
import { createConsumer } from '@rails/actioncable';
import { API_ORIGIN } from 'shared';
import { TokenStore } from '../auth/token-store';

// @rails/actioncable ships no TypeScript types (see triage/actioncable.d.ts,
// which only declares the module as `any`) — these are minimal structural
// types for the bits this service actually uses.
interface CableSubscription {
  unsubscribe(): void;
}
interface CableConsumer {
  subscriptions: { create(params: unknown, mixin: unknown): CableSubscription };
  disconnect(): void;
}

export interface FlagUpdate {
  id: number;
  severity: string;
  state: string;
  breach: boolean;
  sla_deadline_at: string | null;
  episode_ref: number;
}

/**
 * Live triage queue updates (Section 8/M3). The cable URL can't carry an
 * Authorization header (browsers don't support custom WS headers), so the
 * same Bearer token goes as a `token` query param — see
 * ApplicationCable::Connection on the backend.
 */
@Injectable({ providedIn: 'root' })
export class FlagsLiveService implements OnDestroy {
  private readonly apiOrigin = inject(API_ORIGIN);
  private readonly tokenStore = inject(TokenStore);

  readonly lastUpdate = signal<FlagUpdate | null>(null);

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
      { channel: 'FlagsChannel' },
      { received: (data: FlagUpdate) => this.lastUpdate.set(data) }
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
