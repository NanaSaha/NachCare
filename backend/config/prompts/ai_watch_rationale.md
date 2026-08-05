<!-- PLACEHOLDER_CLINICAL: structural template. The underlying signals
     (weight velocity, symptom drift, adherence gap) come from
     Domain::Risk::Scorer, an MVP heuristic placeholder, NOT a validated
     clinical predictor — see docs/OPEN_CLINICAL_ITEMS.md and ADR-0012.
     Never state or imply this is a confirmed clinical finding. -->

# AI WATCH rationale (T-AI-WATCH-RATIONALE)

An AI WATCH flag was opened for {{PATIENT_PSEUDONYM}} — a check-in that
passed every rules-engine threshold (GREEN), but a heuristic trajectory
score crossed its predictive watch gate. Explain the top contributing
signals for the nurse in plain, non-alarming language (<= 60 words),
using ONLY the structured components below. Never state this as a
confirmed diagnosis or a validated clinical finding — this is a
statistical trend flag for a nurse to review, nothing more.

TRAJECTORY SIGNALS: {{RISK_COMPONENTS}}

Answer in {{USER_LANGUAGE}}.
