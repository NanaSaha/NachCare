# ADR-0007: AI gateway provider architecture (M5)

**Status:** Accepted
**Date:** 2026-08-04

## Context

Section 6 specifies `Domain::Ai::Gateway` with a provider abstraction
(`Domain::Ai::Providers::Base#chat`/`#embed`), a primary provider
(`BedrockAnthropicProvider`, AWS Bedrock `eu-central-1`) and a fallback
(`AzureOpenAIProvider`), selected per task from `config/ai.yml`. `.env.example`
already anticipates this (`LLM_PRIMARY_PROVIDER=bedrock_anthropic`,
`LLM_FALLBACK_PROVIDER=azure_openai`, `AWS_REGION`, `AZURE_OPENAI_*`) and
`docs/SUBPROCESSORS.md` already lists both as the intended EU subprocessors.

This dev environment has no AWS/Azure credentials. R9 says: for pure
engineering ambiguity (how to actually implement the model-calling layer
given no live credentials), decide and record an ADR, then move on — don't
guess on safety, but this specific question isn't a safety question.

Two things need to both be true simultaneously:
1. Real adapter code must exist for both providers, gated behind env vars,
   following the same pattern as M4's `WebPushAdapter`/`SmsAdapter` (real
   HTTP calls, fails closed/returns a typed error rather than raising
   uncontrolled exceptions).
2. Every safety-critical guardrail (`EmergencyDetector`, `CategoryRouter`,
   `PostChecker`) and the `rake ai:eval` gate itself must be exercisable
   and *meaningfully assert on classification behavior* without live
   credentials or network access — a pure "provider unavailable ->
   everything degrades to routed_to_nurse" design would make the eval
   suite's "in-scope answered with >= 1 citation" assertion impossible to
   satisfy locally, and would make rspec for the guardrails just test
   "does it fail closed" instead of "does it classify correctly."

## Decision

**Three provider classes, one interface** (`Domain::Ai::Providers::Base`,
`#chat(messages:, system:, max_tokens:, temperature:, json_schema: nil)` /
`#embed(texts:)`):

- `BedrockAnthropicProvider` — real, via `aws-sdk-bedrockruntime` (added to
  Gemfile; handles AWS SigV4 signing, which a bare Faraday client can't do
  without reimplementing it). Region `eu-central-1`, model id from
  `LLM_PRIMARY_MODEL`. `#configured?` is false whenever
  `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY` are blank; `#chat`/`#embed`
  raise `Providers::NotConfiguredError` immediately in that case (no network
  attempt, no hung timeout).
- `AzureOpenAIProvider` — real, via `Faraday` REST calls (api-key header,
  deployment URL from `AZURE_OPENAI_ENDPOINT`/`AZURE_OPENAI_DEPLOYMENT`),
  same `#configured?` gate on `AZURE_OPENAI_KEY`.
- `StubProvider` — deterministic, network-free. Infers *intent* from the
  `json_schema` shape the caller passes (each guardrail stage asks for a
  specific schema: `{emergency:}`, `{category:}`, `{flagged:, span:}`) and
  answers with rule-based logic (keyword/phrase matching reusing the same
  `red_flag_phrases` config the escalation engine's R-10 already uses, plus
  a medication/injection keyword list — see below). For free-text
  generation calls (no `json_schema`: assistant answer, brief, triage/
  callnote drafts, report, translate) it returns a templated response that
  echoes the structured context/citations it was given, so callers that
  check "did I get an answer with a citation" get real, correct-shaped
  behavior in dev/test — not just "some string." `#embed` returns a
  deterministic 1024-dim vector derived from a SHA256 of each input text,
  so cosine-similarity retrieval logic is genuinely exercised (same input
  text -> same vector -> stable similarity ranking) without a live
  embedding model.

**Provider selection is Rails-env-keyed in `config/ai.yml`, not purely
env-var-keyed:** `development` and `test` sections hardcode
`primary: stub, fallback: stub` regardless of `LLM_PRIMARY_PROVIDER`, so a
fresh checkout with no credentials runs the full pipeline deterministically
out of the box (mirrors the existing baked-dev-default pattern in
`config/initializers/active_record_encryption.rb`). `production` reads
`LLM_PRIMARY_PROVIDER`/`LLM_FALLBACK_PROVIDER` from ENV (default
`bedrock_anthropic`/`azure_openai`, matching `.env.example` and
`SUBPROCESSORS.md`). An operator who wants to exercise real Bedrock/Azure
calls from a local dev checkout can still do so by setting
`AI_PROVIDER_OVERRIDE=bedrock_anthropic` (read before the env-keyed
default), documented in `.env.example`.

**Retry/fallback/degradation chain** (`Domain::Ai::Gateway#call!`, used by
every guardrail stage and task): timeout per task type (assistant 6s,
everything else 20s, via Ruby `Timeout.timeout` around the provider call) ->
one retry on the *same* provider -> one attempt on the fallback provider ->
raise `Gateway::AllProvidersFailed`. Each task's public method
(`assistant_reply`, `daily_brief`, ...) rescues `AllProvidersFailed` (and
`NotConfiguredError` bubbling the same way) at the task-method boundary and
returns that task's documented graceful-degradation object. Individual
guardrail-stage failures inside the 4-stage assistant pipeline are *not*
retried from stage 1 — only the failing call itself goes through the
retry/fallback chain — and any stage that exhausts the chain fails the
whole `assistant_reply` call closed to `routed_to_nurse`, consistent with
R3's "if any layer is uncertain, route."

**Medication/injection keyword lists** for the deterministic pre-router and
`StubProvider`'s classification are ordinary multilingual vocabulary
("medication", "dose", "diagnosis", "ignore your instructions" etc.), not
clinical thresholds or alert copy — this is a structural engineering
artifact (a keyword list is code, not a clinical claim), so it lives in
`backend/config/ai_guardrail_keywords.yml` and is *not* logged in
`OPEN_CLINICAL_ITEMS.md`. Non-English entries are machine-drafted for
recall and should be native-reviewed before clinical launch, same caveat
as the DE UI copy (`OPEN_DECISIONS.md` #2) — noted in that file's comments,
not duplicated as a new row.

The 5-language `red_flag_phrases` list (reused from
`config/rulesets/ruleset_v0_1.json`, extended with placeholder `tr`/`ru`/
`ar` entries so the assistant's `EmergencyDetector` has the same coverage
as check-in note matching) *is* clinical content (R1) — already tracked as
`OPEN_CLINICAL_ITEMS.md` #3; the extension is noted there, not a new row.

## Consequences

- `bin/rails runner`/rspec/`rake ai:eval` all work with zero external
  credentials or network access, by design — CI's nightly real-credential
  run (per Section 6's eval harness spec) is a separate, additive check,
  not a prerequisite for this gate.
- The real provider adapters are meaningfully testable by injecting a fake
  Faraday connection (`AzureOpenAIProvider.new(connection: ...)`) or
  stubbing the AWS SDK client the same way M4 tested `WebPushAdapter`
  (constructor-injected dependency, no WebMock/VCR needed — those gems
  aren't in the Gemfile and this ADR doesn't add them).
- Swapping in real credentials in production requires no code change, only
  `ops/.env` — consistent with Section 9's "every open item becomes a
  config/content swap, not a code change."
