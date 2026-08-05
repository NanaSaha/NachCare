import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { TranslatePipe } from '@ngx-translate/core';
import { OnboardingService } from './onboarding.service';
import { PushSubscriptionService } from '../push/push-subscription.service';
import { LanguageService } from '../language/language.service';

type ConsentKind = 'a' | 'b' | 'c' | 'd';
const CONSENT_KINDS: ConsentKind[] = [ 'a', 'b', 'c', 'd' ];
const STEPS = [ 'language', 'consents', 'notificationTime', 'pin', 'orientation' ] as const;

@Component({
  selector: 'app-onboarding',
  imports: [ FormsModule, TranslatePipe ],
  templateUrl: './onboarding.html',
  styleUrl: './onboarding.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Onboarding {
  private readonly onboardingService = inject(OnboardingService);
  private readonly pushSubscriptionService = inject(PushSubscriptionService);
  private readonly languageService = inject(LanguageService);
  private readonly router = inject(Router);

  readonly steps = STEPS;
  readonly consentKinds = CONSENT_KINDS;
  readonly stepIndex = signal(0);

  readonly language = signal('en');
  readonly consents = signal<Record<ConsentKind, boolean>>({ a: false, b: false, c: false, d: false });
  readonly notificationTime = signal('08:00');
  readonly pin = signal('');

  readonly submitting = signal(false);
  readonly error = signal<string | null>(null);

  get currentStep() {
    return this.steps[this.stepIndex()];
  }

  get allRequiredConsentsGranted(): boolean {
    return this.consentKinds.every((k) => this.consents()[k]);
  }

  toggleConsent(kind: ConsentKind): void {
    this.consents.update((c) => ({ ...c, [kind]: !c[kind] }));
  }

  setLanguageAndAdvance(lang: string): void {
    this.language.set(lang);
    // ADR-0008 #9: applies text direction (AR -> rtl) immediately, not just
    // the translation strings — `finish()` below persists the choice.
    this.languageService.applyLocally(lang);
    this.next();
  }

  next(): void {
    if (this.stepIndex() < this.steps.length - 1) this.stepIndex.update((i) => i + 1);
  }

  back(): void {
    if (this.stepIndex() > 0) this.stepIndex.update((i) => i - 1);
  }

  async finish(): Promise<void> {
    this.submitting.set(true);
    this.error.set(null);

    try {
      // Fired synchronously from this click handler, before any `await`
      // breaks the call stack: Chrome only allows PushManager.subscribe()
      // to ride the click's transient user-activation window, which
      // expires quickly — calling it after an awaited network round trip
      // (onboardingService.complete below) leaves the subscribe() promise
      // hanging with no permission prompt and no error. Best-effort by
      // design either way — must never block onboarding completion, since
      // in-app check-ins work without push.
      void this.pushSubscriptionService.subscribe();

      await this.onboardingService.complete({
        language: this.language(),
        notification_time: this.notificationTime(),
        pin: this.pin(),
        consents: this.consents(),
      });
      this.router.navigateByUrl('/home');
    } catch {
      this.error.set('onboarding.failed');
    } finally {
      this.submitting.set(false);
    }
  }
}
