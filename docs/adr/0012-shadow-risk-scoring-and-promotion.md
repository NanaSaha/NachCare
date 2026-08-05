# ADR-0012: Shadow risk scoring, MD/ADM-gated promotion, AI WATCH, and the per-check-in AI brief

**Status:** Accepted
**Date:** 2026-08-03

## Context

The product owner's 25-use-case catalogue names five use cases not yet
built after M0-M7 and two feedback rounds: UC-05 (silent shadow-mode
trajectory tracking), UC-21 (shadow-model promotion, MD/ADM-gated), UC-23
(AI predictive early warning — the "AI WATCH" flag class), UC-24
(predictive cadence adaptation), UC-25 (population risk-trend view) — plus
two smaller gaps: wiring the existing `Domain::Ai::Gateway.daily_brief`
into the check-in result screen, and adding an `ai_watch` value to
`flags.subtype`.

Critical framing from the orchestrating agent, carried through this build
without re-litigation:

1. **No real trained ML model exists and none can be trained here** —
   there is no pilot, no labeled outcomes dataset. `[RISK]` is built as a
   real, deterministic, fully explainable STATISTICAL/heuristic scorer,
   exactly parallel to how the escalation ruleset's clinical thresholds
   are marked `PLACEHOLDER_CLINICAL` (ADR-0005) pending the real SRS. It
   is never claimed to be a validated clinical predictor anywhere in code
   comments, UI copy, or docs.
2. **Shadow mode is the real, enforced default.** Every check-in computes
   and stores a risk score, paired with the rules verdict, invisible in
   every UI surface until the specific site has been explicitly promoted.
3. **Promotion is a real MD/ADM-facing workflow**, gate-evaluated against
   whatever data actually exists — expected to show "insufficient data"
   in a fresh dev/demo checkout, never fabricated as passing. An explicit,
   clearly-labeled dev/demo override lets an MD/ADM promote anyway so the
   full UC-23-25 experience can be seen without a real multi-week pilot.
4. AI WATCH is a new, visually distinct flag treatment (`flags.subtype =
   "ai_watch"`) extending the existing `Flag`/`Intervention` lifecycle
   machinery, not a parallel system.
5. Escalation from an open AI WATCH into a real rules-fired flag must
   preserve the watch's history/context on the resulting flag.

## Decisions

### 1. The heuristic scorer (`Domain::Risk::Scorer`)

Computes exactly the three signal families UC-23 names, each normalized
to `0..1` and combined with placeholder weights (documented in code,
`backend/app/domain/risk/scorer.rb`):

- **Weight velocity (weight 0.5)** — simple delta-over-window (today's
  weight minus the weight `VELOCITY_WINDOW_DAYS` (3) days ago), not a
  regression slope. Chosen for the same reason `ContextBuilder`/`Engine`
  use delta-over-window rather than a fitted slope: fewer data points are
  needed before it produces a meaningful signal, and it stays trivially
  explainable to a nurse (`Ai::Tasks::AiWatchRationale`'s whole point).
  Only gains count — a weight *loss* contributes 0, a deliberate scope
  decision matching the fluid-retention direction HF programs care about.
  Capped at `VELOCITY_CAP_KG` (1.2kg) — deliberately looser/earlier-firing
  than the rules engine's own placeholder weight-gain thresholds, since
  this is meant to catch trajectories *before* the hard rule would.
- **Symptom-answer drift (weight 0.3)** — average true-toggle count over
  the most recent 3 check-ins vs. the 3 before that; a rising average
  contributes to risk, flat/falling contributes 0.
- **Adherence gap (weight 0.2)** — proportion of the trailing 7 days with
  a missed *critical* medication (reusing the same `care_plan.medications
  .critical`/`check_in.med_status` shape `ContextBuilder` already reads
  for a single day, summed across the window here).

`ALERT_GATE` (0.55) is the placeholder promoted-alert-gate threshold UC-23
step 2 describes ("crosses its promoted alert gate"). `ELEVATED_THRESHOLD`
(0.35) is a softer threshold used only by the gate-3 "no missed reds"
computation below. **All of these numbers are placeholder content**,
logged in `docs/OPEN_CLINICAL_ITEMS.md`, exactly like the ruleset's
`999`-kg sentinel thresholds — not sourced from any SRS, not clinically
validated.

The scorer is a completely separate read path from
`Domain::Escalation::{Engine,ContextBuilder,Processor}` — never called
from inside them, per R2. It is invoked as an additional, independent
step (`Domain::Risk::ShadowPipeline.process!`) right after
`Domain::Escalation::Processor.process!` at the check-in submission call
sites (`Api::V1::Caregiver::CheckInsController#create`/`#update`). The
nightly missed-check-in scan does *not* score (`check_in: nil` — UC-05's
trigger is explicitly "every check-in", and there is no check-in weight/
symptom data to score on a silent day).

### 2. Shadow-vs-promoted data model

- `risk_scores` (new table): one row per check-in — `episode_ref,
  check_in_ref, score, components (jsonb), rules_severity, alert_eligible,
  outcome, outcome_evaluated_at`. `rules_severity` is the paired rules
  verdict for the same check-in (UC-05's training triple). `outcome`
  starts `nil` and is backfilled once knowable —
  `Domain::Risk::OutcomeLinker`:
  - `link_for_flag!` — when a real rules-driven flag opens/escalates,
    every still-unlinked shadow score for that episode in the trailing 14
    days gets tagged `flag_yellow`/`flag_red`. `outcome_evaluated_at` is
    used later as an honest proxy for "the date the rules engine
    actually fired" (linking happens synchronously at flag-open time).
  - `link_for_watch_resolution!` — the nurse's own accept/intervene/
    dismiss decision (or the 5-day auto-expiry) on a specific AI WATCH
    flag tags *that flag's own triggering* risk_score directly.
- **Promotion is per-site**, not per-deployment — more realistic (a
  multi-site pilot could promote one site's data readiness before
  another's) and barely harder to build: `Site#ai_watch_promoted?` reads
  `RiskModelPromotion.promoted_for?(site)`.
- `risk_model_promotions` (new table): one audited row *per decision*
  (not per read) — `site_ref, decided_by, version, gate_results (jsonb),
  gates_met, override, promoted`. A site counts as promoted iff it has
  any row with `promoted: true`. No demotion workflow exists — out of
  scope here.

### 3. Promotion gate evaluation (`Domain::Risk::PromotionGate`)

Three pre-registered gates, computed for real against whatever data
exists for the site — **never fabricated**:

1. **Earlier median detection than rules** — for every alert-eligible
   score linked to an eventual rules flag (`outcome` in
   `flag_yellow`/`flag_red`), lead time = `outcome_evaluated_at.to_date -
   check_in.effective_date`. Needs `>= 5` samples (`MIN_LEAD_TIME_
   SAMPLES`) or reports `insufficient_data`; met iff the median is
   positive.
2. **Alert rate < 0.10/patient-day** — alert-eligible scores ÷ total
   check-ins at the site, using a check-in as the "patient-day" unit (an
   approximation — a literal continuous-enrollment patient-day count
   would need enrollment-span tracking this build doesn't have). Needs
   `>= 20` check-ins or reports `insufficient_data`.
3. **No missed reds** — every red rules evaluation with a paired shadow
   score should show `score >= ELEVATED_THRESHOLD`; reds predating shadow
   scoring (no paired score — the feature wasn't active yet) are excluded
   from the denominator, not counted as a pass or a fail. Zero paired reds
   is a legitimate, vacuously-met state (nothing to have missed).

In a fresh dev/demo checkout with no real multi-week pilot, this
evaluation is expected to report `insufficient_data: true` and
`overall_met: false` — confirmed by manual verification below. That is
the correct, honest behavior, not a bug.

### 4. The dev/demo override (`Domain::Risk::Promoter`)

`POST /api/v1/staff/sites/:site_id/risk_model/promote` always
re-evaluates the gates server-side (never trusts a client-sent verdict)
and writes an audited `RiskModelPromotion` row every time a decision is
made, whether or not it results in promotion. `override: true` promotes
anyway when the gates aren't met — the UI's own override checkbox is
labeled "Promote anyway (dev/demo override — in production this requires
real gate-passing data)" verbatim, never hidden or silently applied.
Gated to MD/ADM roles (`physician`/`site_admin`/`sysadmin`,
`RiskModelPromotionPolicy#promote?`) — any staff member at the site can
*view* the honest gate numbers (`#show?`), but only those roles can act.

**Scoped down**: UC-21 step 3 says "MD + ADM approve" — read narrowly this
could mean a two-person dual sign-off (one physician AND one admin, each
clicking separately, with an intermediate pending-approval state). This
build implements a single-authorized-approver gate instead (any one
physician/site_admin/sysadmin can promote solo) — a real two-person
workflow would need its own state machine and was scoped down given time.
Noted here plainly, not glossed over.

### 5. AI WATCH (UC-23)

Extends the existing `Flag`/`Intervention` machinery rather than forking
a parallel system:

- `flags.subtype` gains `"ai_watch"` (migration
  `20260803190002_add_ai_watch_to_flags_subtype.rb`, extending the CHECK
  constraint).
- `flags.watch_expires_at` (new column) — only ever set for `ai_watch`
  flags; a scheduled `AiWatchExpiryJob` (mirrors `SlaWatchJob`'s shape,
  every 15 min) auto-resolves an untouched one after 5 days as
  `resolved_uneventful`, mirroring UC-23 Alternate A2 and counting on the
  false-positive side of the gate-2 alert-rate budget.
- `flags.ai_watch_meta` (new jsonb column) — snapshots the triggering
  `risk_score`'s id/score/component breakdown at watch-open time. This is
  exactly what preserves history/context when an AI WATCH escalates in
  place into a real rules-fired flag (`Domain::Flags::Lifecycle#upgrade`,
  UC-23 Alternate A1) — the escalation branch there always converts
  `subtype` to `"clinical"`, clears `watch_expires_at`, sets a real SLA
  deadline (regardless of whether severity rank increased, since a
  same-rank yellow rules-fire still needs to convert an ai_watch flag),
  and merges `escalated_at`/`escalated_to_subtype` onto the *existing*
  `ai_watch_meta` rather than discarding it.
- `Domain::Risk::WatchFlagger` is the *only* place a shadow score is
  allowed to act — creates the flag iff `rules_severity == "green"` AND
  `alert_eligible` AND `site.ai_watch_promoted?` AND no flag is already
  open for the episode. Re-checks promotion itself (not just trusting the
  caller) as a second, authoritative gate.
- The three nurse actions (UC-23 step 6) are `Intervention#outcome`
  values — `accept_and_watch`, `accept_and_intervene`,
  `dismiss_false_positive` — applied via the *existing*
  `Api::V1::Staff::FlagsController#update` (state/outcome/note
  transition), with `Domain::Risk::WatchOutcomes.apply!` as a follow-up
  step for the AI-WATCH-specific side effects (expiry-timer adjustment,
  risk_score training-label tagging). Not a new action system.
- The rationale panel (UC-23 step 5) is `Domain::Ai::Tasks::
  AiWatchRationale`, same `Gateway.call!` shape as T-TRIAGE, with a
  **deterministic plain-language fallback** (not just "unavailable") on
  graceful degradation — "never a bare score" has to hold even when the
  AI call fails, so the fallback renders the top-2 components by name
  directly from the stored breakdown.
- Caregiver-facing copy (the calm card) is deliberately **not
  AI-generated** — static i18n text (`checkin.aiWatch.*`), styled
  distinctly (AI-purple, `--ai`/`--ai-soft` tokens) from the existing
  amber/coral alert treatment, no SLA/urgency framing anywhere in it. This
  is the one caregiver-facing surface in the whole predictive feature set
  judged too high-empathy-risk to hand to an LLM.

### 6. Cadence adaptation (UC-24) and population trend (UC-25)

`Domain::Risk::TrendSummarizer` computes a direction only (`rising`/
`stable`/`improving`) from the trailing risk-score history — never a raw
score, per the explicit R5/UC-25 instruction. Exposed on
`PatientBlueprint#risk_trend`, gated on `site.ai_watch_promoted?` at the
blueprint layer (so the API itself, not just the UI, never leaks a score
pre-promotion).

`Domain::Risk::CadenceAdvisor#refresh!` proposes a taper (stable,
low-average score, `>= 4` samples) or densify (high/rising average)
`CadenceProposal`, idempotently (never opens a second pending proposal for
the same episode). `#approve!` is the *only* path that ever writes a new
`CarePlan` version — reusing the exact version-bump/carry-forward shape
`CarePlansController#create` already established (ADR-0010), landing the
proposed cadence into the previously-unused `care_plans.cadence` jsonb
column. The model never silently changes what a family is asked to do.

### 7. Per-check-in AI daily brief (M2 gap)

`Api::V1::Caregiver::CheckInsController#render_result` now calls
`Domain::Ai::Gateway.daily_brief` with the check-in's *structured*
evaluation context (severity, fired-rule keys, trend summary) whenever
the result is green — never free text, so there's no prompt-injection
surface from patient-authored notes. `Domain::Ai::Tasks::Brief` already
had the graceful-degradation template fallback built in M5 (ADR-0007's
established pattern); this ADR just wires the existing task into the
existing controller, which M5 hadn't done yet
(`docs/TRACEABILITY.md`'s prior note: "not yet wired into a green-result
UI screen").

## Consequences

- New migrations: `20260803190001_create_risk_scores.rb`,
  `20260803190002_add_ai_watch_to_flags_subtype.rb`,
  `20260803190003_add_watch_expires_at_to_flags.rb`,
  `20260803190004_create_risk_model_promotions.rb`,
  `20260803190005_create_cadence_proposals.rb`,
  `20260803190006_add_ai_watch_meta_to_flags.rb`.
- New domain classes under `backend/app/domain/risk/`: `scorer.rb`,
  `shadow_pipeline.rb`, `outcome_linker.rb`, `watch_flagger.rb`,
  `watch_outcomes.rb`, `promotion_gate.rb`, `promoter.rb`,
  `trend_summarizer.rb`, `cadence_advisor.rb`.
- New job `backend/app/jobs/ai_watch_expiry_job.rb` (schedule.yml,
  `*/15 * * * *`).
- New AI task `backend/app/domain/ai/tasks/ai_watch_rationale.rb` +
  `backend/config/prompts/ai_watch_rationale.md`.
- New/changed controllers: `Api::V1::Staff::RiskModelController`,
  `Api::V1::Staff::CadenceProposalsController`,
  `Api::V1::Staff::FlagsController` (`ai_watch_rationale` action,
  `WatchOutcomes` hook, `summary`'s new `ai_watch` KPI key),
  `Api::V1::Caregiver::CheckInsController` (shadow pipeline + brief +
  ai_watch signal wiring).
- New policies: `RiskModelPromotionPolicy`, `CadenceProposalPolicy`.
- Frontend: cockpit gains `/risk-model` (gate evaluation + promote
  action), a dedicated AI WATCH queue section + rationale panel + three
  action buttons on `flag-detail`, a `risk_trend` column on
  `patient-list`, and a cadence-proposal panel on `patient-detail`.
  Caregiver gains the calm AI WATCH card and the real per-check-in brief
  on the check-in result screen.
- This is genuinely a **prototype placeholder scoring function**, not a
  validated clinical predictor — logged in `docs/OPEN_CLINICAL_ITEMS.md`.
  Promotion to real production use (real gate-passing pilot data, not the
  dev/demo override) is a genuine human/clinical decision gate — logged
  separately in `docs/OPEN_DECISIONS.md`.
