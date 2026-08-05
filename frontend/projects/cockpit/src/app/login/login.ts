import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { ReactiveFormsModule, FormControl, FormGroup, Validators } from '@angular/forms';
import { Router } from '@angular/router';
import { TranslatePipe } from '@ngx-translate/core';
import { AuthService } from '../auth/auth.service';

@Component({
  selector: 'app-login',
  imports: [ ReactiveFormsModule, TranslatePipe ],
  templateUrl: './login.html',
  styleUrl: './login.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class Login {
  private readonly auth = inject(AuthService);
  private readonly router = inject(Router);

  readonly form = new FormGroup({
    email: new FormControl('', { nonNullable: true, validators: [ Validators.required, Validators.email ] }),
    password: new FormControl('', { nonNullable: true, validators: [ Validators.required ] }),
    otpAttempt: new FormControl('', { nonNullable: true }),
  });

  readonly submitting = signal(false);
  readonly error = signal<string | null>(null);

  async submit(): Promise<void> {
    if (this.form.invalid) return;

    this.submitting.set(true);
    this.error.set(null);

    const { email, password, otpAttempt } = this.form.getRawValue();

    try {
      await this.auth.signIn(email, password, otpAttempt || undefined);
      this.router.navigateByUrl('/triage');
    } catch {
      this.error.set('auth.signInFailed');
    } finally {
      this.submitting.set(false);
    }
  }
}
