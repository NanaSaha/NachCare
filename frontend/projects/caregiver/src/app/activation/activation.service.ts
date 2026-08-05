import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';
import { DeviceTokenStore } from '../auth/device-token-store';

export interface CaregiverProfile {
  id: string;
  display_name: string;
  relationship: string;
  language: string;
  notification_time: string | null;
  episode_ref: number;
  pin_set: boolean;
}

@Injectable({ providedIn: 'root' })
export class ActivationService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);
  private readonly tokenStore = inject(DeviceTokenStore);

  async activate(code: string): Promise<CaregiverProfile> {
    const response = await firstValueFrom(
      this.http.post<{ device_token: string; caregiver: CaregiverProfile }>(
        `${this.apiOrigin}/api/v1/caregiver/activations`,
        { code }
      )
    );
    this.tokenStore.set(response.device_token);
    return response.caregiver;
  }
}
