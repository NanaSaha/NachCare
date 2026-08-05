# ADR-0002: Schema inference decisions for Section 5 migrations

**Status:** Accepted
**Date:** 2026-08-02

## Context

Section 5 of the build playbook specifies the data model as a compact prose
list (table name + field list) rather than full DDL. Most fields map
directly; a handful of structural details are left to engineering judgment,
and the companion SRS (which the playbook cites for the authoritative
detail) isn't in the repo (see `docs/OPEN_CLINICAL_ITEMS.md` #1). None of the
decisions below involve clinical content — per R9, pure engineering
ambiguity is decided and recorded here rather than blocked on.

## Decisions

1. **UUID primary keys only where the spec says so.** `patients` and
   `caregivers` get `id: :uuid` (patients explicitly "uuid pk"; caregivers
   lists `uuid` as its first field and is, like patients, referenced from
   external-facing flows — activation codes, push subscriptions — where a
   sequential integer would leak enrollment-order information). Every other
   table uses Rails' default bigint pk.

2. **Foreign key columns are named exactly as the spec writes them**
   (`site_ref`, `episode_ref`, `caregiver_ref`, …), not Rails' default
   `_id` suffix. Implemented as explicit `t.bigint`/`t.uuid` columns +
   `add_foreign_key ... column:` + `add_index`, since `t.references` can't
   target a non-`_id` column name cleanly.

3. **Enums are `string` columns + a `CHECK` constraint**, not native
   Postgres `enum` types. Native Postgres enums can't drop/reorder values
   without table rewrites in older PG and complicate `ALTER TYPE ...  ADD
   VALUE` inside transactions; a string + CHECK is trivially migratable and
   just as strict, at the cost of a few extra bytes per row (acceptable at
   this scale).

4. **`audit_events` and `analytics_events` use polymorphic `*_type` +
   `*_ref` string columns**, not FK-constrained references, because the
   things they point at (`users`, `flags`, `patients`, `caregivers`, …) mix
   bigint and uuid primary keys — a single typed FK column can't span both.
   `*_ref` is stored as `string` (a `bigint` id stringified, or a uuid) with
   `*_type` naming the table. This is also required by R6: an audit row
   must remain valid/immutable even if the entity it describes is later
   deleted logically elsewhere — a hard FK would make that impossible to
   enforce (`ON DELETE` would violate append-only).

5. **`assistant_conversations` carries `episode_ref`, `caregiver_ref`,
   `language`, and `started_at`**, though Section 5 only itemizes fields for
   `assistant_turns` under the combined heading. A conversation needs an
   owning episode and caregiver to assemble AI gateway context (Section 6:
   "Prompt assembly only from templates + structured context") — without
   them the turn-level fields (`retrieval_refs`, `guardrail_verdicts`, etc.)
   have nothing to attach to.

6. **`messages.sender`** is a `string` + CHECK constraint
   (`nurse|caregiver|system|ai`), matching the four actor kinds that appear
   elsewhere in the playbook (nurse-authored, caregiver-authored, automated
   system copy, AI-drafted-then-sent).

7. **`notification_attempts` carries a non-null `caregiver_ref`** (every
   notification has a recipient) in addition to the spec's nullable
   `flag_ref` (routine reminders/digests aren't tied to a flag; RED-chain
   escalations are).

8. **`interventions.actor_ref`** is a non-null FK to `users` — every
   intervention has a human actor per the "AI-flagged, human-verified" trust
   rule (Section 0); AI-drafted content lives in `note_ai`, never as the
   actor itself.

## Consequences

Any of these can be revisited without clinical/regulatory review — they're
structural. Revisit if the SRS materializes and specifies otherwise.
