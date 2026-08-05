import { ChangeDetectionStrategy, Component, OnInit, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ActivatedRoute, Router } from '@angular/router';
import { TranslatePipe } from '@ngx-translate/core';
import { SeverityIndicator, SeverityLevel } from 'shared';
import { FlagsService, FlagDetail as FlagDetailModel } from './flags.service';
import { AssistantConversationService, StaffAssistantTurn } from './assistant-conversation.service';

@Component({
  selector: 'app-flag-detail',
  imports: [ FormsModule, TranslatePipe, SeverityIndicator, DatePipe ],
  templateUrl: './flag-detail.html',
  styleUrl: './flag-detail.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class FlagDetail implements OnInit {
  private readonly flagsService = inject(FlagsService);
  private readonly assistantConversationService = inject(AssistantConversationService);
  private readonly route = inject(ActivatedRoute);
  private readonly router = inject(Router);

  readonly flag = signal<FlagDetailModel | null>(null);
  readonly loading = signal(true);
  readonly outcome = signal('');
  readonly note = signal('');
  readonly submitting = signal(false);

  // T-TRIAGE copilot (Section 8/M5): `null` means graceful degradation —
  // the panel hides itself (Section 6 #1), not an error state.
  readonly triageDraft = signal<string | null>(null);
  readonly triageDraftLoading = signal(false);
  readonly triageDraftRequested = signal(false);
  // The exact AI text last inserted into `note` via "use this draft", sent
  // back as note_ai on save so the backend can compute
  // interventions.ai_accept_ratio from how much the nurse kept vs edited.
  readonly aiDraftOrigin = signal<string | null>(null);

  readonly conversationTurns = signal<StaffAssistantTurn[]>([]);
  readonly conversationLoading = signal(true);

  // UC-23 step 5: the AI WATCH rationale panel — always returns
  // *something* once requested (never a bare score).
  readonly aiWatchRationale = signal<string | null>(null);
  readonly aiWatchRationaleLoading = signal(false);
  readonly aiWatchRationaleRequested = signal(false);

  async ngOnInit(): Promise<void> {
    await this.load();
  }

  async load(): Promise<void> {
    const id = Number(this.route.snapshot.paramMap.get('id'));
    this.loading.set(true);
    const flag = await this.flagsService.get(id);
    this.flag.set(flag);
    this.loading.set(false);

    void this.loadConversation(flag.episode_ref);
  }

  async loadConversation(episodeRef: number): Promise<void> {
    this.conversationLoading.set(true);
    try {
      const result = await this.assistantConversationService.forEpisode(episodeRef);
      this.conversationTurns.set(result.turns);
    } finally {
      this.conversationLoading.set(false);
    }
  }

  async loadTriageDraft(): Promise<void> {
    const f = this.flag();
    if (!f) return;

    this.triageDraftRequested.set(true);
    this.triageDraftLoading.set(true);
    try {
      const result = await this.flagsService.triageDraft(f.id);
      this.triageDraft.set(result.draft);
    } finally {
      this.triageDraftLoading.set(false);
    }
  }

  async loadAiWatchRationale(): Promise<void> {
    const f = this.flag();
    if (!f) return;

    this.aiWatchRationaleRequested.set(true);
    this.aiWatchRationaleLoading.set(true);
    try {
      const result = await this.flagsService.aiWatchRationale(f.id);
      this.aiWatchRationale.set(result.rationale);
    } finally {
      this.aiWatchRationaleLoading.set(false);
    }
  }

  // UC-23 step 6: the three nurse actions on an open AI WATCH flag —
  // Intervention#outcome values on the existing flag lifecycle, not a
  // parallel action system.
  async applyWatchOutcome(outcome: 'accept_and_watch' | 'accept_and_intervene' | 'dismiss_false_positive'): Promise<void> {
    const f = this.flag();
    if (!f) return;

    const state = outcome === 'dismiss_false_positive' ? 'resolved' : 'in_progress';
    this.submitting.set(true);
    const updated = await this.flagsService.transition(f.id, state, outcome, this.note() || undefined);
    this.flag.set(updated);
    this.note.set('');
    this.submitting.set(false);
  }

  useDraft(): void {
    const draft = this.triageDraft();
    if (draft === null) return;

    this.note.set(draft);
    this.aiDraftOrigin.set(draft);
  }

  setNote(value: string): void {
    this.note.set(value);
  }

  asSeverity(s: string): SeverityLevel {
    return s as SeverityLevel;
  }

  /** SVG polyline points for a 300x80 viewBox sparkline of weight over check_in_history. */
  sparklinePoints(): string {
    const history = this.flag()?.check_in_history ?? [];
    const weights = history.map((c) => (c.weight_kg ? parseFloat(c.weight_kg) : null));
    const known = weights.filter((w): w is number => w !== null);
    if (known.length === 0) return '';

    const min = Math.min(...known);
    const max = Math.max(...known);
    const range = max - min || 1;
    const stepX = history.length > 1 ? 300 / (history.length - 1) : 0;

    return weights
      .map((w, i) => (w === null ? null : `${i * stepX},${80 - ((w - min) / range) * 80}`))
      .filter((p): p is string => p !== null)
      .join(' ');
  }

  async transition(state: string): Promise<void> {
    const f = this.flag();
    if (!f) return;

    this.submitting.set(true);
    const updated = await this.flagsService.transition(
      f.id, state, this.outcome() || undefined, this.note() || undefined, this.aiDraftOrigin() || undefined
    );
    this.flag.set(updated);
    this.outcome.set('');
    this.note.set('');
    this.aiDraftOrigin.set(null);
    this.triageDraft.set(null);
    this.triageDraftRequested.set(false);
    this.submitting.set(false);
  }

  back(): void {
    this.router.navigateByUrl('/triage');
  }
}
