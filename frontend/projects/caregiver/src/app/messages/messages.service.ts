import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface CaregiverMessage {
  id: number;
  sender: string;
  body_source: string;
  body_translated: string | null;
  created_at: string;
  media_url: string | null;
  media_content_type: string | null;
}

@Injectable({ providedIn: 'root' })
export class MessagesService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  list(): Promise<CaregiverMessage[]> {
    return firstValueFrom(this.http.get<CaregiverMessage[]>(`${this.apiOrigin}/api/v1/caregiver/messages`));
  }

  // Product-owner feedback item #3: a caregiver-authored status update to
  // the care team, with an optional image/video attachment. `Message.
  // SENDERS` already included "caregiver" (M4/M5) but no caregiver-facing
  // endpoint existed to create one until now (Api::V1::Caregiver::
  // MessagesController#create, ADR-0011).
  send(bodySource: string, media: File | null): Promise<CaregiverMessage> {
    const form = new FormData();
    form.append('body_source', bodySource);
    if (media) form.append('media', media);

    return firstValueFrom(this.http.post<CaregiverMessage>(`${this.apiOrigin}/api/v1/caregiver/messages`, form));
  }
}
