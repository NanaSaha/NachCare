import { ChangeDetectionStrategy, Component, OnInit, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslatePipe } from '@ngx-translate/core';
import { PatientsService, PatientSummary } from './patients.service';

// UC-25: rising sorts first (the "call before they become tomorrow's
// flags" cohort), then stable, then improving, then unknown (pre-
// promotion or insufficient history).
const TREND_RANK: Record<string, number> = { rising: 0, stable: 1, improving: 2 };

@Component({
  selector: 'app-patient-list',
  imports: [ RouterLink, TranslatePipe ],
  templateUrl: './patient-list.html',
  styleUrl: './patient-list.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class PatientList implements OnInit {
  private readonly patientsService = inject(PatientsService);

  readonly patients = signal<PatientSummary[]>([]);
  readonly loading = signal(true);
  readonly sortByRisk = signal(false);

  readonly sortedPatients = computed(() => {
    const list = this.patients();
    if (!this.sortByRisk()) return list;

    return [ ...list ].sort((a, b) => {
      const rankA = a.risk_trend ? TREND_RANK[a.risk_trend] : 3;
      const rankB = b.risk_trend ? TREND_RANK[b.risk_trend] : 3;
      return rankA - rankB;
    });
  });

  readonly showRiskColumn = computed(() => this.patients().some((p) => p.risk_trend !== null));

  async ngOnInit(): Promise<void> {
    this.patients.set(await this.patientsService.list());
    this.loading.set(false);
  }

  toggleSort(): void {
    this.sortByRisk.set(!this.sortByRisk());
  }
}
