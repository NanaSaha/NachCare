import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface StaffMessage {
  id: number;
  episode_ref: number;
  sender: string;
  template_key: string | null;
  body_source: string;
  body_translated: string | null;
  language: string;
  created_at: string;
  // Product-owner feedback item #3 (ADR-0011): caregiver status-update
  // image/video attachment.
  media_url: string | null;
  media_content_type: string | null;
}

export interface MessagePreview {
  body_source: string;
  body_translated: string | null;
  language: string;
}

@Injectable({ providedIn: 'root' })
export class MessagesService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  list(episodeId: number): Promise<StaffMessage[]> {
    return firstValueFrom(this.http.get<StaffMessage[]>(`${this.apiOrigin}/api/v1/staff/episodes/${episodeId}/messages`));
  }

  preview(episodeId: number, payload: { templateKey?: string; bodySource?: string; language: string }): Promise<MessagePreview> {
    return firstValueFrom(
      this.http.post<MessagePreview>(`${this.apiOrigin}/api/v1/staff/episodes/${episodeId}/messages/preview`, {
        template_key: payload.templateKey,
        body_source: payload.bodySource,
        language: payload.language,
      }),
    );
  }

  send(episodeId: number, payload: { templateKey?: string; bodySource: string; bodyTranslated: string | null; language: string }): Promise<StaffMessage> {
    return firstValueFrom(
      this.http.post<StaffMessage>(`${this.apiOrigin}/api/v1/staff/episodes/${episodeId}/messages`, {
        template_key: payload.templateKey,
        body_source: payload.bodySource,
        body_translated: payload.bodyTranslated,
        language: payload.language,
      }),
    );
  }
}
