import { ChangeDetectionStrategy, Component, OnDestroy, OnInit, computed, effect, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslatePipe } from '@ngx-translate/core';
import { SeverityIndicator, SeverityLevel } from 'shared';
import { FlagsService, FlagSummary, KpiSummary } from './flags.service';
import { FlagsLiveService } from './flags-live.service';

@Component({
  selector: 'app-triage-queue',
  imports: [ RouterLink, TranslatePipe, SeverityIndicator ],
  templateUrl: './triage-queue.html',
  styleUrl: './triage-queue.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class TriageQueue implements OnInit, OnDestroy {
  private readonly flagsService = inject(FlagsService);
  private readonly flagsLive = inject(FlagsLiveService);

  readonly flags = signal<FlagSummary[]>([]);
  readonly kpi = signal<KpiSummary | null>(null);
  readonly loading = signal(true);
  readonly stateFilter = signal<string | undefined>(undefined);

  // UC-23 step 5: AI WATCH lives in its own dedicated section below
  // reds/yellows, never mixed into the rules-driven queue list.
  readonly rulesFlags = computed(() => this.flags().filter((f) => f.subtype !== 'ai_watch'));
  readonly watchFlags = computed(() => this.flags().filter((f) => f.subtype === 'ai_watch'));

  constructor() {
    // Live queue updates: patch the matching row, or re-fetch if it's a
    // flag we don't have yet (new one just opened).
    effect(() => {
      const update = this.flagsLive.lastUpdate();
      if (!update) return;

      const exists = this.flags().some((f) => f.id === update.id);
      if (exists) {
        this.flags.update((list) =>
          list.map((f) => (f.id === update.id ? { ...f, ...update } as FlagSummary : f))
        );
      } else {
        this.refresh();
      }
    });
  }

  async ngOnInit(): Promise<void> {
    await this.refresh();
    this.flagsLive.connect();
  }

  ngOnDestroy(): void {
    this.flagsLive.disconnect();
  }

  async refresh(): Promise<void> {
    this.loading.set(true);
    const [ flags, kpi ] = await Promise.all([ this.flagsService.list(this.stateFilter()), this.flagsService.summary() ]);
    this.flags.set(flags);
    this.kpi.set(kpi);
    this.loading.set(false);
  }

  setFilter(state: string | undefined): void {
    this.stateFilter.set(state);
    this.refresh();
  }

  asSeverity(s: string): SeverityLevel {
    return s as SeverityLevel;
  }

  slaMinutesRemaining(flag: FlagSummary): number | null {
    if (!flag.sla_deadline_at) return null;
    return Math.round((new Date(flag.sla_deadline_at).getTime() - Date.now()) / 60000);
  }
}
