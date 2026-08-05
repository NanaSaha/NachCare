import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface AssistantTurn {
  id: number;
  role: 'caregiver' | 'assistant';
  content: string;
  retrieval_refs: string[];
  routed: boolean;
  emergency_detected: boolean;
  routed_flag_id: number | null;
  created_at: string;
  guardrail_verdicts?: Record<string, unknown>;
}

export interface SendMessageResult {
  conversation_id: number;
  caregiver_turn: AssistantTurn;
  assistant_turn: AssistantTurn;
}

@Injectable({ providedIn: 'root' })
export class AssistantService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  list(): Promise<{ conversation_id: number | null; turns: AssistantTurn[] }> {
    return firstValueFrom(
      this.http.get<{ conversation_id: number | null; turns: AssistantTurn[] }>(
        `${this.apiOrigin}/api/v1/caregiver/assistant_messages`
      )
    );
  }

  send(message: string): Promise<SendMessageResult> {
    return firstValueFrom(
      this.http.post<SendMessageResult>(`${this.apiOrigin}/api/v1/caregiver/assistant_messages`, { message })
    );
  }

  escalate(turnId: number): Promise<{ flag_id: number }> {
    return firstValueFrom(
      this.http.post<{ flag_id: number }>(`${this.apiOrigin}/api/v1/caregiver/assistant_messages/${turnId}/escalate`, {})
    );
  }
}
