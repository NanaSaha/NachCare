import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface StaffAssistantTurn {
  id: number;
  role: 'caregiver' | 'assistant';
  content: string;
  retrieval_refs: string[];
  routed: boolean;
  emergency_detected: boolean;
  created_at: string;
}

/**
 * Cockpit-facing view of a caregiver's assistant chat (Section 8/M5:
 * "routed/escalated-conversation view") — a nurse following up on an
 * AI-routed flag opens this to see the exchange behind it, not just the
 * flag's bare metadata.
 */
@Injectable({ providedIn: 'root' })
export class AssistantConversationService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  forEpisode(episodeRef: number): Promise<{ conversation_id: number | null; turns: StaffAssistantTurn[] }> {
    return firstValueFrom(
      this.http.get<{ conversation_id: number | null; turns: StaffAssistantTurn[] }>(
        `${this.apiOrigin}/api/v1/staff/episodes/${episodeRef}/assistant_conversation`
      )
    );
  }
}
