# ADR-0005: Placeholder escalation ruleset — structure vs. content

**Status:** Accepted
**Date:** 2026-08-03

## Context

Section 7 says to create `config/rulesets/ruleset_v0_1.json` "exactly from
SRS Section 6.2: rules R-1…R-11 with the listed thresholds." The SRS isn't
in the repo (`docs/OPEN_CLINICAL_ITEMS.md` #1). R1 is explicit: every
clinical threshold, symptom question, and alert string must come from that
source verbatim, marked `PLACEHOLDER_CLINICAL` if it doesn't exist yet —
never sourced from training knowledge.

The playbook text itself (scattered across Sections 7–8) confirms three of
the eleven rules' *topics*, incidentally, while describing other features:

- **R-4** is the "breathless at rest" toggle in the check-in UI (Section 8,
  M2).
- **R-8** is the missed-check-in nightly scan (Section 7 and Section 8, M2).
- **R-10** drives `red_flag_phrases` — free-text note matching against
  emergency phrasing, e.g. chest-pain wording (Section 7).

The other eight rules' topics (R-1, R-2, R-3, R-5, R-6, R-7, R-9, R-11) are
not stated anywhere in the playbook.

## Decision

Split *structure* from *content*:

- **Structure** (rule categories, JSON schema, engine mechanics — context
  window, shadow mode, evaluation persistence): built for real, fully
  tested. For the 8 unconfirmed rule slots, I used the three categories
  every heart-failure telemonitoring program uses — weight trend, symptom
  worsening, medication adherence — because that categorization is public
  clinical-domain knowledge (taught in nursing curricula, standard across
  telehealth HF literature), not proprietary content this SRS would be the
  sole source of. This is a structural engineering choice, not a clinical
  claim, and it's the "pure engineering ambiguity: decide and move on" case
  R9 describes.
- **Content** (every numeric threshold, every symptom question's actual
  wording, every action/alert copy string, every red-flag phrase): 100%
  `PLACEHOLDER_CLINICAL`, using deliberately absurd sentinel values (e.g. a
  weight-gain threshold of `999` kg) so nothing here could be mistaken for
  real guidance if it ever reached a person. None of it is asserted to come
  from SRS Section 6.2 — the ruleset file and `docs/OPEN_CLINICAL_ITEMS.md`
  both say so explicitly.

R-4/R-8/R-10's *topics* are the one exception: those are taken from the
playbook text itself (not invented), though their specific thresholds/
phrases are still placeholder.

## Consequences

The M2 gate ("`rspec spec/domain/escalation` 100% + determinism property
test") tests engine *mechanics* — given a ruleset and inputs, does
evaluation behave correctly and deterministically — which doesn't depend on
whether the thresholds are real. That gate is meaningful today. The
ruleset's clinical *content* is not launch-ready and every value is logged
in `docs/OPEN_CLINICAL_ITEMS.md` for replacement once Section 6.2 is
available — a config swap, not a code change, per Section 9's mandate.
