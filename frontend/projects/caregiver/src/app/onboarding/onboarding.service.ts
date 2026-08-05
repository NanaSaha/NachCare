import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface OnboardingPayload {
  language?: string;
  notification_time?: string;
  pin?: string;
  consents?: Record<'a' | 'b' | 'c' | 'd', boolean>;
}

@Injectable({ providedIn: 'root' })
export class OnboardingService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  complete(payload: OnboardingPayload): Promise<unknown> {
    return firstValueFrom(this.http.patch(`${this.apiOrigin}/api/v1/caregiver/onboarding`, payload));
  }
}
