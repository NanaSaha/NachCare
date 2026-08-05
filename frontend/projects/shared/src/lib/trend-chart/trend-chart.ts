import { ChangeDetectionStrategy, Component, computed, input } from '@angular/core';
import { TranslatePipe } from '@ngx-translate/core';

export interface TrendPoint {
  label: string;
  value: number | null;
}

/**
 * Generic SVG-polyline line chart for the caregiver Trends screen
 * (Section 8/M6). Generalizes the hand-rolled sparkline pattern
 * `flag-detail.ts#sparklinePoints` already established in M3 — no
 * charting library dependency (ADR-0008 #6 formalizes this as the actual
 * decision behind Section 2's "pick one, ADR it" for ngx-echarts/
 * ng2-charts, which M3 never actually exercised).
 */
let nextGradientId = 0;

@Component({
  selector: 'lib-trend-chart',
  imports: [ TranslatePipe ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './trend-chart.html',
  styleUrl: './trend-chart.css',
})
export class TrendChart {
  readonly points = input.required<TrendPoint[]>();
  readonly width = input(300);
  readonly height = input(80);

  /** Unique per-instance id for the area-fill <linearGradient> — multiple
   * charts render on the same page (Trends screen), and SVG ids must be
   * unique for `fill="url(#id)"` to resolve reliably in every browser. */
  readonly gradientId = `trend-chart-fill-${nextGradientId++}`;

  readonly known = computed(() => this.points().filter((p) => p.value !== null) as { label: string; value: number }[]);

  readonly polylinePoints = computed(() => {
    const pts = this.points();
    const knownValues = this.known().map((p) => p.value);
    if (knownValues.length === 0) return '';

    const min = Math.min(...knownValues);
    const max = Math.max(...knownValues);
    const range = max - min || 1;
    const w = this.width();
    const h = this.height();
    const stepX = pts.length > 1 ? w / (pts.length - 1) : 0;

    return pts
      .map((p, i) => (p.value === null ? null : `${i * stepX},${h - ((p.value - min) / range) * h}`))
      .filter((p): p is string => p !== null)
      .join(' ');
  });

  /**
   * Purely visual: the same line closed down to the chart's baseline, so a
   * soft gradient area fill can render under it. Derived entirely from
   * `polylinePoints`/`height` — no new data source, no change to what the
   * component receives or renders as data.
   */
  readonly areaPoints = computed(() => {
    const line = this.polylinePoints();
    if (!line) return '';
    const h = this.height();
    const coords = line.split(' ');
    const firstX = coords[0].split(',')[0];
    const lastX = coords[coords.length - 1].split(',')[0];
    return `${firstX},${h} ${line} ${lastX},${h}`;
  });
}
