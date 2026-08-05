import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface PilotMetrics {
  site_id: number;
  from: string;
  to: string;
  checkin_adherence_rate: number | null;
  red_flag_sla_compliance_rate: number | null;
  red_flag_median_time_to_first_action_minutes: number | null;
  program_completion_rate: number | null;
  assistant_safety_routing_rate: number | null;
}

/** AN-1 pilot metrics + FR-N12 export (Section 8/M7, ADR-0009). */
@Injectable({ providedIn: 'root' })
export class AnalyticsService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  pilotMetrics(range?: { from: string; to: string }): Promise<PilotMetrics> {
    const params = range ? `?from=${range.from}&to=${range.to}` : '';
    return firstValueFrom(this.http.get<PilotMetrics>(`${this.apiOrigin}/api/v1/staff/analytics/pilot_metrics${params}`));
  }

  /**
   * Fetched via HttpClient (not a plain `<a href>`/`window.open`): the
   * staff JWT is attached by `auth.interceptor.ts` to XHR/fetch requests
   * only, never to a bare browser navigation, so a direct link to this
   * endpoint would 401. The component turns the returned Blob into an
   * object URL and triggers the download itself.
   */
  exportBlob(format: 'csv' | 'pdf', range?: { from: string; to: string }): Promise<Blob> {
    const params = range ? `?from=${range.from}&to=${range.to}` : '';
    return firstValueFrom(
      this.http.get(`${this.apiOrigin}/api/v1/staff/analytics/pilot_metrics.${format}${params}`, { responseType: 'blob' })
    );
  }
}
