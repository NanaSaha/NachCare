# ADR-0008: M6 engineering decisions — Trends, Learn, graduation, i18n completion

**Status:** Accepted
**Date:** 2026-08-05

## Context

Section 8's M6 line is terse (two sentences, no cross-referenced earlier
section — verified by grepping the whole playbook for "Trends"/"Learn"/
"graduat" before starting: those two sentences are the entire spec):

> Trends charts; Learn curriculum with unlock weeks + completion events;
> Care-team page with static emergency block (R4 spec: renders with all
> APIs mocked to fail); day-90 graduation + report; runtime language
> switching everywhere incl. AR RTL (`dir` switching, mirrored layouts
> audit on check-in flow); pending-notification language follows switch.

The companion SRS isn't in the repo (`docs/OPEN_CLINICAL_ITEMS.md` #1), so
several structural details are engineering decisions per R9. None of the
decisions below invent clinical content; where content is needed
(curriculum body text) it is `PLACEHOLDER_CLINICAL` per R1, tracked in
`docs/OPEN_CLINICAL_ITEMS.md`, not decided here.

## Decisions

1. **`content_items` (Learn) reuses the `KnowledgeDoc` two-person-approval
   shape exactly** (`draft -> in_review -> approved`, `REQUIRED_APPROVALS =
   2`, `approvals` jsonb log, `approve!` idempotent on repeat approvers).
   `kind` is a small closed enum (`article`, `tip`, `video`) — a content
   *format* distinction, not clinical content, so it's decided here.
   `language_variants` jsonb holds `{ "en" => { "title" => ..., "body" =>
   ... }, "de" => {...} }`; caregiver-facing responses fall back to `en`
   if the caregiver's language has no variant yet (same fallback contract
   as `Retrieval`'s knowledge-chunk language filter in M5).
   **Following the M5 knowledge-base-CMS precedent exactly** ("no cockpit
   CMS review UI... nurses/physicians can approve via the API directly for
   now" — `docs/TRACEABILITY.md` FR-N15 row), the staff `ContentItems`
   CMS is API-only in this build: no dedicated cockpit authoring/approval
   screen. Same time-scoping rationale as M5's KB CMS.

2. **Unlock weeks are computed, not stored per-caregiver.** An item with
   `week_no = N` is unlocked once the episode has been active for `N`
   program-weeks: `unlocked = ((Date.current - episode.start_date).to_i /
   7) + 1 >= week_no` (`Domain::Learn::Unlocker`). No per-caregiver unlock
   state table — recomputed on every read from `episode.start_date`, the
   same "derive, don't cache" approach the escalation engine's context
   builder already uses for its 14-day window.

3. **"Completion events" are `analytics_events` rows**, not a new table.
   Section 5 already defines `analytics_events` (`episode_pseudonym_ref,
   name, properties jsonb, occurred_at`) and Section 4's repo layout
   already reserves `app/domain/analytics/tracker.rb` for exactly this
   kind of write — it just hadn't been built yet (M7's `pilot_metrics.rb`
   companion is still out of scope; only the minimal `Tracker.track!`
   entry point is added now). Reusing this table over inventing
   `content_completions` avoids a parallel event log and gives M7's
   analytics taxonomy work a real event (`content_item.completed`) to
   build on rather than a retrofit. The `AnalyticsEvent` model didn't
   exist yet (table only, migrated at M0) — added here, minimally
   (presence validations only; no taxonomy enforcement, that's AN-1/M7).

4. **Graduation is a staff-initiated action gated by a day-90 floor, not
   an automatic job.** "First 90 days after hospital discharge" (Section 0)
   and "day-90 graduation" (Section 8/M6) are both playbook-verbatim, not
   `PLACEHOLDER_CLINICAL` — the *90* is a stated programme-duration fact,
   not a clinical threshold requiring sign-off. `Domain::Graduation::
   Eligibility.eligible?(episode:)` returns true once
   `(Date.current - episode.start_date).to_i >= 90`; the transition itself
   requires a managing-role staff member to call `POST
   /api/v1/staff/episodes/:id/graduate` (`EpisodePolicy#graduate?`, same
   role gate as `FlagPolicy#update?` — every managing role except
   `ward_nurse`, per ADR-0003: ward_nurse is discharge-side only). An
   automatic Sidekiq transition at exactly day 90 was rejected: silently
   changing a patient's monitoring status without a human action is a
   bigger safety footgun than a nurse graduating a day or two late, and
   nothing in the playbook asks for automatic transition (contrast with
   R-8's *scan* job, which only *flags* missed check-ins, never changes
   episode/flag state without a human in the loop for anything
   consequential).

5. **Graduation persists to `episodes.milestones` jsonb**, not a new
   table/columns — `milestones` was already reserved for exactly this in
   Section 5 and was unused until now. `Domain::Graduation::Graduator`
   sets `status: "graduated"` and writes `milestones["graduated_at"]`,
   `["graduated_by"]` (user id), and `["graduation_report"]` (the T-REPORT
   text, generated once at graduation time via the *already-existing*
   `Domain::Ai::Gateway.episode_report` from M5 — this ADR does not add a
   new report generator, only a new caller). The existing
   `GET /api/v1/staff/episodes/:id/report` (M5) is left as an independent
   on-demand/live endpoint for viewing the report at any time, including
   before graduation; graduation additionally snapshots one copy into
   `milestones` so the day-90 report a patient graduated with is
   reconstructable later even if a regenerated report would read
   differently (new flags, etc. after graduation).

6. **Trends is a new caregiver-facing dedicated screen**, reusing the
   existing `check_ins` data the escalation engine and M3's flag-detail
   sparkline already read — no new backend table. `GET
   /api/v1/caregiver/trends` returns up to `min(episode_age_days, 90)`
   days of check-in history (weight series, per-day symptom count, and a
   rolling adherence percentage from `med_status`), separate from the
   escalation engine's own 14-day *evaluation* window (different purpose:
   engine context vs. caregiver-facing history). The cockpit already has
   a trend chart (M3's flag-detail sparkline, `data-testid="trend-chart"`)
   — this ADR doesn't touch it, to avoid regression risk in a working M3
   gate, but the new `TrendChart` shared component (`projects/shared/src/
   lib/trend-chart/`) generalizes that sparkline's SVG-polyline approach
   (still no charting library — Section 2's "pick one, ADR it" for
   `ngx-echarts`/`ng2-charts` was never actually exercised in M3, which
   shipped a hand-rolled inline SVG polyline instead; this ADR formalizes
   that as the actual decision, backfilled, rather than adding a charting
   dependency now for one new screen).

7. **Notification bodies become per-language** (`Domain::Notifications::
   Templates.body_for(kind:, language:)`), replacing the flat English-only
   `BODIES` hash from M4. This is required by M6's explicit "pending-
   notification language follows switch": since `Dispatcher#send!` already
   reads `caregiver.language` fresh at send time (no caching), the
   mechanism is correct by construction the moment bodies are keyed by
   language — no separate "pending notification" queue to update on
   switch. EN and DE bodies are agent-authored (DE `MACHINE_DRAFT`, same
   convention as UI copy — `docs/OPEN_DECISIONS.md` #2); TR/RU/AR ship as
   EN-fallback, same convention as the i18n JSON files (`frontend/
   projects/caregiver/public/i18n/README.md`). All bodies remain
   ordinary operational copy, not clinical content — the R5 payload-
   minimization spec is extended (not relaxed) to check every language
   variant of every kind, not just the single English string.

8. **Runtime language switching outside onboarding reuses the existing
   `PATCH /api/v1/caregiver/onboarding` endpoint** — it already accepts a
   bare `{ language: ... }` body unconditionally (`OnboardingsController#
   update`, M1), not gated to first-run. No new backend endpoint. The
   frontend adds a small always-available language switcher (Care-team
   page) and restores `caregiver.language` into `TranslateService` +
   `document.documentElement.dir`/`lang` on every app boot (previously
   only ever set once, transiently, during the onboarding step — lost on
   reload, which this ADR treats as a pre-existing gap M6 closes, not new
   scope creep, since "runtime language switching everywhere" explicitly
   requires it to survive navigation/reload).

9. **AR RTL**: `document.documentElement.dir` follows `TranslateService`'s
   active language (`ar` -> `rtl`, else `ltr`), set from one place (root
   `App` component) on boot and on every switch. A repo-wide audit of
   caregiver-app CSS for direction-dependent physical properties
   (`margin-left/right`, `padding-left/right`, `text-align: left/right`,
   `left:`/`right:` positioning) found exactly one offending rule
   (`onboarding.css` `.something { text-align: left }`) — everything else
   already uses `flex-direction: column` or direction-agnostic properties,
   which CSS flexbox mirrors automatically under `dir="rtl"` with zero
   extra CSS. That one rule is changed to the logical `text-align: start`.
   No RTL stylesheet/override file was needed given the audit result;
   this ADR documents that the audit happened and found the surface
   area small, rather than pre-building unused infrastructure.

## Consequences

- Zero new migrations: `content_items` and `analytics_events` tables were
  already created at M0 (Section 5) and never populated — this phase adds
  the two missing models/domain logic, not schema.
- `docs/OPEN_CLINICAL_ITEMS.md` gets one new row (Learn curriculum body
  text, same shape as M5's knowledge-base seed row).
- Cockpit gets a "Graduate" action + report view on the existing
  patient-detail screen; content_items CMS review stays API-only,
  matching the KB CMS precedent, and is not tracked as a new open item
  since M5 already established this as an accepted time-scoping pattern.
