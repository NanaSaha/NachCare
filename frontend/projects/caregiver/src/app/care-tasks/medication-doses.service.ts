import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface CareTask {
  medication_id: number;
  medication_name: string;
  critical: boolean;
  instructions: string | null;
  scheduled_date: string;
  scheduled_time: string;
  status: 'pending' | 'taken' | 'missed';
  dose_id: number | null;
  taken_at: string | null;
}

export interface CareTasksData {
  date: string;
  tasks: CareTask[];
}

/**
 * Caregiver requirement #3/#5 (post-M7, ADR-0010): "today's care tasks" —
 * one scheduled-dose slot per medication per time, independent of the
 * once-daily check-in wizard.
 */
@Injectable({ providedIn: 'root' })
export class MedicationDosesService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  getToday(): Promise<CareTasksData> {
    return firstValueFrom(this.http.get<CareTasksData>(`${this.apiOrigin}/api/v1/caregiver/medication_doses`));
  }

  // Response shape is the persisted dose row, not a full CareTask — the
  // component re-fetches `getToday()` after marking so the list stays a
  // single source of truth rather than hand-merging a partial response.
  mark(medicationId: number, scheduledDate: string, scheduledTime: string, status: 'taken' | 'missed'): Promise<{ id: number; status: string; taken_at: string | null }> {
    return firstValueFrom(
      this.http.post<{ id: number; status: string; taken_at: string | null }>(`${this.apiOrigin}/api/v1/caregiver/medication_doses`, {
        medication_id: medicationId, scheduled_date: scheduledDate, scheduled_time: scheduledTime, status,
      })
    );
  }
}
