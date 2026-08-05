import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { Router } from '@angular/router';
import { TranslatePipe } from '@ngx-translate/core';
import { ActivationService } from './activation.service';

@Component({
  selector: 'app-activation',
  imports: [ FormsModule, TranslatePipe ],
  templateUrl: './activation.html',
  styleUrl: './activation.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Activation {
  private readonly activationService = inject(ActivationService);
  private readonly router = inject(Router);

  readonly code = signal('');
  readonly submitting = signal(false);
  readonly error = signal<string | null>(null);

  async submit(): Promise<void> {
    const cleaned = this.code().replace(/\s+/g, '');
    if (cleaned.length < 8) return;

    this.submitting.set(true);
    this.error.set(null);

    try {
      await this.activationService.activate(cleaned);
      this.router.navigateByUrl('/onboarding');
    } catch {
      this.error.set('activation.failed');
    } finally {
      this.submitting.set(false);
    }
  }
}
