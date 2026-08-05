import { ChangeDetectionStrategy, Component, OnInit, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslatePipe, TranslateService } from '@ngx-translate/core';
import { CheckInService, HomeData } from '../check-in/check-in.service';
import { VoiceService } from './voice.service';

/**
 * Caregiver requirement #1/#2 (post-M7, ADR-0010): "when caregiver logs in,
 * they see all information uploaded by the nurse/dr" + a voice-playback
 * button. Reuses `CheckInService.getHome()` (already extended with
 * diet_rules/care_instructions/medication schedules) rather than a new
 * endpoint — the wizard's own `/home` route already fetches this data, so
 * this screen is a second, dedicated read view of the same payload,
 * reachable from the check-in wizard's nav bar.
 */
@Component({
  selector: 'app-care-plan',
  imports: [ RouterLink, TranslatePipe ],
  templateUrl: './care-plan.html',
  styleUrl: './care-plan.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CarePlan implements OnInit {
  private readonly checkInService = inject(CheckInService);
  private readonly voiceService = inject(VoiceService);
  private readonly translate = inject(TranslateService);

  readonly home = signal<HomeData | null>(null);
  readonly loading = signal(true);
  readonly speaking = signal(false);

  readonly voiceSupported = this.voiceService.isSupported();

  readonly hasContent = computed(() => {
    const h = this.home();
    return !!h && (!!h.diet_rules || !!h.care_instructions || h.medications.length > 0);
  });

  async ngOnInit(): Promise<void> {
    this.home.set(await this.checkInService.getHome());
    this.loading.set(false);
  }

  speak(): void {
    const text = this.buildSpokenText();
    if (!text) return;

    const lang = this.translate.currentLang() || this.home()?.caregiver.language || 'en';
    const started = this.voiceService.speak(text, lang);
    this.speaking.set(started);
  }

  stop(): void {
    this.voiceService.stop();
    this.speaking.set(false);
  }

  /** Composes a plain-language reading of everything the nurse uploaded, in the caregiver's current UI language's translated labels. */
  buildSpokenText(): string {
    const h = this.home();
    if (!h) return '';

    const parts: string[] = [];

    if (h.care_instructions) {
      parts.push(`${this.translate.instant('carePlan.spokenIntro')} ${h.care_instructions}`);
    }
    if (h.diet_rules) {
      parts.push(`${this.translate.instant('carePlan.spokenDiet')} ${h.diet_rules}`);
    }
    if (h.medications.length > 0) {
      parts.push(this.translate.instant('carePlan.spokenMedicationsIntro'));
      for (const med of h.medications) {
        const times = med.schedule.times.length > 0 ? med.schedule.times.join(', ') : this.translate.instant('carePlan.spokenNoTimes');
        const instructions = med.schedule.instructions ? `, ${med.schedule.instructions}` : '';
        parts.push(`${med.name} ${this.translate.instant('carePlan.spokenAt')} ${times}${instructions}.`);
      }
    }

    return parts.join(' ');
  }
}
