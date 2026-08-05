import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { DatePipe } from '@angular/common';
import { ReactiveFormsModule, FormControl, FormGroup, Validators } from '@angular/forms';
import { TranslatePipe } from '@ngx-translate/core';
import { EnrollmentService, Drug, EnrollmentResult } from './enrollment.service';

const NYHA_CLASSES = [ 'I', 'II', 'III', 'IV' ] as const;
const LANGUAGES = [ 'en', 'de', 'tr', 'ru', 'ar' ] as const;
const MEDICATION_SEARCH_DEBOUNCE_MS = 200;

@Component({
  selector: 'app-enrollment',
  imports: [ ReactiveFormsModule, TranslatePipe, DatePipe ],
  templateUrl: './enrollment.html',
  styleUrl: './enrollment.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Enrollment {
  private readonly enrollmentService = inject(EnrollmentService);

  readonly nyhaClasses = NYHA_CLASSES;
  readonly languages = LANGUAGES;

  readonly form = new FormGroup({
    initials: new FormControl('', { nonNullable: true, validators: [ Validators.required ] }),
    birthYear: new FormControl<number | null>(null, {
      validators: [ Validators.required, Validators.min(1900), Validators.max(new Date().getFullYear()) ],
    }),
    nyhaClass: new FormControl<(typeof NYHA_CLASSES)[number]>('II', { nonNullable: true }),
    displayName: new FormControl('', { nonNullable: true, validators: [ Validators.required ] }),
    relationship: new FormControl('', { nonNullable: true, validators: [ Validators.required ] }),
    language: new FormControl<(typeof LANGUAGES)[number]>('en', { nonNullable: true }),
  });

  readonly medications = signal<string[]>([]);
  readonly medicationQuery = signal('');
  readonly medicationMatches = signal<Drug[]>([]);
  private medicationSearchTimer?: ReturnType<typeof setTimeout>;

  readonly submitting = signal(false);
  readonly error = signal<string | null>(null);
  readonly result = signal<EnrollmentResult | null>(null);

  onMedicationQueryChange(query: string): void {
    this.medicationQuery.set(query);
    clearTimeout(this.medicationSearchTimer);
    this.medicationSearchTimer = setTimeout(() => {
      this.enrollmentService.searchDrugs(query).then((drugs) => this.medicationMatches.set(drugs));
    }, MEDICATION_SEARCH_DEBOUNCE_MS);
  }

  addMedication(name: string): void {
    const trimmed = name.trim();
    if (!trimmed || this.medications().includes(trimmed)) return;

    this.medications.update((meds) => [ ...meds, trimmed ]);
    this.medicationQuery.set('');
    this.medicationMatches.set([]);
  }

  removeMedication(name: string): void {
    this.medications.update((meds) => meds.filter((m) => m !== name));
  }

  async submit(): Promise<void> {
    if (this.form.invalid) return;

    this.submitting.set(true);
    this.error.set(null);

    const raw = this.form.getRawValue();

    try {
      const result = await this.enrollmentService.enroll({
        patient: { initials: raw.initials, birth_year: raw.birthYear!, nyha_class: raw.nyhaClass },
        caregiver: { display_name: raw.displayName, relationship: raw.relationship, language: raw.language },
        medications: this.medications(),
      });
      this.result.set(result);
    } catch {
      this.error.set('enrollment.submitFailed');
    } finally {
      this.submitting.set(false);
    }
  }

  async downloadCodeSheet(): Promise<void> {
    const r = this.result();
    if (!r) return;

    const blob = await this.enrollmentService.downloadCodeSheet(
      r.episode.id, r.activation_code.code, r.activation_code.role, r.activation_code.expires_at
    );
    const url = URL.createObjectURL(blob);
    window.open(url, '_blank');
  }

  enrollAnother(): void {
    this.result.set(null);
    this.error.set(null);
    this.medications.set([]);
    this.form.reset({ nyhaClass: 'II', language: 'en' });
  }
}
