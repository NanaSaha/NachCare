import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface CareTeamData {
  site_name: string;
}

@Injectable({ providedIn: 'root' })
export class CareTeamService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  get(): Promise<CareTeamData> {
    return firstValueFrom(this.http.get<CareTeamData>(`${this.apiOrigin}/api/v1/caregiver/care_team`));
  }
}
