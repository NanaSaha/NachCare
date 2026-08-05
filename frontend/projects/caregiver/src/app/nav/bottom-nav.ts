import { ChangeDetectionStrategy, Component, inject, signal } from '@angular/core';
import { toSignal } from '@angular/core/rxjs-interop';
import { NavigationEnd, Router, RouterLink, RouterLinkActive } from '@angular/router';
import { TranslatePipe } from '@ngx-translate/core';
import { filter, map } from 'rxjs';
import { DeviceTokenStore } from '../auth/device-token-store';

// Product-owner feedback item #3 (post-M7, ADR-0013): a persistent,
// thumb-reachable bottom tab bar so every authenticated screen is
// reachable from every other one — previously the only way to reach
// most of the app was a handful of pill links buried on the check-in
// result screen (now removed, see check-in.html), with no way back once
// the caregiver navigated away from it. Mobile-first PWA (390px
// viewport convention) -> bottom bar, not a desktop-style top nav (see
// cockpit's app.html for that pattern instead).
//
// 5 top-level tabs (the bar's own max per the design brief) + a "More"
// sheet for the remaining 2 real routes (Care Tasks, Learn) that don't
// carry their own weight as a top-level tab: Care Tasks duplicates most
// of what Home's medication list + Care Plan already show (ADR-0013
// explains the full reasoning), and Learn is a slower-cadence,
// once-a-week destination, not a daily one like Home/Care Plan/Trends/
// Assistant.
@Component({
  selector: 'app-bottom-nav',
  imports: [ RouterLink, RouterLinkActive, TranslatePipe ],
  templateUrl: './bottom-nav.html',
  styleUrl: './bottom-nav.css',
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class BottomNav {
  private readonly router = inject(Router);
  private readonly deviceTokenStore = inject(DeviceTokenStore);

  readonly moreOpen = signal(false);

  private readonly currentUrl = toSignal(
    this.router.events.pipe(
      filter((e): e is NavigationEnd => e instanceof NavigationEnd),
      map((e) => e.urlAfterRedirects)
    ),
    { initialValue: this.router.url }
  );

  // Pre-auth flows (activate/onboarding) never show the nav, even though
  // onboarding itself requires a device token (deviceAuthGuard) — the
  // route, not just the token, decides visibility here.
  readonly visible = () => {
    const url = this.currentUrl();
    const authed = this.deviceTokenStore.token() !== null;
    return authed && !url.startsWith('/activate') && !url.startsWith('/onboarding');
  };

  toggleMore(): void {
    this.moreOpen.update((v) => !v);
  }

  closeMore(): void {
    this.moreOpen.set(false);
  }
}
