import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface GateEvaluation {
  detection_lead_time_median_days: number | null;
  detection_lead_time_sample_size: number;
  detection_lead_time_met: boolean;
  alert_rate_per_patient_day: number | null;
  alert_rate_sample_checkins: number;
  alert_rate_met: boolean;
  missed_reds_count: number;
  missed_reds_total_reds: number;
  missed_reds_met: boolean;
  overall_met: boolean;
  insufficient_data: boolean;
}

export interface PromotionRecord {
  id: number;
  version: number;
  gates_met: boolean;
  override: boolean;
  promoted: boolean;
  gate_results: GateEvaluation;
  decided_by: number;
  created_at: string;
}

export interface RiskModelStatus {
  site_id: number;
  promoted: boolean;
  gate_evaluation: GateEvaluation;
  history: PromotionRecord[];
}

// UC-21: MD/ADM-gated shadow-model promotion. `show` is read-only (safe
// to call repeatedly); `promote` always re-evaluates the gates
// server-side, never trusts a client-sent verdict.
@Injectable({ providedIn: 'root' })
export class RiskModelService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  status(siteId: number): Promise<RiskModelStatus> {
    return firstValueFrom(this.http.get<RiskModelStatus>(`${this.apiOrigin}/api/v1/staff/sites/${siteId}/risk_model`));
  }

  promote(siteId: number, override: boolean): Promise<PromotionRecord> {
    return firstValueFrom(
      this.http.post<PromotionRecord>(`${this.apiOrigin}/api/v1/staff/sites/${siteId}/risk_model/promote`, { override })
    );
  }
}
