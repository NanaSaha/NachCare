import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';
import { OfflineQueue } from './offline-queue';

export interface MedicationSchedule {
  times: string[];
  instructions: string | null;
}

export interface CaregiverMedication {
  id: number;
  name: string;
  critical: boolean;
  schedule: MedicationSchedule;
}

export interface HomeData {
  caregiver: { display_name: string; relationship: string; language: string; assistant_available?: boolean };
  // Caregiver requirement #1 (post-M7, ADR-0010): everything the nurse/dr
  // uploaded — diet rules, free-text home care instructions, and each
  // medication's full schedule (not just id/name/critical).
  diet_rules: string | null;
  care_instructions: string | null;
  medications: CaregiverMedication[];
  last_weight_kg: string | null;
  last_check_in_date: string | null;
}

export interface CheckInPayload {
  client_uuid: string;
  effective_date: string;
  weight_kg: number | null;
  symptoms: Record<string, boolean>;
  med_status: Record<string, 'taken' | 'missed'>;
  note: string;
}

export interface CheckInSubmitResult {
  check_in: { id: number };
  evaluation: { severity: 'green' | 'yellow' | 'red'; fired_rule_count: number } | null;
  // M2 gap fix: real AI-generated (or gracefully-degraded template) daily
  // brief on a green result — `null` for any non-green result (the
  // frontend already shows severity-specific static copy for those).
  brief: { text: string; source: 'ai' | 'template' } | null;
  // UC-23 step 4: signal only. All caregiver-facing calm-card copy lives
  // in frontend i18n — deliberately not AI-generated for this
  // highest-empathy-required surface.
  ai_watch: { opened: boolean } | null;
}

@Injectable({ providedIn: 'root' })
export class CheckInService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);
  private readonly offlineQueue = inject(OfflineQueue);

  getHome(): Promise<HomeData> {
    return firstValueFrom(this.http.get<HomeData>(`${this.apiOrigin}/api/v1/caregiver/home`));
  }

  async submit(payload: CheckInPayload): Promise<CheckInSubmitResult | 'queued'> {
    try {
      return await firstValueFrom(
        this.http.post<CheckInSubmitResult>(`${this.apiOrigin}/api/v1/caregiver/check_ins`, payload)
      );
    } catch {
      await this.offlineQueue.enqueue({ clientUuid: payload.client_uuid, payload, queuedAt: new Date().toISOString() });
      return 'queued';
    }
  }

  // Product-owner feedback item #2: photo/video attach on check-in. A
  // separate multipart request against the already-created check-in
  // (rather than folding the file into `submit()`'s JSON body) so the
  // offline-retry queue above stays untouched — if this upload fails
  // (e.g. connection drops right after the check-in itself succeeded),
  // it's simply not retried; the check-in itself is never blocked on it.
  async attachPhoto(checkInId: number, file: File): Promise<{ id: number; url: string } | null> {
    const form = new FormData();
    form.append('image', file);
    try {
      return await firstValueFrom(
        this.http.post<{ id: number; url: string }>(`${this.apiOrigin}/api/v1/caregiver/check_ins/${checkInId}/photos`, form)
      );
    } catch {
      return null;
    }
  }

  /** Called on app start / reconnect to flush anything IndexedDB is still holding. */
  async retryQueued(): Promise<void> {
    const items = await this.offlineQueue.all();
    for (const item of items) {
      try {
        await firstValueFrom(this.http.post(`${this.apiOrigin}/api/v1/caregiver/check_ins`, item.payload as CheckInPayload));
        await this.offlineQueue.dequeue(item.clientUuid);
      } catch {
        // still offline or still failing — leave it queued, try again next time
      }
    }
  }
}
