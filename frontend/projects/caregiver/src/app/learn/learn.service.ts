import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface ContentItemData {
  id: number;
  kind: 'article' | 'tip' | 'video';
  week_no: number;
  title: string | null;
  body: string | null;
  unlocked: boolean;
  completed: boolean;
}

@Injectable({ providedIn: 'root' })
export class LearnService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  list(): Promise<ContentItemData[]> {
    return firstValueFrom(this.http.get<ContentItemData[]>(`${this.apiOrigin}/api/v1/caregiver/content_items`));
  }

  complete(id: number): Promise<ContentItemData> {
    return firstValueFrom(this.http.post<ContentItemData>(`${this.apiOrigin}/api/v1/caregiver/content_items/${id}/complete`, {}));
  }
}
