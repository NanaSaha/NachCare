# NachCare AI

A prescribed digital aftercare companion for heart-failure patients in the
first 90 days after hospital discharge — a caregiver-facing Angular PWA
(daily check-ins, trends, an AI-guarded assistant, a Learn curriculum) and
a Ruby on Rails API backing both it and a nurse-facing clinical cockpit
(triage queue, care plans, pilot analytics). Built end to end (M0-M7) per
`NachCareAI_Agent_Build_Instructions.md`, the authoritative build
playbook — where this README and the playbook conflict, the playbook
wins.

**Trust rule stamped into every feature:** *AI-flagged, human-verified.*
The escalation engine that turns a check-in into GREEN/YELLOW/RED is pure,
deterministic Ruby — no LLM in that path, ever (R2). The AI assistant
layer never answers medication, dosage, diagnosis, or prognosis questions
— those always route to a nurse (R3).

## Documentation map

- `docs/RUNBOOK.md` — how to run, verify, and operate this checkout.
- `docs/TRACEABILITY.md` — every requirement ID implemented, its files,
  and its specs.
- `docs/OPEN_CLINICAL_ITEMS.md` — every `PLACEHOLDER_CLINICAL` value in
  this build (thresholds, alert copy, consent text) and what it needs
  before real clinical use. **Read this before treating anything in this
  repo as clinically accurate — none of it is; the companion SRS this
  content should come from isn't in this repo (item #1).**
- `docs/OPEN_DECISIONS.md` — non-clinical items needing a human decision
  before pilot/launch (legal texts, provider contracts, DPIA, etc.).
- `docs/adr/` — engineering decisions, numbered, one per non-obvious call.
- `docs/AI_EVAL_REPORT.md` — latest `rake ai:eval` guardrail-safety run.
- `docs/SUBPROCESSORS.md` — every external service, EU-region-only (R8).

## Quick start

```
ops/demo.sh
```

Boots postgres/redis/mailcatcher/backend, prepares the database, seeds
baseline reference data plus the full Ingrid/Sabine demo scenario, and
starts both Angular dev servers. Prints the caregiver activation code and
cockpit nurse login when done. See `docs/RUNBOOK.md` for the non-demo
day-to-day commands (running specs, the M7 gate, load testing, etc).

## The Ingrid story — a side-by-side walkthrough

`ops/demo.sh` seeds one continuous story: **Ingrid** (76, NYHA III) was
discharged after a heart-failure admission; her daughter **Sabine** (49)
does Ingrid's daily 3-minute check-in on the caregiver PWA. The seed
spans a full 90-day episode, with day 17 as its centerpiece — a real RED
escalation, caught and resolved by a nurse, driven through the actual
escalation engine rather than faked. Open both apps side by side:

**Caregiver PWA — `http://localhost:4200`**
1. Go to `/activate`, enter the activation code `ops/demo.sh` printed.
   Complete onboarding (language, consents, notification time, PIN).
2. You land on today's check-in (day 90 of the seeded episode — the seed
   deliberately leaves "today" unseeded so this step is a real, live
   submission). Enter a weight, confirm medications, no symptoms, submit.
3. **Trends** — 90 days of weight/symptom/adherence history, including
   the day-17 spike.
4. **Learn** — every seeded curriculum item is unlocked by day 90; mark
   one complete.
5. **Care-team** — the static emergency block (112, always renders, zero
   API dependency — try it with devtools offline) and the language
   switcher (try Arabic: the whole layout mirrors to RTL).

**Cockpit — `http://localhost:4300`**
1. Sign in with the nurse credentials `ops/demo.sh` printed
   (`sabine.demo.nurse@example.eu`).
2. **Triage** — the day-17 flag is already resolved in the seed (that's
   "the save": R-4 breathless-at-rest fired RED, the RED notification
   chain started, a nurse acknowledged and resolved it same day). Open it
   to see the full history — evaluations, the intervention note, the AI
   copilot draft panel.
3. **Patients** — find Ingrid, open her detail page. The episode is
   90 days old, so the **graduate** button is live — click it to run the
   real day-90 lifecycle transition and see the generated report.
4. **Analytics** (new in M7) — the pilot metrics dashboard. The default
   30-day window won't show the day-17 RED flag (it's outside that
   window); widen "From" back to ~May 2026 to see it: 100% RED-flag SLA
   compliance, a 60-minute median time-to-first-action, ~99% check-in
   adherence. Export as CSV or PDF.

Everything above is driven by the real backend — nothing in this
walkthrough is mocked or hand-waved. `e2e/tests/journey.spec.ts` scripts
this same day-0→17→90 story end to end via Playwright.

## Repository layout

```
backend/    Ruby on Rails 7.2 API — app/domain/ holds the core POROs
            (escalation engine, flags, AI gateway, audit spine, analytics)
frontend/   Angular workspace: projects/caregiver, projects/cockpit,
            projects/shared (design tokens, API client, i18n, severity UI)
docs/       Traceability, ADRs, open items, runbook, AI eval report
ops/        docker-compose, verify_*.sh gates, demo.sh, k6 load script
e2e/        Playwright, driving both Angular apps against the real backend
```

## Status: M0-M7 complete

All seven build phases (foundations; identity/enrollment; check-in +
escalation engine; cockpit triage; notifications; AI layer; trends/Learn/
graduation/i18n; analytics/reports/hardening) are built and gate-green.
See `docs/TRACEABILITY.md` for the full requirement-by-requirement
breakdown and `docs/OPEN_DECISIONS.md`/`docs/OPEN_CLINICAL_ITEMS.md` for
what's explicitly deferred to a human before real clinical/pilot use —
this build is a complete, working MVP scaffold, not a clinically-signed-off
product; every clinical value in it is a marked placeholder by design
(rule R1).
