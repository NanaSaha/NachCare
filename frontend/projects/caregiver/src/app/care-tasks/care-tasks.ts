import { ChangeDetectionStrategy, Component, OnInit, inject, signal } from '@angular/core';
import { RouterLink } from '@angular/router';
import { TranslatePipe } from '@ngx-translate/core';
import { CareTask, MedicationDosesService } from './medication-doses.service';

/**
 * Caregiver requirement #3/#5 (post-M7, ADR-0010): today's scheduled doses
 * (medication x time), independent of the once-daily check-in wizard's
 * single taken/missed toggle per medication.
 */
@Component({
  selector: 'app-care-tasks',
  imports: [ RouterLink, TranslatePipe ],
  templateUrl: './care-tasks.html',
  styleUrl: './care-tasks.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CareTasks implements OnInit {
  private readonly dosesService = inject(MedicationDosesService);

  readonly tasks = signal<CareTask[]>([]);
  readonly loading = signal(true);
  readonly marking = signal<string | null>(null); // `${medicationId}-${scheduledTime}` while a mark request is in flight
  readonly error = signal<string | null>(null);

  async ngOnInit(): Promise<void> {
    await this.refresh();
  }

  async refresh(): Promise<void> {
    this.loading.set(true);
    const data = await this.dosesService.getToday();
    this.tasks.set(data.tasks);
    this.loading.set(false);
  }

  taskKey(task: CareTask): string {
    return `${task.medication_id}-${task.scheduled_time}`;
  }

  async mark(task: CareTask, status: 'taken' | 'missed'): Promise<void> {
    const key = this.taskKey(task);
    this.marking.set(key);
    this.error.set(null);
    try {
      await this.dosesService.mark(task.medication_id, task.scheduled_date, task.scheduled_time, status);
      await this.refresh();
    } catch {
      this.error.set('careTasks.markFailed');
    } finally {
      this.marking.set(null);
    }
  }
}
