import { ChangeDetectionStrategy, Component, OnDestroy, OnInit, computed, effect, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, RouterLink } from '@angular/router';
import { TranslatePipe } from '@ngx-translate/core';
import { BridgeArc } from 'shared';
import { AuthService } from '../auth/auth.service';
import { PatientsService, PatientDetail as PatientDetailModel, MedicationSummary, CareActivityEntry } from './patients.service';
import { MessagesService, StaffMessage } from '../messages/messages.service';
import { CareActivityLiveService } from './care-activity-live.service';
import { CadenceProposalsService, CadenceProposal } from './cadence-proposals.service';

const MESSAGE_TEMPLATE_KEYS = [ 'checkin_reminder', 'thank_you', 'low_salt_day', 'track_fluids_1_5l', 'elevate_legs_photo', 'call_nurse_now' ];
const MAX_ACTIVITY_ITEMS = 20;

// Local editing state for one medication's schedule (ADR-0010 shape:
// `{"times": ["08:00", "20:00"], "instructions": "..."}`).
interface MedicationDraft {
  id: number;
  name: string;
  critical: boolean;
  drug_id: number | null;
  times: string[];
  instructions: string;
}

@Component({
  selector: 'app-patient-detail',
  imports: [ FormsModule, RouterLink, TranslatePipe, DatePipe, BridgeArc ],
  templateUrl: './patient-detail.html',
  styleUrl: './patient-detail.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PatientDetail implements OnInit, OnDestroy {
  private readonly patientsService = inject(PatientsService);
  private readonly messagesService = inject(MessagesService);
  private readonly authService = inject(AuthService);
  private readonly route = inject(ActivatedRoute);
  private readonly careActivityLive = inject(CareActivityLiveService);
  private readonly cadenceProposalsService = inject(CadenceProposalsService);

  // UC-24: post-promotion-only. Empty pre-promotion or with no signal to
  // propose — the panel simply doesn't render (see patient-detail.html).
  readonly cadenceProposals = signal<CadenceProposal[]>([]);
  readonly cadenceDeciding = signal(false);

  readonly patient = signal<PatientDetailModel | null>(null);
  readonly loading = signal(true);
  readonly dietRules = signal('');
  readonly careInstructions = signal('');
  readonly thresholdsJson = signal('');
  readonly saving = signal(false);
  readonly error = signal<string | null>(null);

  // Medication schedule editing (caregiver requirement #2/#3 support).
  readonly medicationDrafts = signal<MedicationDraft[]>([]);
  readonly scheduleSaving = signal(false);
  readonly scheduleError = signal<string | null>(null);
  // Product-owner feedback item #1 (ADR-0011): "add medication" needs a
  // client-side id before the backend has assigned a real one — negative,
  // decrementing, so it never collides with a real (positive) medication
  // id from the API. Dropped once the schedule save round-trips and the
  // drafts are rebuilt from the server's response (toDraft, below).
  private nextTempMedicationId = -1;

  // Nurse must fill in a name for every medication (including ones just
  // added) before the schedule can be saved — the backend creates each
  // medication via `create!`, which would raise on a blank name rather
  // than returning a clean 422, so this is validated client-side first.
  readonly hasInvalidMedication = computed(() => this.medicationDrafts().some((m) => !m.name.trim()));

  // Nurse requirement #3: live caregiver activity feed, seeded from the
  // initial fetch and prepended-to as ActionCable updates arrive.
  readonly recentActivity = signal<CareActivityEntry[]>([]);

  constructor() {
    effect(() => {
      const update = this.careActivityLive.lastUpdate();
      if (!update) return;
      this.recentActivity.update((list) => [ update, ...list.filter((a) => !(a.type === update.type && a.id === update.id)) ].slice(0, MAX_ACTIVITY_ITEMS));
    });
  }

  readonly messageTemplateKeys = MESSAGE_TEMPLATE_KEYS;
  readonly messages = signal<StaffMessage[]>([]);
  readonly messageTemplateKey = signal('');
  readonly messageBodySource = signal('');
  readonly messageLanguage = signal('en');
  readonly messagePreview = signal<{ body_source: string; body_translated: string | null } | null>(null);
  readonly messageBodyTranslated = signal('');
  readonly messagePreviewing = signal(false);
  readonly messageSending = signal(false);
  readonly messageError = signal<string | null>(null);

  // FR-N8: only a physician (or sysadmin) may edit clinical thresholds.
  readonly canEditThresholds = computed(() => {
    const role = this.authService.currentUser()?.role;
    return role === 'physician' || role === 'sysadmin';
  });

  // Day-90 graduation (Section 8/M6, ADR-0008 #4/#5).
  readonly graduating = signal(false);
  readonly graduateError = signal<string | null>(null);

  readonly currentEpisode = computed(() => this.patient()?.episodes[0] ?? null);

  // Signature visual element (product-owner use-case catalogue): the same
  // bridge-arc used on the caregiver onboarding/check-in screens, here
  // showing the nurse the patient's position on the 90-day journey and,
  // for a graduated episode, the "fully crossed" state. Purely derived
  // from `episode.start_date`, which the detail fetch already returns —
  // no new backend call, no change to what this component fetches.
  readonly programDay = computed(() => {
    const episode = this.currentEpisode();
    if (!episode) return null;
    if (episode.status === 'graduated') return 90;
    const ageDays = Math.floor((Date.now() - new Date(episode.start_date).getTime()) / 86_400_000);
    return Math.min(Math.max(ageDays, 0), 90);
  });

  async ngOnInit(): Promise<void> {
    await this.authService.loadCurrentUser();
    const id = this.route.snapshot.paramMap.get('id')!;
    const patient = await this.patientsService.get(id);
    this.patient.set(patient);

    const activePlan = patient.episodes[0]?.care_plan;
    this.dietRules.set(activePlan?.diet_rules ?? '');
    this.careInstructions.set(activePlan?.care_instructions ?? '');
    this.thresholdsJson.set(activePlan ? JSON.stringify(activePlan.thresholds, null, 2) : '{}');
    this.medicationDrafts.set((activePlan?.medications ?? []).map((m) => this.toDraft(m)));
    this.recentActivity.set(patient.episodes[0]?.recent_activity ?? []);
    this.loading.set(false);

    const episodeId = patient.episodes[0]?.id;
    if (episodeId) {
      this.messages.set(await this.messagesService.list(episodeId));
      this.careActivityLive.connect(episodeId);
      this.cadenceProposals.set(await this.cadenceProposalsService.list(episodeId));
    }
  }

  ngOnDestroy(): void {
    this.careActivityLive.disconnect();
  }

  get pendingCadenceProposal(): CadenceProposal | null {
    return this.cadenceProposals().find((p) => p.status === 'pending') ?? null;
  }

  async approveCadenceProposal(proposal: CadenceProposal): Promise<void> {
    const episodeId = this.currentEpisode()?.id;
    if (!episodeId) return;

    this.cadenceDeciding.set(true);
    try {
      await this.cadenceProposalsService.approve(episodeId, proposal.id);
      this.cadenceProposals.set(await this.cadenceProposalsService.list(episodeId));
    } finally {
      this.cadenceDeciding.set(false);
    }
  }

  async dismissCadenceProposal(proposal: CadenceProposal): Promise<void> {
    const episodeId = this.currentEpisode()?.id;
    if (!episodeId) return;

    this.cadenceDeciding.set(true);
    try {
      await this.cadenceProposalsService.dismiss(episodeId, proposal.id);
      this.cadenceProposals.set(await this.cadenceProposalsService.list(episodeId));
    } finally {
      this.cadenceDeciding.set(false);
    }
  }

  private toDraft(med: MedicationSummary): MedicationDraft {
    const schedule = med.schedule as { times?: string[]; instructions?: string | null };
    return {
      id: med.id, name: med.name, critical: med.critical, drug_id: med.drug_id,
      times: [ ...(schedule.times ?? []) ], instructions: schedule.instructions ?? '',
    };
  }

  selectTemplate(key: string): void {
    this.messageTemplateKey.set(key);
    this.messageBodySource.set('');
    this.messagePreview.set(null);
  }

  async previewMessage(): Promise<void> {
    const episodeId = this.patient()?.episodes[0]?.id;
    if (!episodeId) return;

    this.messagePreviewing.set(true);
    this.messageError.set(null);
    try {
      const preview = await this.messagesService.preview(episodeId, {
        templateKey: this.messageTemplateKey() || undefined,
        bodySource: this.messageTemplateKey() ? undefined : this.messageBodySource(),
        language: this.messageLanguage(),
      });
      this.messagePreview.set(preview);
      // Nurse reviews/edits this before send (show-before-send) — pre-fill
      // with whatever TranslateAssist returned, empty string if it
      // couldn't translate (M4 stub — see Domain::Messages::TranslateAssist).
      this.messageBodyTranslated.set(preview.body_translated ?? '');
    } catch {
      this.messageError.set('patients.messages.previewFailed');
    } finally {
      this.messagePreviewing.set(false);
    }
  }

  async sendMessage(): Promise<void> {
    const episodeId = this.patient()?.episodes[0]?.id;
    const preview = this.messagePreview();
    if (!episodeId || !preview) return;

    this.messageSending.set(true);
    this.messageError.set(null);
    try {
      const sent = await this.messagesService.send(episodeId, {
        templateKey: this.messageTemplateKey() || undefined,
        bodySource: preview.body_source,
        bodyTranslated: this.messageBodyTranslated() || null,
        language: this.messageLanguage(),
      });
      this.messages.update((list) => [ ...list, sent ]);
      this.messageTemplateKey.set('');
      this.messageBodySource.set('');
      this.messagePreview.set(null);
      this.messageBodyTranslated.set('');
    } catch {
      this.messageError.set('patients.messages.sendFailed');
    } finally {
      this.messageSending.set(false);
    }
  }

  async saveDietRules(): Promise<void> {
    await this.saveCarePlan({ diet_rules: this.dietRules() });
  }

  // Product-owner request (post-M7, ADR-0010): nurse-authored home care
  // instructions, same permission level/flow as diet_rules.
  async saveCareInstructions(): Promise<void> {
    await this.saveCarePlan({ care_instructions: this.careInstructions() });
  }

  addTimeSlot(medicationId: number): void {
    this.medicationDrafts.update((list) =>
      list.map((m) => (m.id === medicationId ? { ...m, times: [ ...m.times, '08:00' ] } : m))
    );
  }

  removeTimeSlot(medicationId: number, index: number): void {
    this.medicationDrafts.update((list) =>
      list.map((m) => (m.id === medicationId ? { ...m, times: m.times.filter((_, i) => i !== index) } : m))
    );
  }

  updateTime(medicationId: number, index: number, value: string): void {
    this.medicationDrafts.update((list) =>
      list.map((m) => (m.id === medicationId ? { ...m, times: m.times.map((t, i) => (i === index ? value : t)) } : m))
    );
  }

  updateInstructions(medicationId: number, value: string): void {
    this.medicationDrafts.update((list) => list.map((m) => (m.id === medicationId ? { ...m, instructions: value } : m)));
  }

  updateName(medicationId: number, value: string): void {
    this.medicationDrafts.update((list) => list.map((m) => (m.id === medicationId ? { ...m, name: value } : m)));
  }

  updateCritical(medicationId: number, value: boolean): void {
    this.medicationDrafts.update((list) => list.map((m) => (m.id === medicationId ? { ...m, critical: value } : m)));
  }

  // Product-owner feedback item #1: "nurse still can't add medication".
  // Appends an empty draft the nurse fills in (name, critical, time
  // slots) and then saves via the existing saveSchedules() flow, which
  // already sends the full medications array on every save.
  addMedication(): void {
    this.medicationDrafts.update((list) => [
      ...list,
      { id: this.nextTempMedicationId--, name: '', critical: false, drug_id: null, times: [], instructions: '' },
    ]);
  }

  removeMedication(medicationId: number): void {
    this.medicationDrafts.update((list) => list.filter((m) => m.id !== medicationId));
  }

  // Persists every medication's current schedule as a new care-plan
  // version. Sends the full medications array (not just the one edited)
  // since the backend replaces the whole list when `medications` is
  // present (CarePlansController#create) — carries every medication's
  // name/critical/drug_id forward from the loaded drafts.
  async saveSchedules(): Promise<void> {
    const episodeId = this.patient()?.episodes[0]?.id;
    if (!episodeId) return;

    if (this.hasInvalidMedication()) {
      this.scheduleError.set('patients.carePlan.medicationNameRequired');
      return;
    }

    this.scheduleSaving.set(true);
    this.scheduleError.set(null);
    try {
      await this.patientsService.updateCarePlan(episodeId, {
        medications: this.medicationDrafts().map((m) => ({
          name: m.name, critical: m.critical, drug_id: m.drug_id,
          schedule: { times: [ ...m.times ].sort(), instructions: m.instructions },
        })),
      });
      this.patient.set(await this.patientsService.get(this.patient()!.id));
      const activePlan = this.patient()?.episodes[0]?.care_plan;
      this.medicationDrafts.set((activePlan?.medications ?? []).map((m) => this.toDraft(m)));
    } catch {
      this.scheduleError.set('patients.carePlan.scheduleSaveFailed');
    } finally {
      this.scheduleSaving.set(false);
    }
  }

  async saveThresholds(): Promise<void> {
    let parsed: Record<string, unknown>;
    try {
      parsed = JSON.parse(this.thresholdsJson());
    } catch {
      this.error.set('patients.carePlan.invalidJson');
      return;
    }
    await this.saveCarePlan({ thresholds: parsed });
  }

  private async saveCarePlan(payload: { diet_rules?: string; care_instructions?: string; thresholds?: Record<string, unknown> }): Promise<void> {
    const episodeId = this.patient()?.episodes[0]?.id;
    if (!episodeId) return;

    this.saving.set(true);
    this.error.set(null);
    try {
      await this.patientsService.updateCarePlan(episodeId, payload);
      this.patient.set(await this.patientsService.get(this.patient()!.id));
    } catch {
      this.error.set('patients.carePlan.saveFailed');
    } finally {
      this.saving.set(false);
    }
  }

  async graduate(): Promise<void> {
    const episodeId = this.currentEpisode()?.id;
    if (!episodeId) return;

    this.graduating.set(true);
    this.graduateError.set(null);
    try {
      await this.patientsService.graduate(episodeId);
      this.patient.set(await this.patientsService.get(this.patient()!.id));
    } catch {
      this.graduateError.set('patients.graduation.failed');
    } finally {
      this.graduating.set(false);
    }
  }
}
