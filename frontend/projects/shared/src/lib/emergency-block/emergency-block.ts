import { ChangeDetectionStrategy, Component } from '@angular/core';
import { TranslatePipe } from '@ngx-translate/core';

/**
 * R4: "The 112 emergency block renders on every alert screen and the
 * Care-team page as static markup, functional even if every API call and
 * the entire AI gateway is down." This component makes zero HTTP calls
 * and has zero inputs that depend on backend data — the phone number is a
 * hardcoded `tel:` link, not fetched, not computed. It must keep working
 * exactly the same when the assistant/AI gateway is fully degraded
 * (Domain::Ai::Tasks::Assistant's routed_to_nurse fallback) — the two are
 * intentionally decoupled: this block is not part of, or gated by, any
 * emergency-detection call.
 */
@Component({
  selector: 'lib-emergency-block',
  imports: [ TranslatePipe ],
  changeDetection: ChangeDetectionStrategy.OnPush,
  templateUrl: './emergency-block.html',
  styleUrl: './emergency-block.css',
})
export class EmergencyBlock {}
