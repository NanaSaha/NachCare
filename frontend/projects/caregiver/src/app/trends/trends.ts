import { ChangeDetectionStrategy, Component, OnInit, computed, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslatePipe } from '@ngx-translate/core';
import { TrendChart, TrendPoint } from 'shared';
import { TrendsData, TrendsService } from './trends.service';

@Component({
  selector: 'app-trends',
  imports: [ RouterLink, TranslatePipe, TrendChart ],
  templateUrl: './trends.html',
  styleUrl: './trends.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Trends implements OnInit {
  private readonly trendsService = inject(TrendsService);

  readonly data = signal<TrendsData | null>(null);
  readonly loading = signal(true);

  readonly weightPoints = computed<TrendPoint[]>(() =>
    (this.data()?.points ?? []).map((p) => ({ label: p.effective_date, value: p.weight_kg ? parseFloat(p.weight_kg) : null }))
  );

  readonly symptomPoints = computed<TrendPoint[]>(() =>
    (this.data()?.points ?? []).map((p) => ({ label: p.effective_date, value: p.symptom_count }))
  );

  readonly adherencePoints = computed<TrendPoint[]>(() =>
    (this.data()?.points ?? []).map((p) => ({ label: p.effective_date, value: p.adherence_pct }))
  );

  async ngOnInit(): Promise<void> {
    this.data.set(await this.trendsService.get());
    this.loading.set(false);
  }
}
