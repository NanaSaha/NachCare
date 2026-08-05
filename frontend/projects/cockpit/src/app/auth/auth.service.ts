import { HttpClient } from '@angular/common/http';
import { Injectable, computed, inject, signal } from '@angular/core';
import { API_ORIGIN } from 'shared';
import { firstValueFrom } from 'rxjs';
import { TokenStore } from './token-store';
import { StaffUser } from './staff-user';

@Injectable({ providedIn: 'root' })
export class AuthService {
  private readonly http = inject(HttpClient);
  private readonly apiOrigin = inject(API_ORIGIN);
  private readonly tokenStore = inject(TokenStore);

  readonly isAuthenticated = computed(() => this.tokenStore.token() !== null);
  readonly currentUser = signal<StaffUser | null>(null);

  async signIn(email: string, password: string, otpAttempt?: string): Promise<StaffUser> {
    const user: Record<string, string> = { email, password };
    if (otpAttempt) user['otp_attempt'] = otpAttempt;

    const response = await firstValueFrom(
      this.http.post<{ user: StaffUser }>(`${this.apiOrigin}/api/v1/staff/sign_in`, { user }, { observe: 'response' })
    );

    const token = response.headers.get('Authorization');
    if (!token) throw new Error('sign-in succeeded but no token was issued');
    this.tokenStore.set(token);
    this.currentUser.set(response.body!.user);

    return response.body!.user;
  }

  async signOut(): Promise<void> {
    await firstValueFrom(this.http.delete(`${this.apiOrigin}/api/v1/staff/sign_out`));
    this.tokenStore.clear();
    this.currentUser.set(null);
  }

  /** For a fresh page load where sign-in already happened in a prior session. */
  async loadCurrentUser(): Promise<StaffUser | null> {
    if (!this.tokenStore.token()) return null;
    if (this.currentUser()) return this.currentUser();

    const user = await firstValueFrom(this.http.get<StaffUser>(`${this.apiOrigin}/api/v1/staff/me`));
    this.currentUser.set(user);
    return user;
  }
}
