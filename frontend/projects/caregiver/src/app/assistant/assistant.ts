import { ChangeDetectionStrategy, Component, OnInit, computed, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { TranslatePipe } from '@ngx-translate/core';
import { EmergencyBlock } from 'shared';
import { AssistantService, AssistantTurn } from './assistant.service';

/**
 * Assistant chat (Section 8/M5). Renders per the four-stage pipeline's
 * output on each assistant turn: a source-citation line when the answer
 * cites the knowledge base, a routed/escalation chip when the message was
 * routed to the nurse instead of answered, and — per R4 — a static
 * <lib-emergency-block> above the reply whenever emergency_detected is
 * true. The emergency block itself is never conditioned on the assistant
 * call having succeeded; it only depends on the last-known turn state
 * already in memory, so it keeps rendering even if a later send fails.
 */
@Component({
  selector: 'app-assistant',
  imports: [ FormsModule, TranslatePipe, EmergencyBlock ],
  templateUrl: './assistant.html',
  styleUrl: './assistant.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Assistant implements OnInit {
  private readonly assistantService = inject(AssistantService);
  private readonly router = inject(Router);

  readonly turns = signal<AssistantTurn[]>([]);
  readonly loading = signal(true);
  readonly draft = signal('');
  readonly sending = signal(false);
  readonly error = signal<string | null>(null);
  readonly escalatingTurnId = signal<number | null>(null);
  readonly escalatedTurnIds = signal<ReadonlySet<number>>(new Set());

  readonly anyEmergency = computed(() => this.turns().some((t) => t.emergency_detected));

  async ngOnInit(): Promise<void> {
    try {
      const result = await this.assistantService.list();
      this.turns.set(result.turns);
    } catch {
      this.error.set('assistant.unavailable');
    } finally {
      this.loading.set(false);
    }
  }

  async send(): Promise<void> {
    const message = this.draft().trim();
    if (!message || this.sending()) return;

    this.sending.set(true);
    this.error.set(null);
    try {
      const result = await this.assistantService.send(message);
      this.turns.update((t) => [ ...t, result.caregiver_turn, result.assistant_turn ]);
      this.draft.set('');
    } catch {
      this.error.set('assistant.error');
    } finally {
      this.sending.set(false);
    }
  }

  async escalate(turn: AssistantTurn): Promise<void> {
    if (this.escalatingTurnId() !== null) return;

    this.escalatingTurnId.set(turn.id);
    try {
      await this.assistantService.escalate(turn.id);
      this.escalatedTurnIds.update((ids) => new Set([ ...ids, turn.id ]));
    } catch {
      this.error.set('assistant.error');
    } finally {
      this.escalatingTurnId.set(null);
    }
  }

  back(): void {
    this.router.navigateByUrl('/home');
  }
}
