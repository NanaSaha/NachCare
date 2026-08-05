import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export type CarePlanItemType = 'medication' | 'care_instructions' | 'diet_rules';

export interface CarePlanExplanation {
  text: string;
  source: 'ai' | 'template';
}

// Product-owner feedback item #1 (post-M7, ADR-0013): "tap a task/
// medication/note on Home, get an AI explanation." Talks to a dedicated
// backend endpoint (Domain::Ai::Tasks::ExplainCarePlanItem) grounded in
// the caregiver's own structured care-plan data — not the general
// free-text assistant, which depends on fuzzy knowledge-base retrieval
// and isn't the right tool for "explain this specific already-prescribed
// item" (see backend ADR-0013 for the full reasoning).
@Injectable({ providedIn: 'root' })
export class CarePlanExplanationService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  explain(itemType: CarePlanItemType, itemId?: number): Promise<CarePlanExplanation> {
    return firstValueFrom(
      this.http.post<CarePlanExplanation>(`${this.apiOrigin}/api/v1/caregiver/care_plan/explain`, {
        item_type: itemType,
        ...(itemId !== undefined ? { item_id: itemId } : {}),
      })
    );
  }
}
