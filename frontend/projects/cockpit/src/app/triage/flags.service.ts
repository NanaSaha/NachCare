import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface FlagSummary {
  id: number;
  episode_ref: number;
  severity: 'green' | 'yellow' | 'red';
  subtype: 'clinical' | 'adherence' | 'manual' | 'ai_watch';
  state: 'open' | 'in_progress' | 'resolved';
  sla_deadline_at: string | null;
  breach: boolean;
  opened_at: string;
  first_action_at: string | null;
  resolved_at: string | null;
  outcome: string | null;
  // UC-23: only ever set for subtype ai_watch (5-day auto-expiry).
  watch_expires_at: string | null;
  patient: { pseudonym_code: string; initials: string; nyha_class: string };
}

export interface FlagDetail extends FlagSummary {
  evaluations: { id: number; severity: string; ruleset_version: string; fired_rules: unknown[]; created_at: string }[];
  interventions: { id: number; actor_ref: number; outcome: string | null; note_final: string | null; created_at: string }[];
  // note/photo_urls (ADR-0011, feedback item #2): caregiver's free-text
  // "how is she feeling today" answer + any attached photo/video URLs.
  check_in_history: {
    id: number; effective_date: string; weight_kg: string | null; symptoms: Record<string, boolean>;
    note: string | null; photo_urls: string[];
  }[];
  // UC-23 step 5: only present for subtype ai_watch — the rationale
  // panel's raw material (component breakdown), null for every other
  // flag type.
  ai_watch_meta: { risk_score_id?: number; score?: number; components?: Record<string, number>; opened_at?: string } | null;
}

export interface KpiSummary {
  open: number;
  in_progress: number;
  red: number;
  yellow: number;
  ai_watch: number;
  breached: number;
}

@Injectable({ providedIn: 'root' })
export class FlagsService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  list(state?: string): Promise<FlagSummary[]> {
    const params: Record<string, string> = {};
    if (state) params['state'] = state;
    return firstValueFrom(this.http.get<FlagSummary[]>(`${this.apiOrigin}/api/v1/staff/flags`, { params }));
  }

  summary(): Promise<KpiSummary> {
    return firstValueFrom(this.http.get<KpiSummary>(`${this.apiOrigin}/api/v1/staff/flags/summary`));
  }

  get(id: number): Promise<FlagDetail> {
    return firstValueFrom(this.http.get<FlagDetail>(`${this.apiOrigin}/api/v1/staff/flags/${id}`));
  }

  createManual(episodeRef: number, severity: string): Promise<FlagSummary> {
    return firstValueFrom(
      this.http.post<FlagSummary>(`${this.apiOrigin}/api/v1/staff/flags`, { episode_ref: episodeRef, severity })
    );
  }

  // noteAi (Section 8/M5): when the nurse's note started from a T-TRIAGE
  // copilot draft, this is sent alongside so the backend can compute
  // interventions.ai_accept_ratio (edit-tracking).
  transition(id: number, state: string, outcome?: string, note?: string, noteAi?: string): Promise<FlagDetail> {
    return firstValueFrom(
      this.http.patch<FlagDetail>(`${this.apiOrigin}/api/v1/staff/flags/${id}`, { state, outcome, note, note_ai: noteAi })
    );
  }

  // T-TRIAGE / T-CALLNOTE copilot drafts (Section 8/M5). `draft: null`
  // means graceful degradation — the UI hides the draft panel rather than
  // showing an error (Section 6 #1).
  triageDraft(id: number): Promise<{ draft: string | null }> {
    return firstValueFrom(this.http.get<{ draft: string | null }>(`${this.apiOrigin}/api/v1/staff/flags/${id}/triage_draft`));
  }

  callnoteDraft(id: number): Promise<{ draft: string | null }> {
    return firstValueFrom(this.http.get<{ draft: string | null }>(`${this.apiOrigin}/api/v1/staff/flags/${id}/callnote_draft`));
  }

  // UC-23 step 5: always returns *something* (AI-generated or a
  // deterministic plain-language fallback) — never null, unlike the other
  // copilot drafts above (this is an explanation, not an editable draft).
  aiWatchRationale(id: number): Promise<{ rationale: string }> {
    return firstValueFrom(this.http.get<{ rationale: string }>(`${this.apiOrigin}/api/v1/staff/flags/${id}/ai_watch_rationale`));
  }
}
