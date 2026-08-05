import { ChangeDetectionStrategy, Component, OnInit, inject, signal, computed } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { RouterLink } from '@angular/router';
import { TranslatePipe, TranslateService } from '@ngx-translate/core';
import { BridgeArc, EmergencyBlock, SeverityIndicator, SeverityLevel } from 'shared';
import { CheckInService, HomeData } from './check-in.service';
import { MessagesService, CaregiverMessage } from '../messages/messages.service';
import { TrendsService } from '../trends/trends.service';
import { CarePlanExplanationService, CarePlanItemType } from '../care-plan/care-plan-explanation.service';

const STEPS = [ 'weight', 'medications', 'symptoms', 'note', 'result' ] as const;
const WEIGHT_CONFIRM_DELTA_KG = 5; // FR-C13

// R-4: breathless-at-rest is its own dedicated toggle, not folded into the
// generic symptom list, per Section 8 (M2).
const OTHER_SYMPTOMS = [ 'swelling_increased', 'fatigue_increased' ] as const;

@Component({
  selector: 'app-check-in',
  imports: [ FormsModule, TranslatePipe, SeverityIndicator, BridgeArc, EmergencyBlock, RouterLink ],
  templateUrl: './check-in.html',
  styleUrl: './check-in.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CheckIn implements OnInit {
  private readonly checkInService = inject(CheckInService);
  private readonly messagesService = inject(MessagesService);
  private readonly trendsService = inject(TrendsService);
  private readonly carePlanExplanationService = inject(CarePlanExplanationService);
  private readonly translate = inject(TranslateService);

  readonly steps = STEPS;
  readonly otherSymptoms = OTHER_SYMPTOMS;
  readonly stepIndex = signal(0);

  readonly home = signal<HomeData | null>(null);
  readonly loading = signal(true);
  readonly messages = signal<CaregiverMessage[]>([]);

  // Signature visual element (product-owner use-case catalogue): the
  // bridge-arc 90-day progress visualization shown on the Home/check-in
  // landing. Driven by the same figure TrendsController already computes
  // as `window_days = min(age_days_in_episode, 90)` — real data, no new
  // backend surface. Best-effort/non-blocking: the wizard must still work
  // if this call fails, so the arc simply doesn't render (see check-in.html).
  readonly programDay = signal<number | null>(null);

  readonly weight = signal<number | null>(null);
  readonly showWeightConfirm = signal(false);
  readonly medStatus = signal<Record<string, 'taken' | 'missed'>>({});
  readonly breathlessAtRest = signal(false);
  readonly symptoms = signal<Record<string, boolean>>({});
  readonly note = signal('');

  // Product-owner feedback item #2: optional photo/video attach on the
  // note step. Kept entirely separate from the structured symptom toggles
  // above — this never feeds Domain::Escalation::Engine.
  readonly photoFile = signal<File | null>(null);
  readonly photoPreviewUrl = signal<string | null>(null);
  readonly photoUploading = signal(false);

  readonly submitting = signal(false);
  readonly error = signal<string | null>(null);
  readonly resultSeverity = signal<SeverityLevel | null>(null);
  // M2 gap fix: the real per-check-in AI brief (or graceful-degradation
  // template) — null falls back to the static i18n severity copy.
  readonly resultBrief = signal<{ text: string; source: 'ai' | 'template' } | null>(null);
  // UC-23 step 4: a new AI WATCH flag was opened for this trajectory —
  // only ever true post-promotion. Calm, non-alarming card, never the
  // urgent/amber styling used for real alerts.
  readonly aiWatchOpened = signal(false);

  // Product-owner feedback item #1 (post-M7, ADR-0013): tap a task from
  // the nurse (a medication, or the home care/diet instructions) on Home
  // and see a grounded AI explanation of it. `explainItem` identifies
  // which item is currently open in the panel so the template can render
  // its label while `explainLoading`/`explainError`/`explainResult` track
  // that one request's lifecycle — only one explanation panel is ever
  // open at a time, so a single set of signals (not one per item) is
  // enough.
  readonly explainItem = signal<{ type: CarePlanItemType; id?: number; label: string } | null>(null);
  readonly explainLoading = signal(false);
  readonly explainError = signal(false);
  readonly explainResult = signal<{ text: string; source: 'ai' | 'template' } | null>(null);

  readonly lastWeightKg = computed(() => {
    const raw = this.home()?.last_weight_kg;
    return raw ? parseFloat(raw) : null;
  });

  readonly weightDelta = computed(() => {
    const last = this.lastWeightKg();
    const current = this.weight();
    return last !== null && current !== null ? current - last : null;
  });

  get currentStep() {
    return this.steps[this.stepIndex()];
  }

  async ngOnInit(): Promise<void> {
    this.checkInService.retryQueued();
    this.home.set(await this.checkInService.getHome());
    const meds = this.home()!.medications;
    this.medStatus.set(Object.fromEntries(meds.map((m) => [ String(m.id), 'taken' as const ])));
    this.loading.set(false);

    this.messages.set(await this.messagesService.list());

    this.trendsService
      .get()
      .then((t) => this.programDay.set(t.window_days))
      .catch(() => undefined);
  }

  toggleMed(id: number): void {
    this.medStatus.update((s) => ({ ...s, [id]: s[id] === 'taken' ? 'missed' : 'taken' }));
  }

  toggleSymptom(key: string): void {
    this.symptoms.update((s) => ({ ...s, [key]: !s[key] }));
  }

  confirmWeightAndNext(): void {
    const delta = this.weightDelta();
    if (delta !== null && Math.abs(delta) >= WEIGHT_CONFIRM_DELTA_KG && !this.showWeightConfirm()) {
      this.showWeightConfirm.set(true);
      return;
    }
    this.showWeightConfirm.set(false);
    this.next();
  }

  next(): void {
    if (this.stepIndex() < this.steps.length - 1) this.stepIndex.update((i) => i + 1);
  }

  back(): void {
    if (this.stepIndex() > 0) this.stepIndex.update((i) => i - 1);
  }

  async openExplain(type: CarePlanItemType, label: string, id?: number): Promise<void> {
    this.explainItem.set({ type, id, label });
    this.explainResult.set(null);
    this.explainError.set(false);
    this.explainLoading.set(true);

    try {
      const result = await this.carePlanExplanationService.explain(type, id);
      this.explainResult.set(result);
    } catch {
      this.explainError.set(true);
    } finally {
      this.explainLoading.set(false);
    }
  }

  closeExplain(): void {
    this.explainItem.set(null);
    this.explainResult.set(null);
    this.explainError.set(false);
  }

  openExplainInstructions(): void {
    void this.openExplain('care_instructions', this.translate.instant('home.nurseTasksInstructions'));
  }

  openExplainDiet(): void {
    void this.openExplain('diet_rules', this.translate.instant('home.nurseTasksDiet'));
  }

  onPhotoSelected(event: Event): void {
    const input = event.target as HTMLInputElement;
    const file = input.files?.[0] ?? null;
    this.setPhotoFile(file);
  }

  removePhoto(): void {
    this.setPhotoFile(null);
  }

  private setPhotoFile(file: File | null): void {
    const previous = this.photoPreviewUrl();
    if (previous) URL.revokeObjectURL(previous);

    this.photoFile.set(file);
    this.photoPreviewUrl.set(file ? URL.createObjectURL(file) : null);
  }

  async submit(): Promise<void> {
    this.submitting.set(true);
    this.error.set(null);

    const result = await this.checkInService.submit({
      client_uuid: crypto.randomUUID(),
      effective_date: new Date().toISOString().slice(0, 10),
      weight_kg: this.weight(),
      symptoms: { ...this.symptoms(), breathless_at_rest: this.breathlessAtRest() },
      med_status: this.medStatus(),
      note: this.note(),
    });

    // Best-effort: the photo attach is a follow-up request against the
    // check-in the above call just created, so it can only run once that
    // check-in genuinely has a server-side id — not while offline-queued.
    const photo = this.photoFile();
    if (result !== 'queued' && photo) {
      this.photoUploading.set(true);
      await this.checkInService.attachPhoto(result.check_in.id, photo);
      this.photoUploading.set(false);
    }

    this.submitting.set(false);

    if (result === 'queued') {
      this.resultSeverity.set(null); // "will sync" state, no severity yet
      this.resultBrief.set(null);
      this.aiWatchOpened.set(false);
    } else {
      this.resultSeverity.set(result.evaluation?.severity ?? 'green');
      this.resultBrief.set(result.brief);
      this.aiWatchOpened.set(result.ai_watch?.opened ?? false);
    }
    this.next(); // -> result step regardless; template distinguishes queued vs resolved
  }
}
