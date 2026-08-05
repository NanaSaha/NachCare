# ADR-0010: Post-M7 caregiver/nurse care-plan loop (nurse-authored instructions, medication schedule, voice playback, dose recording, realtime activity)

**Status:** Accepted
**Date:** 2026-08-03

## Context

The product owner requested a set of features directly on top of the finished
M0-M7 build (not part of the original playbook): the nurse authors home-care
instructions and a medication schedule in the cockpit; the caregiver sees all
of it, can hear it read aloud, can record activity against each scheduled
dose, and gets reminders per dose time; the nurse sees caregiver activity in
real time. Two things were already decided by the product owner before this
work started (not re-litigated here):

1. Discharge note / instructions are structured text authored directly in
   the cockpit — no file upload, no OCR/PDF pipeline.
2. Voice playback uses the browser-native Web Speech API
   (`window.speechSynthesis`), not a cloud TTS provider — zero new external
   dependency, no new subprocessor to document in `docs/SUBPROCESSORS.md`.

Everything else below is an engineering decision made per R9 (decide, ADR,
move on) since none of it is clinical content — it is either UI/data-shape
structure or reuses established patterns from ADR-0002 through ADR-0009.

## Decisions

### 1. `care_instructions`: a plain column on `care_plans`, same versioning/permission contract as `diet_rules`

Added via migration (`db/migrate/20260803180001_add_care_instructions_to_care_plans.rb`).
Not threshold-gated (`CarePlanPolicy#update_thresholds?` only gates
`thresholds`) — any `CarePlanPolicy::MANAGING_ROLES` member (ward_nurse
through sysadmin) can set it, exactly like `diet_rules`, per the task
instruction to match the existing `diet_rules` permission level rather than
the stricter `thresholds` one. Persisted through the existing
`CarePlansController#create` versioning flow (new row, previous
deactivated) — never mutated in place, consistent with every other
care-plan field.

### 2. Medication schedule JSON shape

`medications.schedule` (jsonb, existed unused since M0) now holds:

```json
{ "times": ["08:00", "20:00"], "instructions": "1 tablet with food" }
```

`times` is an array of `HH:MM` 24-hour strings (validated by
`Medication#schedule_shape_valid`, TDD'd per R10 since it's schedule-timing
logic); `instructions` is a short optional free-text dose note. Chosen over
a richer per-dose-object shape (e.g. `[{"time": "08:00", "note": "..."}]`)
because every dose slot on one medication shares the same instructions in
the common case ("1 tablet, with food" applies at both 08:00 and 20:00) —
keeping `instructions` singular avoids the UI needing to duplicate/sync text
across slots for no real benefit at this scope. Revisit to a per-slot shape
if a real case needs different instructions per time-of-day for the same
medication.

### 3. `CarePlansController#create`: medications now carry forward when omitted (bug fix, not new behavior)

Every other versioned field (`diet_rules`, `cadence`, `thresholds`) already
fell back to the previous active plan's value when the param was omitted
from a request. `medications` had no such fallback — `Array(params[:medications])`
was simply empty when the caller only sent (say) `{diet_rules: "..."}`,
silently dropping every medication off the new version. This was a latent
bug: the demo seed (`db/seeds/ingrid_scenario.rb`) creates its `CarePlan`
directly via `CarePlan.create!`, never through the controller, so no
existing test or manual walkthrough ever exercised "edit diet_rules after
medications already exist." It would have surfaced the moment a real nurse
edited diet rules on a patient with medications already on file. Fixed to
match the established fallback pattern: `params[:medications]` present ->
use it exclusively (full replace, the existing behavior for an explicit
edit); absent -> carry forward every medication (name, critical, drug_ref,
schedule) from the previous active plan onto the new version unchanged.
Covered by a new spec (`care_plans_spec.rb`, "carries forward existing
medications... when a nurse edits an unrelated field").

### 4. `medication_doses`: a new table, rows created lazily, never pre-populated

```
medication_doses: medication_ref, caregiver_ref, scheduled_date, scheduled_time,
                   taken_at (nullable), status (pending|taken|missed, default pending)
```

Per the task instruction's own steer: a row is created only when a caregiver
actually acts on a specific dose slot (`MedicationDosesController#create`,
`find_or_initialize_by(medication_ref:, scheduled_date:, scheduled_time:)`),
not pre-populated by a job at midnight or on schedule-save. The "today's
care tasks" list (`GET /api/v1/caregiver/medication_doses`) computes the
full set of scheduled slots from `Medication#schedule_times` for the
requested date and overlays whatever `MedicationDose` rows already exist —
an untouched slot simply has no row and reads as the virtual `pending`
state. This mirrors the "derive, don't pre-populate" posture ADR-0008 #2
already established for Learn's unlock-week computation. A unique index on
`(medication_ref, scheduled_date, scheduled_time)` makes the upsert
race-safe and is the same key the reminder job's "already resolved" check
uses.

Marking a dose is a POST upsert, not a strict create: re-marking the same
slot (e.g. correcting `missed` -> `taken`) updates the existing row rather
than erroring or duplicating, since real caregivers make and correct
mistakes and a hard one-shot-only endpoint would be actively hostile to
that. `medication_dose.recorded` was added to `AnalyticsEvent::TAXONOMY`
(closed list, ADR-0009 #2) — `Domain::Analytics::PilotMetrics` (ADR-0009 #1)
deliberately doesn't read this table, so extending the taxonomy carries no
metrics-definition risk, only makes the event available for future
event-level export/consumers, consistent with why the taxonomy mechanism
exists at all.

### 5. Caregiver requirement #1 ("sees all information") splits HomeController (extended) from two new dedicated screens, not a HomeController rewrite

`Api::V1::Caregiver::HomeController#show` gained `diet_rules`,
`care_instructions`, and each medication's full `schedule` (previously
`{id, name, critical}` only) — additive fields, so the existing check-in
wizard (which already fetches `HomeData` for its medications step) needed
no changes to keep working. Rather than restructuring the check-in wizard
itself (safety-tested M2 flow, real Playwright coverage, not worth the
regression risk for this scope), two new routed caregiver screens were
added following the exact pattern M6 established for `/trends`, `/learn`,
`/care-team` (standalone lazy-loaded routed component + its own service,
`deviceAuthGuard`):

- `/care-plan` — reads the same `HomeController` payload a second time (no
  new endpoint; `CheckInService.getHome()` reused) to render care
  instructions, diet rules, and medications-with-schedule, plus the voice
  button (decision #6). Linked from the check-in wizard's top (visible
  immediately on login, every step) and its post-submit nav bar.
- `/care-tasks` — reads the new `GET /api/v1/caregiver/medication_doses`
  endpoint (decision #4) for today's scheduled-dose list with mark
  taken/missed actions.

Splitting into two screens (rather than one combined "everything" screen)
follows the same information-scoping the app already uses elsewhere
(trends vs. learn vs. care-team are separate concerns, not one mega-page):
"what the nurse told you" (read-mostly, occasional reference) is a
different task from "what you need to do right now" (actionable, checked
multiple times a day).

### 6. Voice playback: a thin `VoiceService` wrapping `window.speechSynthesis` directly

`frontend/projects/caregiver/src/app/care-plan/voice.service.ts`. No new
package, no new subprocessor (product owner's decision, restated here per
the task instructions). `isSupported()` feature-detects
`'speechSynthesis' in window && typeof SpeechSynthesisUtterance !== 'undefined'`
so the play button is replaced with a plain unsupported-notice string
instead of rendering a dead button. `speak()` composes one utterance from
care instructions + diet rules + each medication's name/times/instructions
(built in `CarePlan.buildSpokenText()`, using translated label fragments via
`TranslateService.instant()` so the spoken text's connective phrases follow
the caregiver's chosen UI language, not just the underlying data).
`SpeechSynthesisUtterance.lang` is set from a small BCP-47 lookup table
(`en`->`en-US`, `de`->`de-DE`, etc.) — best effort only per the task
instructions, since actual voice availability is entirely up to the
browser/OS and this build has no way to guarantee a given language has an
installed voice.

### 7. Dose reminders: a second scheduled job, same shape as `DailyReminderJob`, not a generalization of it

`DoseReminderJob` (`backend/app/jobs/dose_reminder_job.rb`) reuses
`DailyReminderJob::QUIET_HOURS`/`WINDOW_MINUTES` directly rather than
extracting a shared base class — the two jobs' *iteration targets* differ
enough (caregivers-by-notification_time vs. care-plans-by-medication-
schedule-time) that a shared abstraction would mostly be indirection over
two nearly-disjoint bodies. Idempotency follows the exact strategy already
established: the job runs every `WINDOW_MINUTES` (10) via
`schedule.yml`'s cron cadence, and a given scheduled time's `due_now?`
window is also `WINDOW_MINUTES` wide — since the cron grid spacing equals
the window width, any single scheduled time's window contains exactly one
cron tick per day (pigeonhole), so no separate "already sent" tracking
table is needed, matching `DailyReminderJob`'s design exactly rather than
inventing a different mechanism for a structurally identical problem. A
dose already marked `taken` or `missed` (decision #4's table) suppresses
the reminder for that slot.

Payload: `Templates::BODIES["dose_reminder"]` — "Time for a scheduled task
in the app." (EN) / German `MACHINE_DRAFT`, TR/RU/AR EN-fallback, matching
every other kind's convention (ADR-0008 #7). Deliberately avoids not just
drug names/doses but also the words "medication" and "dose" themselves,
since both appear in `spec/domain/notifications/payload_minimization_spec.rb`'s
`FORBIDDEN_TERMS` list (R5) — "scheduled task" reads as generic as
`daily_reminder`'s "Time for today's check-in." `NotificationAttempt::KINDS`
and the payload-minimization spec's exact-kind-set assertion were both
extended to include it.

### 8. Realtime caregiver activity: a new `CareActivityChannel`/`Broadcaster`, one stream per episode (not per site)

Mirrors `FlagsChannel`/`Domain::Flags::Broadcaster` (M3) exactly in shape —
raw-attribute payloads over ActionCable, no presentation-layer coupling in
the domain broadcaster. Differs in fan-out scope: `FlagsChannel` streams
per *site* because the whole triage queue needs every flag at that site;
`CareActivityChannel` streams per *episode* because a patient-detail page
only ever cares about one patient's activity, and per-episode scoping keeps
the channel's own authorization check identical in spirit to
`PatientPolicy`/`CarePlanPolicy`'s `same_site?` gate without needing a
separate policy class — the channel loads the episode's patient and checks
`current_user.site_ref == site_id || sysadmin?` directly, matching every
other staff-side site-scoping check in the app.

`Domain::CareActivity::Broadcaster` builds two payload shapes
(`check_in_payload`, `dose_payload`) that `Domain::CareActivity::Feed`
(the *initial*, non-live fetch backing `PatientDetailBlueprint#recent_activity`)
reuses directly, so the cockpit's activity list renders identically whether
an item arrived live or from the page's first load — one payload builder,
two delivery paths, instead of maintaining two shapes that could drift.
Wired into `CheckInsController#create`/`#update` and
`MedicationDosesController#create` (decision #4) right after each already
persists its audit event, following the same "audit first, broadcast
after" ordering `Domain::Flags::Lifecycle` already uses.

No PHI-minimization constraint applies here (unlike decision #7's
caregiver-facing push payload, R5) — this channel is staff-only, gated the
same way the rest of the cockpit's patient data already is, and nurses
already see full clinical detail on this exact page (weight values, flag
severities, etc.) via the pre-existing `PatientDetailBlueprint`/triage
queue. Broadcasting a check-in's weight or a dose's medication name here is
consistent with everything else already on the page, not a new exposure.

#### 8a. Two pre-existing infrastructure bugs discovered and fixed while manually verifying this feature

Manual Puppeteer verification (real browser, real login, real dose-mark
action) initially showed the cockpit's live activity feed never updating
without a page reload. Root-caused to two separate, pre-existing bugs, both
unrelated to any code this phase wrote but both required to make *any*
ActionCable feature — including the already-shipped M3 triage-queue live
updates (`FlagsChannel`) — actually work in this environment:

1. **`ops/docker-compose.yml`'s persistent `backend` service hardcoded
   `WEB_CONCURRENCY: "10"`** (left over from ADR-0009 #9's k6 load-gate
   tuning). `config/puma.rb` explicitly documents this as opt-in ("unset
   outside the load-test invocation leaves this single-process"), but the
   compose file baked it into the *standing* dev/demo container's
   environment instead of scoping it to the load-test run. With 10 Puma
   worker processes, `config/cable.yml`'s `async` pubsub adapter — which
   only delivers a broadcast to WebSocket connections held by the *same*
   process that called `.broadcast` — meant a live update almost never
   reached the worker process actually holding a given client's cable
   connection. Fixed by removing `WEB_CONCURRENCY` from the persistent
   `backend` service's environment (reverting to Puma's documented
   single-process default); `RAILS_MAX_THREADS` left unchanged since
   thread count doesn't affect this. Re-running `ops/verify_m7.sh`'s k6
   load gate now needs `WEB_CONCURRENCY=10` supplied explicitly for that
   invocation — tracked in `docs/OPEN_DECISIONS.md`.
2. **`ApplicationCable::Connection#authenticate!` never stripped the
   `Bearer ` scheme prefix.** The cockpit's `TokenStore` correctly stores
   the *entire* `Authorization` response header value devise-jwt issues —
   `"Bearer <jwt>"` — because that's exactly what `HttpClient`'s
   Authorization header needs. But every `connect()` call site that opens
   a cable connection (`FlagsLiveService`, and this phase's
   `CareActivityLiveService`, both modeled on the same pattern) passes
   that same stored value as the cable URL's `token` query param, and
   `Warden::JWTAuth::TokenDecoder`/`JWT.decode` cannot parse a
   `Bearer `-prefixed string — every cable connection was silently
   rejected as unauthorized (`{"type":"disconnect","reason":"unauthorized"}`),
   confirmed directly via Chrome DevTools Protocol WebSocket-frame
   inspection. Fixed centrally in `ApplicationCable::Connection`
   (`request.params[:token].to_s.sub(/\ABearer /, "")`), matching the
   identical `.sub(/\ABearer /, "")` pattern `CaregiverAuthenticatable`
   already uses on the HTTP path — one fix covers every existing and
   future `connect()` call site rather than requiring each frontend
   service to strip the prefix itself. Regression-guarded by
   `spec/channels/application_cable/connection_spec.rb` (new — no
   connection-level spec existed before), which explicitly asserts a
   `Bearer `-prefixed token connects successfully, not just a bare one.

Both fixes were necessary to make this phase's "nurse sees realtime
caregiver updates" requirement genuinely true, and both also silently
repair the pre-existing M3 triage-queue live-update feature
(`docs/TRACEABILITY.md`'s triage-queue row claimed "Done" including "live
updates" — that claim was accurate for the mechanism's *code*, but neither
bug would have been caught by the existing test suite, since no prior spec
exercised a real authenticated WebSocket connection end-to-end; RSpec's
channel specs test `subscribed`/`stream_from` behavior directly against a
`TestConnection`, bypassing real JWT-string parsing entirely, and no
Playwright e2e spec asserts a live push arrives without a reload). Verified
end-to-end via Puppeteer after both fixes: a caregiver's real "mark dose
taken" button click, hitting the real running dev backend, appeared in the
cockpit's "Recent caregiver activity" list within ~1 second, on an
already-open page, with zero reload — see the manual-verification section
of the final report for the exact repro steps.

### 9. Blueprint/API additions are additive; no breaking changes to existing shapes

`PatientDetailBlueprint`'s `care_plan.medications` gained `drug_id` (needed
so the cockpit's schedule-save round-trip doesn't silently drop each
medication's link to the seeded drug catalog when resubmitting the full
medications array — see decision #3's "explicit array replaces wholesale"
behavior) and `schedule`; `HomeController`'s `medications` gained
`schedule`. Both existing response shapes only gained fields, and existing
request specs asserting *subsets* of the JSON (not exact-shape) needed no
changes beyond the one place (`home_spec.rb`) that did assert an exact
`contain_exactly` match, which was updated in place.

## Consequences

- Two new backend migrations (`20260803180001`, `20260803180002`), applied
  to both `development` and `test` via `db:migrate` / `db:test:prepare`,
  `db/structure.sql` regenerated and verified to contain both changes.
- New backend surface: `MedicationDose` model, `MedicationDosesController`,
  `DoseReminderJob`, `CareActivityChannel`, `Domain::CareActivity::{Broadcaster,Feed}`.
  New frontend surface: cockpit `care-activity-live.service.ts` +
  `patient-detail` extensions; caregiver `care-plan/` and `care-tasks/`
  screens + `voice.service.ts` + `medication-doses.service.ts`.
- No new `docs/OPEN_CLINICAL_ITEMS.md` row: every piece of new user-facing
  copy here is either ordinary operational app chrome (button labels,
  status words) or nurse/caregiver-authored real content, not
  system-authored clinical-shaped copy — consistent with the task
  instructions' R1 calibration note.
- Full backend suite: 484 examples, 0 failures (was 439 before this work);
  rubocop clean (334 files); brakeman clean (0 warnings, 1 pre-existing
  ignored Rails-EOL entry, unchanged). All three Angular projects
  (`caregiver`, `cockpit`, `shared`) build/lint/test clean.
- `docs/OPEN_DECISIONS.md` gets one new row: re-running the k6 load gate
  needs `WEB_CONCURRENCY=10` supplied explicitly now that it's no longer
  baked into the persistent `backend` service's environment (decision #8a).
