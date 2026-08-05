import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';
import { TranslatePipe } from '@ngx-translate/core';

/**
 * The 90-day recovery journey, as a literal bridge/arc the patient's
 * progress travels along — "bridge-arc shows Day 0 of 90" at onboarding,
 * "the full bridge crossed" at day-90 graduation (product-owner use-case
 * catalogue). Purely presentational: takes a day count, draws an SVG arch
 * from a left tower (Day 0) to a right tower (Day `totalDays`), fills the
 * deck up to the current day, and places a marker at the traveller's
 * position — a checkmark/flag replaces the marker once crossed.
 *
 * The arch is one quadratic Bézier path (`ARC_P0` -> `ARC_P1` -> `ARC_P2`).
 * Both the muted track and the evergreen progress overlay share that path
 * with `pathLength="1"`, so the fill is a plain `stroke-dashoffset`
 * fraction — no chart library, no JS geometry beyond locating the marker
 * point on the same curve for its (x, y).
 */
@Component({
  selector: 'lib-bridge-arc',
  imports: [TranslatePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './bridge-arc.html',
  styleUrl: './bridge-arc.css',
})
export class BridgeArc {
  readonly currentDay = input.required<number>();
  readonly totalDays = input<number>(90);

  private static readonly P0 = { x: 24, y: 108 };
  private static readonly P1 = { x: 160, y: 18 };
  private static readonly P2 = { x: 296, y: 108 };

  readonly clampedDay = computed(() => Math.min(Math.max(this.currentDay(), 0), this.totalDays()));

  readonly progress = computed(() => (this.totalDays() > 0 ? this.clampedDay() / this.totalDays() : 0));

  readonly crossed = computed(() => this.clampedDay() >= this.totalDays());

  /** stroke-dashoffset for the progress overlay, expressed as a 0..1 fraction (pathLength="1" on the <path>). */
  readonly dashOffset = computed(() => 1 - this.progress());

  readonly markerPoint = computed(() => BridgeArc.pointOnQuadratic(this.progress()));

  private static pointOnQuadratic(t: number): { x: number; y: number } {
    const { P0, P1, P2 } = BridgeArc;
    const mt = 1 - t;
    return {
      x: mt * mt * P0.x + 2 * mt * t * P1.x + t * t * P2.x,
      y: mt * mt * P0.y + 2 * mt * t * P1.y + t * t * P2.y,
    };
  }
}
