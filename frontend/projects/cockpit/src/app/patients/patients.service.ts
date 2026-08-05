import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface PatientSummary {
  id: string;
  pseudonym_code: string;
  initials: string;
  birth_year: number;
  nyha_class: string;
  // UC-25: a direction only (never a raw score, R5) — null pre-promotion
  // (shadow mode enforced) or with insufficient score history yet.
  risk_trend: 'rising' | 'stable' | 'improving' | null;
}

export interface MedicationSchedule {
  times: string[];
  instructions?: string | null;
}

export interface MedicationSummary {
  id: number;
  name: string;
  critical: boolean;
  drug_id: number | null;
  schedule: MedicationSchedule | Record<string, never>;
}

export interface CarePlanSummary {
  id: number;
  version: number;
  active: boolean;
  diet_rules: string | null;
  care_instructions: string | null;
  thresholds: Record<string, unknown>;
  cadence: Record<string, unknown>;
  medications: MedicationSummary[];
}

export interface EpisodeMilestones {
  graduated_at?: string;
  graduated_by?: string;
  graduation_report?: string | null;
}

// Nurse requirement #3 (ADR-0010): initial/live "recent caregiver
// activity" entries — same shape the backend's ActionCable broadcast uses.
export interface CareActivityEntry {
  type: 'check_in' | 'medication_dose';
  id: number;
  episode_ref: number;
  occurred_at: string;
  effective_date?: string;
  weight_kg?: string | null;
  // Product-owner feedback item #2 (ADR-0011): caregiver's free-text
  // "how is she feeling today" answer + any attached photo/video URLs.
  note?: string | null;
  photo_urls?: string[];
  medication_name?: string;
  scheduled_date?: string;
  scheduled_time?: string;
  status?: string;
}

export interface PatientDetail extends PatientSummary {
  episodes: {
    id: number;
    status: string;
    start_date: string;
    care_plan: CarePlanSummary | null;
    eligible_for_graduation: boolean;
    milestones: EpisodeMilestones;
    recent_activity: CareActivityEntry[];
  }[];
}

@Injectable({ providedIn: 'root' })
export class PatientsService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  list(): Promise<PatientSummary[]> {
    return firstValueFrom(this.http.get<PatientSummary[]>(`${this.apiOrigin}/api/v1/staff/patients`));
  }

  get(id: string): Promise<PatientDetail> {
    return firstValueFrom(this.http.get<PatientDetail>(`${this.apiOrigin}/api/v1/staff/patients/${id}`));
  }

  updateCarePlan(
    episodeId: number,
    payload: {
      diet_rules?: string;
      care_instructions?: string;
      thresholds?: Record<string, unknown>;
      medications?: { name: string; critical: boolean; drug_id?: number | null; schedule?: MedicationSchedule }[];
    }
  ): Promise<CarePlanSummary> {
    return firstValueFrom(
      this.http.post<CarePlanSummary>(`${this.apiOrigin}/api/v1/staff/episodes/${episodeId}/care_plan`, payload)
    );
  }

  graduate(episodeId: number): Promise<{ id: number; status: string; milestones: EpisodeMilestones }> {
    return firstValueFrom(
      this.http.post<{ id: number; status: string; milestones: EpisodeMilestones }>(
        `${this.apiOrigin}/api/v1/staff/episodes/${episodeId}/graduate`, {}
      )
    );
  }
}
