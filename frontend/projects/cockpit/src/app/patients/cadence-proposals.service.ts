import { HttpClient } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';

export interface CadenceProposal {
  id: number;
  direction: 'taper' | 'densify';
  proposed_cadence: Record<string, unknown>;
  rationale: string | null;
  status: 'pending' | 'approved' | 'dismissed';
  created_at: string;
}

// UC-24: post-promotion-only cadence-adaptation proposals. `list` also
// refreshes server-side (computes a fresh proposal if warranted) — safe
// to call on every patient-detail load.
@Injectable({ providedIn: 'root' })
export class CadenceProposalsService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);

  list(episodeId: number): Promise<CadenceProposal[]> {
    return firstValueFrom(
      this.http.get<CadenceProposal[]>(`${this.apiOrigin}/api/v1/staff/episodes/${episodeId}/cadence_proposals`)
    );
  }

  approve(episodeId: number, proposalId: number): Promise<{ proposal: CadenceProposal; care_plan_version: number }> {
    return firstValueFrom(
      this.http.post<{ proposal: CadenceProposal; care_plan_version: number }>(
        `${this.apiOrigin}/api/v1/staff/episodes/${episodeId}/cadence_proposals/${proposalId}/approve`, {}
      )
    );
  }

  dismiss(episodeId: number, proposalId: number): Promise<CadenceProposal> {
    return firstValueFrom(
      this.http.post<CadenceProposal>(`${this.apiOrigin}/api/v1/staff/episodes/${episodeId}/cadence_proposals/${proposalId}/dismiss`, {})
    );
  }
}
