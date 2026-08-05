import { Injectable, inject } from '@angular/core';
import { TranslateService } from '@ngx-translate/core';
import { CheckInService } from '../check-in/check-in.service';
import { OnboardingService } from '../onboarding/onboarding.service';

const RTL_LANGUAGES = new Set([ 'ar' ]);

/**
 * Runtime language switching outside onboarding (Section 8/M6, ADR-0008
 * #8/#9). Onboarding's own language step (`onboarding.ts`) calls
 * `TranslateService.use()` directly but never persists AR's `dir`, and
 * nothing restores the caregiver's saved language on reload — this
 * service is the one place both concerns live, used at app boot and from
 * the Care-team page's language switcher.
 */
@Injectable({ providedIn: 'root' })
export class LanguageService {
  private readonly translate = inject(TranslateService);
  private readonly checkInService = inject(CheckInService);
  private readonly onboardingService = inject(OnboardingService);

  /** Called once at app boot (if a device token exists) to restore the caregiver's saved language + text direction. */
  async restore(): Promise<void> {
    try {
      const home = await this.checkInService.getHome();
      this.apply(home.caregiver.language);
    } catch {
      // Not activated/onboarded yet (e.g. still on /activate) — nothing to restore.
    }
  }

  /** Switches immediately (so the UI reflects it right away) and persists it — ADR-0008 #7: notifications read caregiver.language fresh at send time, so this alone makes "pending-notification language follows switch" true. */
  async switchTo(lang: string): Promise<void> {
    this.apply(lang);
    await this.onboardingService.complete({ language: lang });
  }

  /** Applies the language + text direction locally without a network round trip — used by the onboarding wizard's own language step, which persists everything itself in one call at `finish()`. */
  applyLocally(lang: string): void {
    this.apply(lang);
  }

  private apply(lang: string): void {
    this.translate.use(lang);
    document.documentElement.lang = lang;
    document.documentElement.dir = RTL_LANGUAGES.has(lang) ? 'rtl' : 'ltr';
  }
}
