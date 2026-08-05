import { ChangeDetectionStrategy, Component, OnInit, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { TranslatePipe } from '@ngx-translate/core';
import { AnalyticsService, PilotMetrics } from './analytics.service';

/** AN-1 pilot metrics dashboard + FR-N12 CSV/PDF export (Section 8/M7). */
@Component({
  selector: 'app-analytics-dashboard',
  imports: [ FormsModule, TranslatePipe ],
  templateUrl: './analytics-dashboard.html',
  styleUrl: './analytics-dashboard.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AnalyticsDashboard implements OnInit {
  private readonly analyticsService = inject(AnalyticsService);

  readonly metrics = signal<PilotMetrics | null>(null);
  readonly loading = signal(true);
  readonly exporting = signal<'csv' | 'pdf' | null>(null);
  readonly error = signal(false);

  readonly from = signal(this.isoDaysAgo(30));
  readonly to = signal(this.isoDaysAgo(0));

  async ngOnInit(): Promise<void> {
    await this.reload();
  }

  async reload(): Promise<void> {
    this.loading.set(true);
    this.error.set(false);
    try {
      this.metrics.set(await this.analyticsService.pilotMetrics({ from: this.from(), to: this.to() }));
    } catch {
      this.error.set(true);
    } finally {
      this.loading.set(false);
    }
  }

  asPercent(rate: number | null): string {
    return rate === null ? '—' : `${Math.round(rate * 100)}%`;
  }

  asMinutes(minutes: number | null): string {
    return minutes === null ? '—' : `${Math.round(minutes)} min`;
  }

  async export(format: 'csv' | 'pdf'): Promise<void> {
    this.exporting.set(format);
    try {
      const blob = await this.analyticsService.exportBlob(format, { from: this.from(), to: this.to() });
      const url = URL.createObjectURL(blob);
      const link = document.createElement('a');
      link.href = url;
      link.download = `nachcare-pilot-metrics.${format}`;
      link.click();
      URL.revokeObjectURL(url);
    } finally {
      this.exporting.set(null);
    }
  }

  private isoDaysAgo(days: number): string {
    const date = new Date();
    date.setDate(date.getDate() - days);
    return date.toISOString().slice(0, 10);
  }
}
