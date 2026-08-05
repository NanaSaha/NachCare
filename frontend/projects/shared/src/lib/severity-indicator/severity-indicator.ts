import { ChangeDetectionStrategy, Component, input } from '@angular/core';
import { TranslatePipe } from '@ngx-translate/core';
import { SeverityLevel } from './severity-level';

/**
 * Renders a GREEN/YELLOW/RED severity as color + icon + text — never color
 * alone (NachCareAI_Agent_Build_Instructions.md Section 2 design tokens
 * note). Label text comes from the `severity.<level>` i18n key unless
 * overridden, per R7 (no hardcoded user-facing copy).
 */
@Component({
  selector: 'lib-severity-indicator',
  imports: [TranslatePipe],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './severity-indicator.html',
  styleUrl: './severity-indicator.css',
})
export class SeverityIndicator {
  readonly level = input.required<SeverityLevel>();
  readonly label = input<string | undefined>(undefined);
}
