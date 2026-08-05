# ADR-0009: M7 engineering decisions — Analytics, reports, hardening

**Status:** Accepted
**Date:** 2026-08-09

## Context

Section 8's M7 line, verbatim:

> Analytics event taxonomy (AN-1) + pilot_metrics module computing the five
> metrics; FR-N12 CSV/PDF export; weekly digest job; rate limiting
> (rack-attack), security headers, brakeman clean, dependency audits clean;
> load script: 300 concurrent check-ins < 2 s p95 (use `k6` in `ops/`);
> failure drills scripted: LLM down, push down, redis down — assert
> degradations match spec; seed `ingrid_scenario.rb` reproducing the full
> demo story incl. the day-17 save; RUNBOOK.md.

Gate: `verify_m7.sh` = AT suite (Section 8 acceptance tests AT-1..AT-10)
green + load + failure drills.

The companion SRS isn't in the repo (`docs/OPEN_CLINICAL_ITEMS.md` #1), so
neither "the five metrics" (AN-1) nor FR-N12's exact field list is defined
anywhere in this repo. Per R9 these are engineering ambiguities, not
clinical content — none of the decisions below invent clinical thresholds
or copy; they're the same category of structural call ADR-0003 (role
matrix) and ADR-0008 (M6 structural decisions) already made. Grepped the
whole playbook for "AN-1", "FR-N12", "pilot_metrics", "readmission" before
deciding — no fuller definition exists anywhere in this repo.

## Decisions

### 1. The five pilot metrics

Chosen to track the product's stated mission (Section 0: catch
deterioration early, get the right SLA response, keep caregivers engaged
through day 90) using only data this build already produces — no new
clinical inputs:

1. **Check-in adherence rate** — completed check-in days ÷ expected
   check-in days, per episode, averaged over the requested window. Expected
   days = elapsed program days capped at the episode's age (an episode that
   started 5 days ago has 5 expected days, not the full window length).
2. **RED-flag SLA compliance rate** — share of RED flags whose
   `first_action_at` (or `resolved_at` if never separately actioned) fell
   at or before `sla_deadline_at`, i.e. `breach == false`. This is the
   single sharpest "did we catch and respond to danger in time" signal and
   the one most directly tied to readmission prevention.
3. **RED-flag median time-to-first-action** — median minutes from
   `opened_at` to `first_action_at` across RED flags with a recorded
   first action. Complements #2 with a magnitude, not just a pass/fail.
4. **Program completion rate** — among episodes old enough to have
   concluded one way or another (age >= `Domain::Graduation::Eligibility::
   MIN_DAYS`), the share with `status == "graduated"` vs. `withdrawn` /
   `deceased`. A pilot-level engagement/retention signal.
5. **Assistant safety-routing rate** — share of assistant turns where a
   guardrail correctly kept the assistant from answering
   (`routed == true` or `emergency_detected == true`) out of all turns
   where routing was *warranted* (approximated as: all routed/emergency
   turns, divided by itself, i.e. this metric reports the routed-turn
   *count and rate of total turns*, not a false-negative rate — this build
   has no ground-truth label for "should have routed" outside the eval
   harness's `rake ai:eval`, which already covers that with a stricter
   100%-of-traps assertion). Reported as: routed turns ÷ total turns, framed
   explicitly in the API/UI as "share of conversations kept off clinical
   ground" rather than a safety-recall claim — `rake ai:eval` remains the
   actual safety gate (AI-1).

All five are computed **directly from source-of-truth tables**
(`check_ins`, `flags`, `episodes`, `assistant_turns`), the same approach
`FlagsController#summary` (M3) already uses for the KPI header — not from
`analytics_events`. Reasons: (a) it's what AT-10 ("pilot report exact-match
against seeded known dataset") needs — a deterministic function of rows
that already have integrity constraints, not of an event log whose
completeness depends on every call site remembering to call
`Tracker.track!`; (b) it avoids a second parallel source of truth that
could drift from the tables that already enforce it in the domain layer
(`Domain::Flags::Sla`, `Domain::Graduation::Eligibility`).
`Domain::Analytics::PilotMetrics.compute(site:, from:, to:)` is the module;
pseudonym-refs only in its output (site id, counts, rates, minutes — never
a patient/caregiver identifier), per R5.

### 2. AN-1 event taxonomy stays a closed list, enforced at the model

`AnalyticsEvent::TAXONOMY` (a frozen array) is the closed set of event
`name`s `Tracker.track!` may write; `AnalyticsEvent` validates `name`
inclusion against it (was presence-only since M6, ADR-0008 #3). This
formalizes "AN-1" as a real taxonomy deliverable independent of
`pilot_metrics` (per decision #1, metrics don't read this table) — it
exists for event-level CSV export (decision #3) and as the extension point
future analytics consumers build on, without becoming a second metrics
source of truth. New `Tracker.track!` call sites added this phase: `flag.opened`,
`flag.resolved`, `checkin.submitted`, `episode.graduated`,
`assistant.turn.routed` — chosen to cover one event per metric above
(plus `content_item.completed`, already present since M6), so the
taxonomy has real, exercised rows in the seeded demo rather than shipping
empty. `episode.withdrawn`/`episode.deceased` are included in the
taxonomy's closed list (metric #4 reads `episodes.status` directly, which
already supports those values per `Episode::STATUSES`) but have no
`Tracker.track!` call site yet — no controller/job in this build ever
transitions an episode to `withdrawn`/`deceased` (out of M7 scope, not
asked for by the playbook); wiring those two stays a follow-up for
whenever that lifecycle path is built, not invented here.

### 3. FR-N12 export: pilot metrics only, CSV + PDF, same Prawn pattern as ADR-0004

`GET /api/v1/staff/analytics/pilot_metrics` (JSON), `.csv`, and `.pdf`
format variants of the same endpoint (Rails format-based rendering, one
controller action). CSV via Ruby's stdlib `CSV` (no new gem). PDF reuses
the `Domain::Enrollment::CodeSheetPdf` Prawn pattern exactly (A4 portrait,
same font-hiding preamble) — new class `Domain::Analytics::PilotMetricsPdf`.
Raw `analytics_events` CSV export was considered and scoped out: FR-N12's
wording ("CSV/PDF export") reads as a report export, and a raw event-log
dump has no PDF-shaped analog, so extending it to both formats consistently
argues for the metrics report, not the event log.

### 4. Access: reuses the existing role matrix, no new role

ADR-0003 already assigned `analyst`: "Read-only: patients, episodes,
analytics events, pilot metrics/exports" — M7 doesn't need a new role, and
no new policy class either: `AnalyticsController` authorizes against the
`Site` record itself (`authorize site, :show?`), reusing `SitePolicy#show?`
(`sysadmin? || same_site?`) exactly as written — that method's semantics
("sysadmin sees everything, everyone else only their own site") are
precisely what pilot-metrics visibility needs, and the record really is a
`Site`, not a synthetic one `SitePolicy` would have to be taught about.
Every staff role including `analyst` gets read access at their own site;
pilot metrics are operational visibility every staff role benefits from,
not a restricted view.

### 5. Weekly digest job: real `ActionMailer`, not the caregiver `EmailAdapter`

`Domain::Notifications::Adapters::EmailAdapter` and `Templates` are built
for **caregiver** notifications and R5 payload minimization ("no health
terms in any dispatched notification body" —
`spec/domain/notifications/payload_minimization_spec.rb`). The weekly
digest is a **staff-facing operational** email (aggregate counts/rates, no
patient-identifying content by construction per decision #1) sent to
`site_admin`/`physician` users at each site — reusing the caregiver
minimization pipeline would be the wrong contract (it's designed to
minimize, this needs to inform). New `DigestMailer#weekly_digest(user:,
site:, metrics:)` on the existing `ActionMailer::Base` infra (already
wired to `mailcatcher` in dev per `ops/docker-compose.yml`, `:test`
delivery in test). `WeeklyDigestJob` (Sidekiq, `schedule.yml` — the
"digest" job the M4-era Gemfile comment on `sidekiq-cron` already
anticipated) runs weekly per site, computes `PilotMetrics.compute` for the
trailing 7 days, and mails every `site_admin`/`physician` at that site.

### 6. Rate limiting: `Rack::Attack` with the default in-process store, not Redis-backed

`Rack::Attack.cache.store` is left at its gem default
(`ActiveSupport::Cache::MemoryStore`), not pointed at the app's Redis
instance. Deliberate: coupling rate-limiting *availability* to Redis
health would mean a Redis outage either fails the limiter open (silently
disabling brute-force protection right when the app is already degraded)
or fails it closed (throttling collapses to "reject everything," which is
worse than no limiter). In-process memory means the limiter can't
coordinate across multiple app processes/dynos, which is a real gap at
real pilot scale — logged as a follow-up in `docs/OPEN_DECISIONS.md#11`
rather than solved now (this build runs a single backend container; the
gap only matters once it's horizontally scaled). Throttled: caregiver
activation-code exchange (`POST /api/v1/caregiver/activations`, the
brute-force-guessing surface the M1 controller comment already flagged as
"an M7 hardening concern") at 5 req/20s per IP, and staff login
(`POST /api/v1/staff/sign_in`) at 5 req/20s per IP + per email, both under
`throttle`, returning 429 with a small JSON body (no PHI, per R5).

### 7. Security headers via a thin Rack middleware, not the `secure_headers` gem

`ActionController::API` has no view-layer CSP DSL to hook into, and this
app has no server-rendered HTML surface to protect beyond a handful of
fixed headers, so a new gem is unjustified weight. `Middleware::
SecurityHeaders` (new, `config/application.rb` inserts it) sets
`X-Content-Type-Options: nosniff`, `X-Frame-Options: DENY`,
`Referrer-Policy: strict-origin-when-cross-origin`,
`Content-Security-Policy: default-src 'none'` (a pure JSON API originates
no scripts/styles/images of its own — `'none'` is correct, not
lazy-strict), `Strict-Transport-Security` (production only, since dev/test
run over plain HTTP).

### 8. Failure drills are RSpec specs against stubbed failure conditions, not live container kills

The standing session instruction says not to bring the shared
`docker-compose` stack down. Killing `redis`/simulating LLM/push outages
by stopping containers would also make the drills non-reproducible in CI
(no container orchestration there beyond the `services:` blocks CI already
runs). Every prior phase already tests degradation this way — M4's
`fallback_chain_spec.rb`, M5's gateway timeout/fallback specs — so M7
follows the same pattern: `spec/domain/hardening/failure_drills_spec.rb`
stubs (a) the AI provider chain raising on every call (LLM down —
asserts `assistant_reply` degrades to `routed_to_nurse` per Section 6 #1,
AT-9), (b) `WebPushAdapter#send!` returning false (push down — asserts the
RED fallback chain's SMS escalation fires, reusing
`Domain::Notifications::FallbackChain`), (c) `Redis::BaseError` raised
from `KnowledgeChunkingJob.perform_async` (the only synchronous-path
Sidekiq enqueue in the app — grepped for `perform_async`/`perform_in`
across `app/`) — asserts `KnowledgeDoc#approve!` still completes and
persists the approval instead of 500ing, with the enqueue failure logged
(`KnowledgeDoc#approve!` wraps the enqueue in a rescue.) `verify_m7.sh`
runs this file explicitly as its own step so a drill regression is visible
independent of the full suite.

### 9. Load script targets the seeded demo data, run manually against the dev container

`ops/k6/load_checkins.js` posts 300 concurrent `POST
/api/v1/caregiver/check_ins` (idempotent on `client_uuid`, already proven
in `check_ins_spec.rb`) against the running dev backend container, using
device tokens for 300 dedicated caregivers seeded by `bin/rails
load_test:seed[300]` (`backend/lib/tasks/load_test.rake` — a rake task,
not a `db/seeds/*.rb` file, since it's throwaway load-fixture data under
its own "M7 Load Test Site", with a matching `load_test:teardown` task).
`verify_m7.sh` runs it via `docker run --rm --network nachcare_default
grafana/k6 run` against `http://backend:3000` (both on the compose
network) and asserts p95 < 2000ms from k6's own summary output. Not wired
into GitHub Actions CI (no spare capacity/isolation guarantee on shared
runners for a 300-VU load assertion without flaking) — it's a
`verify_m7.sh`/manual-run gate, consistent with `rake ai:eval` being "CI
nightly... skip-if-no-key," i.e. this repo already has precedent for
gates that live outside the PR-blocking CI path.

Two real bugs surfaced building this gate, both fixed, neither about load
per se: (a) `ActionDispatch::HostAuthorization` blocks the docker-compose
service alias `backend` by default in development (only `localhost`/IPs
are allowlisted out of the box) — k6 running in its own container needs
`http://backend:3000`, so `config/environments/development.rb` now adds
`"backend"` to `config.hosts`; (b) `client_uuid` is a native Postgres
`uuid` column, and the load script's first draft generated non-UUID
placeholder strings — Rails casts an invalid UUID string to `nil` rather
than raising, which surfaces only as "Client uuid can't be blank," and
chasing that looked exactly like an application bug for a long detour
before being isolated to the test data. `load_checkins.js` now generates
real v4 UUIDs (a small inline generator, not a remote jslib import — the
k6 container has no guaranteed network access at gate time).

**Puma tuning and the honest result.** The stock dev config
(`config/puma.rb`'s 3-thread, single-process default) queues hard under
300 concurrent connections — measured p95 ~5.9s. `config/puma.rb` gained
opt-in `WEB_CONCURRENCY`-driven multi-worker support (`workers` +
`preload_app!` + an `on_worker_boot` DB-reconnect hook, standard Rails/
Puma cluster-mode boilerplate); `ops/docker-compose.yml`'s `backend`
service now sets `WEB_CONCURRENCY=10`/`RAILS_MAX_THREADS=6` (60 Puma
request-handling slots, 60 DB connections against Postgres's
`max_connections=100` — headroom kept deliberately for `rails console`/
migrations/etc. running alongside). This was the best of several
worker/thread combinations swept (3-thread single-process, 4x10, 8x10,
8x12, 10x6) — it converges around **p95 ~2.3-2.4s, not fully under the 2s
bar**. `nachcare-backend-1`'s CPU never exceeded ~50% during any of these
runs (`docker stats` sampled mid-run), ruling out raw compute as the
ceiling; the remaining gap is most likely Docker Desktop's virtualized
network/CPU scheduling overhead for a single shared dev container on this
host, not an application-level defect — individual request latency under
light load (20 VUs) was 69-89ms, so the escalation pipeline itself isn't
slow. Recorded here rather than silently tuned away or claimed as passing:
this gate is genuinely not green in this environment. A real deployment
target (dedicated host/multiple containers behind a load balancer, not a
laptop's single Docker Desktop VM sharing CPU with everything else this
session ran) would very plausibly clear it, but that's not something this
session's environment can prove. Logged as `docs/OPEN_DECISIONS.md` #12.

## Consequences

`docs/OPEN_DECISIONS.md` gets one new row (#11: Rack::Attack's in-process
store doesn't coordinate across horizontally-scaled instances — revisit
if/when the backend runs more than one process). Nothing here invents
clinical content; revisit metric definitions against the real SRS/AN-1
text once available, same posture as every other ADR in this index.
