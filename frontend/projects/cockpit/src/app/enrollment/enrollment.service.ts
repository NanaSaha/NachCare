import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface Drug {
  id: number;
  name: string;
  category: string | null;
}

export interface EnrollmentResult {
  patient: { id: number; pseudonym_code: string; initials: string; birth_year: number; nyha_class: string };
  episode: { id: number; status: string; start_date: string };
  caregiver: { id: string; display_name: string; relationship: string; language: string };
  activation_code: { code: string; role: string; expires_at: string };
}

export interface EnrollmentPayload {
  patient: { initials: string; birth_year: number; nyha_class: string };
  caregiver: { display_name: string; relationship: string; language: string };
  medications: string[];
}

@Injectable({ providedIn: 'root' })
export class EnrollmentService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  searchDrugs(query: string): Promise<Drug[]> {
    if (!query.trim()) return Promise.resolve([]);
    return firstValueFrom(
      this.http.get<Drug[]>(`${this.apiOrigin}/api/v1/staff/drugs`, { params: { q: query } })
    );
  }

  enroll(payload: EnrollmentPayload): Promise<EnrollmentResult> {
    return firstValueFrom(
      this.http.post<EnrollmentResult>(`${this.apiOrigin}/api/v1/staff/enrollments`, payload)
    );
  }

  async downloadCodeSheet(episodeId: number, code: string, role: string, expiresAt: string): Promise<Blob> {
    return firstValueFrom(
      this.http.get(`${this.apiOrigin}/api/v1/staff/enrollments/${episodeId}/code_sheet`, {
        params: { code, role, expires_at: expiresAt },
        responseType: 'blob',
      })
    );
  }
}
