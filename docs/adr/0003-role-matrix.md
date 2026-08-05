# ADR-0003: Staff role matrix (FR-N13)

**Status:** Accepted
**Date:** 2026-08-03

## Context

The build playbook references "Pundit policies per role matrix (FR-N13)" as
an M1 deliverable, but FR-N13's actual text lives in the companion SRS,
which isn't in the repo (`docs/OPEN_CLINICAL_ITEMS.md` #1). This is an
access-control/engineering design, not clinical content, so per R9 it's
decided here and recorded rather than blocked on.

## Decision

Six roles (`User::ROLES`), scoped per-site except `sysadmin`:

| Role | Scope | Can |
|---|---|---|
| `sysadmin` | all sites | Everything. Manage sites, manage staff users of any role/site, everything below. |
| `site_admin` | own site | Manage staff users at their site (not `sysadmin`s). Manage their site's settings. Everything a `nurse` can do at their site. |
| `physician` | own site | Everything a `nurse` can do, plus: edit care-plan clinical thresholds (FR-N8's "physician-gated threshold bounds"), approve rulesets and knowledge-base content (two-person approval, FR-N15). |
| `nurse` | own site | Everything a `ward_nurse` can do, plus: triage cockpit queue (resolve flags, log interventions, send caregiver messages), edit care plans other than physician-gated threshold fields. |
| `ward_nurse` | own site | Enroll patients (create patient/episode/activation code), view patients/episodes/check-ins/flags at their site. Read-only on the triage queue — the narrower discharge-side role. |
| `analyst` | own site | Read-only: patients, episodes, analytics events, pilot metrics/exports. No check-in note content, no messages, no assistant conversations (those carry free-text that's more sensitive than structured clinical fields). |

Default is deny: `ApplicationPolicy` has no permissive fallback — every
action method must be defined by a concrete policy, and `Pundit`'s
`NotAuthorizedError` is rescued into a 403.

Policies are added incrementally, one per resource, as each resource gets
its first real controller — not written speculatively ahead of use. M1
introduces `SitePolicy`, `UserPolicy`, `PatientPolicy`, `EpisodePolicy`;
`FlagPolicy`, `CarePlanPolicy`, etc. arrive with M2/M3.

## Consequences

Revisit against the real FR-N13 text once the SRS is available — this is
recorded as a decision, not a guess presented as fact, so a future diff
against the SRS is easy to review.
