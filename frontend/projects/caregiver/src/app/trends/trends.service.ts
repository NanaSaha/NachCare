import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface TrendPointData {
  effective_date: string;
  weight_kg: string | null;
  symptom_count: number;
  adherence_pct: number | null;
}

export interface TrendsData {
  window_days: number;
  points: TrendPointData[];
}

@Injectable({ providedIn: 'root' })
export class TrendsService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  get(): Promise<TrendsData> {
    return firstValueFrom(this.http.get<TrendsData>(`${this.apiOrigin}/api/v1/caregiver/trends`));
  }
}
