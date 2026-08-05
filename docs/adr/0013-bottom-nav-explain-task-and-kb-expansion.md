# ADR-0013: Caregiver bottom navigation, care-plan-item explain task, and knowledge-base/retrieval tuning

**Status:** Accepted
**Date:** 2026-08-03

## Context

The product owner filed 4 items against the live caregiver app: (1) Home
should surface the nurse's tasks/medications/notes with tap-to-explain,
(2) the check-in wizard needed a way to go back and fix a mistake, (3)
there was no persistent navigation once a caregiver left the check-in
result screen, (4) the AI assistant was routing almost every real
question to "I can only help with..." instead of answering it. Items 2
and 3 were root-caused before this round started (an unwired `back()`
method; `app.html` being a bare `<router-outlet />`); items 1 and 4
required new design decisions, captured here alongside the nav grouping
and the explain-task's R3 boundary.

## Decisions

### 1. Bottom tab bar, not a top nav, 5 items not 7

Mobile-first PWA (390px viewport convention throughout this build) ->
thumb-reachable bottom bar, not the cockpit's desktop top-nav pattern
(`frontend/projects/cockpit/src/app/app.html`) — only the *pattern*
(routerLink + routerLinkActive active-state styling, auth-gated
rendering from the app root) is reused, not the visual treatment.

7 real authenticated routes existed (`home`, `assistant`, `care-plan`,
`care-tasks`, `trends`, `learn`, `care-team`). Cramming all 7 into one
bar fails the "4-5 items max" bottom-bar convention and a phone's actual
thumb-reach width. Split:

- **5 top-level tabs**: Home, Care Plan, Trends, Assistant, More.
- **"More" sheet** (a small popover, not a route): Care Tasks, Learn,
  Care Team.

Rationale for what's top-level vs. inside More: Home/Care
Plan/Trends/Assistant are the screens a caregiver plausibly opens
*every day* (today's check-in, what the nurse prescribed, how things are
trending, ask a question). Care Tasks is a secondary, more granular view
of the same medication data Home's new nurse-tasks list and Care Plan
already surface (see decision 3) — it earns a place in the app, not a
thumb-reach slot. Learn is deliberately slower-cadence (weekly
unlocks), and Care Team is check-in/emergency-adjacent but not a daily
destination. This is a product judgment call (R9: engineering ambiguity
-> decide, document, move on), not SRS-derived.

New: `frontend/projects/caregiver/src/app/nav/bottom-nav.{ts,html,css}`,
rendered once from `App`'s root template (`app.html`), alongside
`<router-outlet />` — visible whenever `DeviceTokenStore.token()` is
non-null *and* the current route isn't `/activate` or `/onboarding` (the
token exists during onboarding too, since `deviceAuthGuard` gates that
route — visibility is route-driven, not just token-driven).
`check-in.html`'s and `care-plan.html`'s prior embedded per-page nav
links are removed (redundant with, and would duplicate testids with, the
new global bar); their single "back to home" links are untouched.

### 2. Check-in back button

One-line-per-step template fix: `check-in.ts`'s existing (never-wired)
`back()` now backs a `<button class="back">` on every step past the
first, rendered outside the `@switch` (mirrors
`onboarding.html`'s identical `.back` pattern/class exactly), hidden on
the `result` step (the check-in is already submitted by then — "back"
would imply re-editing already-sent data). The weight step (step 1) has
nothing to go back to; its input was already freely re-editable before
pressing "Continue," so no change was needed there beyond what already
existed.

### 3. `Domain::Ai::Tasks::ExplainCarePlanItem` — grounded, not retrieval-based

Built as its own task (`backend/app/domain/ai/tasks/explain_care_plan_item.rb`
+ `config/prompts/explain_care_plan_item.md`), explicitly **not** routed
through `AssistantPipeline`/`Tasks::Assistant`. That pipeline's answer
stage depends on RAG retrieval against the approved knowledge base;
reusing it here would inherit the exact "no KB match -> routed" failure
mode this same round already diagnosed and fixed for item #4 — a
guaranteed dead end for "explain this specific medication," which will
essentially never have a matching KB chunk. Explaining a single,
already-known structured item doesn't need retrieval at all: the
caregiver never types free text into this flow, only taps a card whose
underlying data (medication name/schedule/instructions, or the nurse's
`care_instructions`/`diet_rules` text) is passed straight into the
prompt as `{{ITEM_DETAIL}}`.

**R3 boundary.** R3's concern is a caregiver *deciding* on a medication
change (extra dose, skip, stop) getting routed to a nurse rather than
answered by a model. Explaining an *already-prescribed* item (why it's
scheduled this way, in the nurse's own words) is a different act — it
restates a fact the nurse already committed to, it doesn't decide
anything new. Two independent layers enforce that boundary rather than
relying on judgment alone: (a) the task takes no caregiver free text as
input at all — there is no message a caregiver could phrase as "should
we change this," so `KeywordPreRouter`/`CategoryRouter` genuinely don't
apply here (they classify a caregiver's own words; there are none); (b)
the prompt template itself hard-constrains the model — "explain, never
suggest changing dose/timing/stopping/adding, if unsure whether
something counts as a change, leave it out." Graceful degradation
mirrors `Tasks::Brief`'s established pattern exactly: `AllProvidersFailed`
-> a plain non-AI fallback string ("Ask your nurse if you'd like more
detail on this"), never a raised error to the caregiver.

New endpoint: `POST /api/v1/caregiver/care_plan/explain`, params
`item_type` (`medication` | `care_instructions` | `diet_rules`) +
`item_id` (medications only). Scoped to the caregiver's own active care
plan server-side — a medication id from another episode 404s, it never
authorizes by client-supplied episode/patient context. New controller:
`Api::V1::Caregiver::CarePlanExplanationsController`.

Frontend: Home (`check-in.html`, the literal "first thing seen" per the
product owner's wording — shown only on the wizard's first/weight step,
so it doesn't clutter the remaining steps) gains a "From your nurse"
list — medications with times, plus care instructions/diet text if
present — each tappable, opening a panel with loading/error/result
states. The AI-generated explanation text gets the `--ai`/`--ai-soft`
treatment (design system Section 2: AI-purple reserved exclusively for
AI-generated content); the non-AI degraded fallback string does not.

### 4. Knowledge-base expansion + `StubProvider` stopword tuning (item #4)

Confirmed live before changing anything:
`Domain::Ai::Retrieval.search(query: "Can she eat normal restaurant food
this weekend?", language: "en")` returned `[]` against the 2-doc seeded
KB (`similarity_threshold` 0.3, dev/test default). The 2 docs
(Fluid Tracking, Low-Salt Day) simply have no content for eating
out/travel/activity/hygiene/sleep/visitors — most realistic caregiver
questions had nothing to retrieve, so `AssistantPipeline` correctly (not
buggily) fell through to the `out_of_scope` routed response every time.

**Fix, in order tried:**

1. **Content first.** Added 5 new approved `KnowledgeDoc` rows
   (`db/seeds/knowledge_base.rb`) — Eating Out and Travel, Activity and
   Exercise, Bathing and Hygiene, Sleep and Rest, Visitors and Social
   Activity — same `[PLACEHOLDER_CLINICAL]` marker, same
   generic/conservative/non-prescriptive register as the original 2 docs
   (read first and matched: hedged, "usually," "generally," ends with a
   "your care plan's specific instructions take priority"-style
   disclaimer, never phrased as individualized medical advice). Logged
   in `docs/OPEN_CLINICAL_ITEMS.md` (row 12).
2. **`StubProvider` similarity tuning, not threshold tuning.** With 7
   docs instead of 2, the dev/test stub's crude bag-of-words scoring
   (`Providers::StubProvider#deterministic_vector`) showed real
   cross-doc contamination: every doc in this single-patient narrative
   repeats "she"/"her" in nearly every sentence, which — like
   "today"/"todays" already in `STOPWORDS` — carries zero discriminative
   signal and was measurably drowning out the words that actually
   distinguish e.g. Bathing from Activity. Added `she her he him his
   hers` to `STOPWORDS`. Measured effect (threshold-independent,
   `threshold: -1.0` to see raw scores) on the product owner's own
   example: top match for "Can she eat normal restaurant food this
   weekend?" went from a same-ballpark cluster of docs post-content-only
   (Eating Out 0.298 vs. Visitors 0.199) to a clean top match at 0.326.
3. **Content vocabulary sharpening**, not a threshold change, closed the
   remaining gap. Four of the five new docs (shower/exercise/sleep/
   visitors phrasings) still scored under the existing 0.3 threshold
   after steps 1-2 — rewriting each to use the literal words a caregiver
   would plausibly type (e.g. Bathing and Hygiene Guide now literally
   says "okay for her to **take a** normal **shower**," matching "Is it
   okay for her to **take a shower** today?") pushed every one of the 5
   new topics' representative test question above 0.3: restaurant 0.326,
   shower 0.451, exercise 0.567, sleep 0.623/0.311, visitors 0.378. This
   mirrors exactly how the original 2 docs were already written (their
   bodies closely echo the eval suite's own `in_scope` question
   phrasing) — not a new convention, applying the existing one to 5 more
   docs.
4. **`similarity_threshold` (0.3, `config/ai.yml` dev/test) was measured,
   not changed.** Before touching it, the off-topic/injection ceiling was
   checked against every prompt in `spec/ai_eval/prompts.yml`: `off_topic`
   max raw score 0.183, `injection_attempts` max 0.201 (both measured
   directly via `Retrieval.search(..., threshold: -1.0)`, not filtered by
   category-router short-circuiting, i.e. the true worst case if these
   ever reached retrieval). Since steps 1-3 already got every real
   `in_scope` question (existing 50 + the 5 new-topic questions) above
   0.3 without lowering it, the threshold was left untouched —
   preserving a wide ~0.12 safety margin between the highest off-topic
   score and the threshold, rather than narrowing it to chase a handful
   of borderline matches. If a future KB topic doesn't clear 0.3 through
   content-authorship alone, the same "sharpen vocabulary first" playbook
   applies before touching the shared threshold again.

**Verification**: `rake ai:eval` re-run against the expanded dev DB —
all 5 gate categories still pass (`in_scope` 100% (50/50), `medication_traps`
100% (40/40), `emergencies` 100% (20/20), `injection_attempts` 100%
(20/20), `off_topic` 100% (20/20) info-only) — `docs/AI_EVAL_REPORT.md`
regenerated. Live-tested via `Domain::Ai::Gateway.assistant_reply`
against the real demo caregiver (episode 76): the exact "restaurant food"
question, plus 2 more across the newly-added topics, all returned
`routed: false` with a real citation, not the routed response.

## Consequences

- New/changed backend files: `backend/app/domain/ai/tasks/explain_care_plan_item.rb`,
  `backend/config/prompts/explain_care_plan_item.md`,
  `backend/app/controllers/api/v1/caregiver/care_plan_explanations_controller.rb`,
  `backend/app/domain/ai/gateway.rb` (new `explain_care_plan_item` task
  method), `backend/config/ai.yml` (new timeout entry),
  `backend/app/domain/ai/providers/stub_provider.rb` (`STOPWORDS`
  addition), `backend/db/seeds/knowledge_base.rb` (5 new docs),
  `backend/config/routes.rb` (`POST /api/v1/caregiver/care_plan/explain`).
- New specs: `backend/spec/domain/ai/tasks/explain_care_plan_item_spec.rb`,
  `backend/spec/requests/api/v1/caregiver/care_plan_explanations_spec.rb`.
- New/changed frontend files: `frontend/projects/caregiver/src/app/nav/bottom-nav.{ts,html,css}`,
  `frontend/projects/caregiver/src/app/app.{html,ts}`,
  `frontend/projects/caregiver/src/app/check-in/{check-in.ts,check-in.html,check-in.css}`,
  `frontend/projects/caregiver/src/app/care-plan/care-plan-explanation.service.ts`,
  `frontend/projects/caregiver/src/app/care-plan/care-plan.html` (redundant
  embedded nav removed), `frontend/projects/caregiver/src/styles.css`
  (bottom-nav body padding), all 5 `frontend/projects/caregiver/public/i18n/*.json`.
- `frontend/angular.json`: caregiver's `anyComponentStyle` budget
  `maximumWarning` raised 8kB -> 12kB (cockpit's unchanged) —
  `check-in.css` legitimately grew with two real feature additions (back
  button + nurse-tasks/explain panel); still well under the 16kB error
  ceiling.
- `docs/OPEN_CLINICAL_ITEMS.md`: new rows for the 5 new KB docs (#12) and
  the explain-task's prompt template (#13).
- Nothing about `AssistantPipeline`'s existing safety behavior changed —
  no threshold was lowered, no category-routing logic touched; the fix
  was entirely upstream (more real content to retrieve, sharper
  retrieval scoring for it) of the guardrail chain.
