# ADR-0011: Second post-M7 feedback round (medication add/remove, check-in photo + free-text feeling, caregiver status updates with media, cross-app nurse alerts)

**Status:** Accepted
**Date:** 2026-08-03

## Context

Further live product-owner feedback on top of the finished M0-M7 build plus
ADR-0010's caregiver/nurse care-plan loop, four items:

1. Nurse still can't add a brand-new medication (or general treatment plan
   was unclear).
2. Caregivers need to attach a picture/file to a check-in and answer "how
   is she feeling today" in free text, additively — not replacing the
   structured symptom toggles that feed the deterministic escalation
   engine (R2).
3. Caregivers need to send a status update (with an optional image/video)
   to the care team — `Message.SENDERS` already listed `"caregiver"`
   (M4/M5) but no caregiver-facing endpoint/UI existed to create one.
4. Nurses get no in-app alert when a caregiver acts, unless they already
   happen to have the exact right patient-detail page open.

Two decisions were fixed before this work started by the orchestrating
agent (not re-litigated here): item #2 is additive-only relative to the
symptom toggles (never feeds the deterministic engine via LLM inference of
free text), and item #4 must be a real cross-app channel, not the existing
per-episode `CareActivityChannel` alone. Everything else below is an
engineering decision made per R9.

## Decisions

### 1. "Add medication": no backend change, client-side temp ids + validation

`CarePlansController#create` already replaces the full medication list
whenever `medications` is present (ADR-0010 decision #3's carry-forward
fix), keyed by name, never by id. The cockpit's `saveSchedules()` already
sends the full `medicationDrafts()` array on every save. So "add
medication" is purely a frontend change:
`patient-detail.ts#addMedication()` appends a draft with a **negative,
decrementing client-side id** (`nextTempMedicationId`, starting at -1) —
negative so it can never collide with a real (positive) medication id from
the API, dropped automatically once the save round-trips and drafts are
rebuilt from the server's response. `removeMedication(id)` filters the
draft out client-side; if it was never saved, nothing to tell the backend.

The medication-schedule list previously rendered `med.name`/`med.critical`
as static text — there was no way to *set* a name for a newly-added blank
draft. Both are now editable inputs for every row, not just new ones
(`updateName`/`updateCritical`), for consistency.

One real risk: the backend creates each medication via `create!` (bang),
which raises `ActiveRecord::RecordInvalid` — not a clean 422 — on a blank
name, and that exception isn't rescued anywhere in
`CarePlansController#create`. Rather than change well-tested backend
behavior for this, `hasInvalidMedication` (a computed signal checking
every draft has a non-blank name) disables the save button and shows
`patients.carePlan.medicationNameRequired` client-side first.

`patients.carePlan.careInstructions` label/placeholder (ADR-0010's
`care_instructions` field) was reworded from "Home care instructions" to
"Home care instructions & general treatment plan" (EN+DE) — the field
already covered this in substance (its placeholder already mentioned
daily routine, warning signs, when to call the team), the product owner's
complaint was that the label undersold it as diet-adjacent, not that the
underlying field was missing.

### 2a. Check-in photo/video: `CheckInPhoto` model, `has_one_attached`, reusing the existing join table — a second, separate upload request, not folded into check-in JSON

The `check_in_photos` table (Section 5, present since M0, previously
unused) was clearly meant as the record ActiveStorage attaches to, not a
column on `check_ins` itself. `CheckInPhoto belongs_to :check_in,
has_one_attached :image` — one row per attachment, so a check-in can carry
zero, one, or (future) several without another schema change; this pass's
UI only ever creates one. `CheckIn has_many :check_in_photos`.

The upload is `POST /api/v1/caregiver/check_ins/:check_in_id/photos`
(multipart), a **separate request fired after** the existing
`POST /api/v1/caregiver/check_ins` (JSON) succeeds — not a single combined
multipart submission. This was deliberate: the existing check-in submit
flow has a real IndexedDB offline-retry queue (`offline-queue.ts`,
FR-C15) built around a plain JSON payload; folding a `File` into that
payload would mean either serializing binary data into IndexedDB (real
complexity, real failure modes for a 3-minute daily flow) or giving the
photo attach its own bespoke offline path. Instead, the check-in itself
(the safety-relevant part — weight, symptoms, meds) stays exactly as
robust as before; the photo attach is explicitly best-effort against an
already-guaranteed-persisted check-in id, and if it fails (including
"never got the network back"), the check-in itself was never at risk.
This is a real, honestly-scoped limitation: a caregiver who submits a
check-in while fully offline and never reopens the app before the queue
retries will not get another chance to attach that day's photo. Acceptable
given the alternative complexity for a first pass.

Both `CheckInPhoto#image` and `Message#media` (decision #3) share the same
validation shape: an allowlist of image/video content types
(`image/jpeg`, `image/png`, `image/webp`, `image/heic`, `image/heif`,
`video/mp4`, `video/quicktime`, `video/webm`) and a 25MB size cap — a
pragmatic default (not from any spec), documented here rather than as a
`PLACEHOLDER_CLINICAL` item since it's an ordinary engineering safety
limit, not clinical content.

### 2b. Free-text "how is she feeling today": reuses `check_ins.note`, no migration

`check_ins.note` already existed (M2, encrypted, optional) and the
caregiver check-in wizard already had a "note" step. Rather than adding a
new column, the existing field is reused and the step's copy reworded —
EN: "In your own words, how is she feeling today?" (was "Anything else to
mention?") — making it explicit this *is* the free-text answer to that
question, positioned as the additive alternative right after the
structured symptom-toggle step, not a replacement for it.

This is safe by construction, not just by convention: `note` already
flows into `Domain::Escalation::ContextBuilder#build` as `note_text`, and
`Domain::Escalation::Engine#red_flag_phrases?` already does a pure,
deterministic substring match against `Ruleset#red_flag_phrases` (R-10) —
no LLM involved, already existed before this work, untouched by it. No
other rule reads `note_text`. Since this change relabels an existing
field's UI copy rather than adding a new data path, R2 (escalation engine
stays deterministic/LLM-free) and the task's explicit "do NOT have an LLM
infer symptom booleans from the free text" instruction are both satisfied
by inspection — there is no new code path for the free text to reach the
engine through, and none was added.

Nurse-facing exposure: `FlagDetailBlueprint#check_in_history` gained
`note` and `photo_urls` fields (this is exactly the M3 traceability note's
"photos not yet implemented (ActiveStorage attachment endpoint deferred)"
gap). `Domain::CareActivity::Broadcaster#check_in_payload` (ADR-0010) also
gained the same two fields, so the patient-detail activity feed — reached
without needing an active flag/escalation — is a second, easier-to-verify
surface for the same data, live and on initial load
(`Domain::CareActivity::Feed` reuses the same payload builder).

One real ordering wrinkle: the photo attach (decision #2a) happens in a
request *after* the check-in's own `check_in!` broadcast has already
fired (the payload at that point has no photos yet, since none exist).
`CheckInPhotosController#create` re-broadcasts `check_in!` (with
`check_in.check_in_photos.reload` first) once the photo attach succeeds —
same `type`+`id`, so the cockpit's live feed replaces the entry in place
(it already dedupes on `type`+`id`, from ADR-0010) rather than showing a
duplicate. A nurse with the patient-detail page open at the moment of
submission sees the check-in appear first, then update in place a moment
later with the photo — an accurate reflection of what actually happened.

### 3. Caregiver-authored status update: `Message#media` (`has_one_attached`, directly on the row, no join model)

Unlike check-in photos, a message needs at most one attachment, so
`has_one_attached :media` lives directly on `Message` — no
`CheckInPhoto`-style join model needed; ActiveStorage's own polymorphic
`active_storage_attachments`/`blobs` tables are the only new storage this
requires (zero new migrations for both #2 and #3 — every table already
existed).

`Api::V1::Caregiver::MessagesController#create` (new — the controller was
previously index-only) accepts multipart `body_source` + optional
`media`, always `sender: "caregiver"`. `Message#body_source` presence
validation is now conditional (`if: -> { !media.attached? }`) — a status
update can be media-only (e.g. just a photo, no caption), matching the
product owner's literal ask ("upload images or videos... as a status
update"), but a message with neither text nor media is still rejected.

No Pundit `authorize` call here, matching every other caregiver
controller (`CheckInsController`, `MedicationDosesController`,
`CheckInPhotosController`) — caregivers authenticate via device token
(`CaregiverAuthenticatable`), a completely separate mechanism from staff's
Devise/JWT + Pundit, and every existing caregiver endpoint already scopes
strictly to `current_caregiver.episode` instead of a policy object.

Caregiver UI: a "Send an update to your care team" composer added to the
existing `/care-team` page (ADR-0008 established this route; its existing
`careTeam.messageHint` copy already told caregivers "you can message your
care team..." with nothing actually behind it before now — reworded to
reflect where messages *from* the team appear, since sending now lives
right below it on the same page). Nurse-facing: `MessageBlueprint` gained
`media_url`/`media_content_type`; `patient-detail.html`'s existing
`message-history` list renders an `<img>` or `<video controls>` tag based
on content type.

Scoped down, stated honestly: the caregiver check-in wizard's own
"Messages from your care team" panel (`check-in.html`, read-only, nurse
messages) was **not** updated to render media thumbnails — a caregiver's
own sent status update (with photo) would show as text-only there if
viewed from that panel. The primary, verified path for sending is the
`/care-team` composer; this is a minor secondary-surface gap, not a
functional one (the message and its media are genuinely persisted and
visible to the nurse either way).

### 4. Cross-app nurse alert: `NurseAlertsChannel`, one stream per **site** (not per user), thin non-clinical payload, session-only unread count

Mirrors `Domain::Flags::Broadcaster`/`FlagsChannel` (M3) in shape exactly
— site-scoped stream (`nurse_alerts_site_#{site_ref}`), same defensive
`reject unless site_id` (matching FlagsChannel's existing behavior for a
hypothetical no-site user, e.g. sysadmin, even though in practice
`User belongs_to :site` is required and every real user has one) — rather
than `CareActivityChannel`'s per-*episode* scope (ADR-0010), because the
bell needs to be visible and live on every cockpit screen for every nurse
at that site, not just a specific patient's page. Per-user streams were
considered and rejected: every nurse at a site needs to see every alert
for that site (there's no per-nurse patient assignment model in this
build), so per-site is both simpler and correct — identical reasoning to
why `FlagsChannel` is per-site rather than per-user.

`Domain::NurseAlerts::Broadcaster` fires on the three trigger points the
task specified: check-in submitted, dose recorded, caregiver message sent
— wired into the same three caregiver controllers right after their
existing `Domain::CareActivity::Broadcaster`/`Domain::Audit::Recorder`
calls (audit-first-then-broadcast, matching `Domain::Flags::Lifecycle`'s
established ordering).

**Payload is deliberately thin** — `type`, `episode_ref`, `patient_id`
(needed for the bell's `routerLink` to `/patients/:id`, which is keyed by
patient uuid, not episode id), `pseudonym_code`, `initials`,
`occurred_at`, and (dose only) `status`. No weight, no symptoms, no
message body/media. This is **not** an R5 requirement — this channel is
staff-only/authenticated exactly like `CareActivityChannel`, which *does*
carry clinical values (ADR-0010 decision #8 reasoned this through
already: nurses already see full clinical detail on the patient-detail
page via the pre-existing blueprint, so broadcasting it again isn't a new
exposure). It's a deliberately conservative choice anyway, because this
channel's only job is a lightweight "something happened, go look" badge —
a nurse who opens an alert navigates to the patient-detail page, which
renders full detail through the existing, unrelated
`CareActivityChannel`/`PatientDetailBlueprint`/message thread. Keeping the
alert payload itself minimal is simply good hygiene for a notification
whose UI never needed the extra fields.

**Scope, stated honestly**: unread state is in-memory,
per-browser-session only. `NurseAlertsService` (cockpit) holds `alerts`
and `unreadCount` as plain signals with no backing store; a page reload
clears both back to empty, and opening the dropdown ("mark seen") is
per-session, not per-alert, not synced across devices/tabs, and not
persisted server-side. Building real server-side read-tracking
(a `notification_reads` table, per-user, per-alert) was judged out of
scope for this pass — the task instructions explicitly called this an
acceptable scope ("a live, in-memory-for-this-session count is an
acceptable, honest scope for this pass").

**Connection lifecycle is the one place this channel's frontend service
differs structurally from every prior live-service pattern
(`FlagsLiveService`, `CareActivityLiveService`)**: those both
connect/disconnect from inside one specific routed page component's
lifecycle (`ngOnInit`/`ngOnDestroy`), which is exactly wrong for a nav
bell that must keep receiving alerts no matter which page is currently
mounted. `NurseAlertsService.connect()`/`.disconnect()` are instead called
from `App`'s constructor (`app.ts`), gated by an `effect()` over
`AuthService.isAuthenticated()` — connects once at login (or on a fresh
page load with an existing valid token), stays connected across every
route navigation since the root `App` component is never destroyed while
the SPA runs, disconnects on sign-out.

### ActiveStorage: URL generation needs an explicit host+port outside a request context

`rails_blob_url` needs `Rails.application.routes.default_url_options` set
even when called from a blueprint field block (no HTTP request in scope
the way a controller has one). Development: the Rails container listens
on port 3000 internally but is only reachable from the host browser via
the docker-compose port mapping to 3001 (`ops/docker-compose.yml`,
matching `ops/.env.example`'s `API_ORIGIN=http://localhost:3001`) — so
`config/environments/development.rb` sets host/port explicitly via
`APP_HOST`/`APP_PORT` env vars (defaulting to `localhost`/`3001`), not
inferred from the container's own bind address. Test: mirrors the
existing mailer convention (`host: "www.example.com"`). No
`image_processing`/`mini_magick` dependency was added — blobs are served
as-uploaded via the `rails_blob_url` redirect route, no variants/resizing,
consistent with "don't over-engineer" for this pass; a genuinely large
upload is bounded only by the 25MB cap above, not resized down.

#### A real deployment gotcha this caught: `config/environments/*.rb` does not hot-reload

Manual Puppeteer verification against the standing dev backend (the one
`ops/docker-compose.yml`'s persistent `backend` service runs, the one both
frontend dev servers actually talk to) initially returned a 500 —
`ArgumentError: Missing host to link to!` — from `PatientDetailBlueprint`
the moment a check-in with a photo entered `recent_activity`, even though
a one-off `docker compose run --rm backend bin/rails runner` invocation
tried moments earlier proved the same code path worked. Root cause: Rails
evaluates `config/environments/development.rb` once, at process boot —
`config.enable_reloading` (Rails' code reloader) reloads `app/` source,
not `config/environments/*.rb` itself. The standing `backend` container
had been running since before this change landed, so its in-memory
`default_url_options` was still unset; a fresh one-off `runner` invocation
boots a new process and picks up the current file, which is why that
check passed while the real running server hadn't. Fixed by restarting
the standing container (`docker compose restart backend` — source is
volume-mounted, no rebuild needed). Recorded here, not just fixed
silently, because it's a real trap for any future `config/environments/*`
change in this project: verifying via a one-off `runner`/`rspec` process
proves the *code* is correct but not that the *standing dev/demo server*
has picked it up — the standing container needs an explicit restart after
any such change before manual browser verification against it means
anything.

## Consequences

- No new migrations: `check_in_photos` and all three `active_storage_*`
  tables already existed in `db/structure.sql` (M0), unused until now.
- New backend surface: `CheckInPhoto` model,
  `Api::V1::Caregiver::CheckInPhotosController`, `Domain::Media::Url`
  (shared blob-URL helper), `Domain::NurseAlerts::Broadcaster`,
  `NurseAlertsChannel`. Extended: `Message` (`has_one_attached :media`,
  conditional `body_source` presence), `CheckIn` (`has_many
  :check_in_photos`), `MessageBlueprint`, `FlagDetailBlueprint`,
  `Domain::CareActivity::Broadcaster`,
  `Api::V1::Caregiver::MessagesController` (`#create`),
  `CheckInsController`/`MedicationDosesController` (nurse-alert
  broadcast call added).
- New frontend surface: cockpit `nav/nurse-alerts.service.ts` +
  `nav/nurse-alerts-bell.{ts,html,css}`, wired into `app.ts`/`app.html`.
  Extended: `patient-detail.ts/.html` (add/remove medication, activity
  feed note/photos, message media rendering), `flag-detail.ts/.html`
  (check-in history note/photos), `patients.service.ts`/`flags.service.ts`/
  `messages.service.ts` (cockpit) type additions. Caregiver:
  `check-in.ts/.html/.service.ts` (photo attach), `care-team.ts/.html/.css`
  (status-update composer), `messages/messages.service.ts` (`send()`).
- No new `docs/OPEN_CLINICAL_ITEMS.md` row: every piece of new copy is
  either ordinary operational app chrome or caregiver/nurse-authored real
  content, not system-authored clinical-shaped copy — same calibration
  ADR-0010 already used.
- Full backend suite: 515 examples, 0 failures (was 487 before this
  work); rubocop clean (344 files, was 334); brakeman clean (0 warnings,
  1 pre-existing ignored Rails-EOL entry, unchanged).
