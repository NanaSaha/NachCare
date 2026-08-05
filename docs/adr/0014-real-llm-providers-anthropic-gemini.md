# ADR-0014: Direct Anthropic and Gemini API providers for real dev/test AI responses

## Status

Accepted (dev/test only — see explicit non-goal below).

## Context

Every AI feature in the app (M5's assistant/guardrails, triage/call-note
drafts, briefs, reports, translation, M12's shadow risk rationale, M13's
care-plan explanations) had only ever run against `Domain::Ai::Providers::
StubProvider` in this environment — no real LLM credentials were ever
configured (`docs/OPEN_DECISIONS.md` #6). The product owner asked
specifically to configure a real provider so real responses could be seen
and evaluated, first offering an Anthropic API key, then a Google Gemini
API key once the Anthropic account turned out to have no usable credit
balance.

The app's only pre-existing real provider integrations
(`BedrockAnthropicProvider`, `AzureOpenaiProvider`) were deliberately built
for R8 (EU-only externals) — AWS Bedrock `eu-central-1` and an EU Azure
OpenAI deployment. Neither Anthropic's direct API
(`api.anthropic.com`) nor Google's direct Gemini API
(`generativelanguage.googleapis.com`) has an EU-region option — both are
US-hosted. This is a **known, deliberate deviation** from R8, accepted
here only because:

1. This environment holds no real patient data — it's the same demo/dev
   database used throughout this entire build.
2. `docs/OPEN_DECISIONS.md` #6 already required a real legal/DPA sign-off
   process before any provider touches production data regardless of
   which one is ultimately chosen — that gate is untouched by this ADR.
3. The product owner explicitly asked for this, understanding the
   trade-off as explained before building it.

**This must not be treated as a template for production configuration.**
`config/ai.yml`'s `production:` block is untouched — still
`bedrock_anthropic`/`azure_openai` only. Neither `anthropic` nor `gemini`
should ever be set as `LLM_PRIMARY_PROVIDER`/`LLM_FALLBACK_PROVIDER` in a
real deployment without revisiting this decision.

## Decision

### Two new provider classes

- `Domain::Ai::Providers::AnthropicProvider` — direct Anthropic Messages
  API (`api.anthropic.com/v1/messages`), same request/response shape as
  `BedrockAnthropicProvider` (Bedrock's Claude body format *is* the
  Anthropic Messages format) but plain Faraday + an `x-api-key` header
  instead of AWS SigV4. `#embed` always raises `NotConfiguredError` —
  Anthropic has no embeddings endpoint.
- `Domain::Ai::Providers::GeminiProvider` — Google's `generateContent`/
  `batchEmbedContents` REST API. Chat uses `contents`/`systemInstruction`
  (Gemini's shape differs from OpenAI/Anthropic-style `messages`+`system`
  arrays — mapped in the provider, not leaked to callers).
  `generationConfig.responseMimeType: "application/json"` is set when a
  `json_schema` guardrail call is made, which Gemini honors reliably (more
  so than hoping free text parses as JSON).

Both registered in `Gateway::PROVIDER_CLASSES` (`"anthropic"`, `"gemini"`)
alongside the existing three. Both gated by `configured?` checking their
respective API key env var, exactly like every other provider — an
unconfigured provider is skipped by `Gateway#call!`'s retry/fallback
chain, never attempted.

### Gemini chosen as `development`'s active primary, not Anthropic

`config/ai.yml`'s `development.providers.primary` is `gemini`, not
`anthropic`, specifically because **Gemini has a real embeddings
endpoint** (`gemini-embedding-001`, requested at `outputDimensionality:
1024` to exactly match the existing `knowledge_chunks.embedding
vector(1024)` column via MRL truncation — no schema/migration needed).
Anthropic has no embeddings API at all, so RAG retrieval would have kept
using the stub's crude feature-hashing regardless of how good Anthropic's
chat answers were — the exact retrieval-coverage problem from ADR-0013
would have persisted for the *contents* of AI-generated answers even
though the model itself improved. `anthropic` stays registered and
reachable via `AI_PROVIDER_OVERRIDE=anthropic` if its account ever gets
credit and someone wants to compare it, but it is not the active default.

`fallback` stays `stub` for both providers (not each other) — the stub is
the only provider that is always configured, has zero latency/cost/rate
limit, and can always serve `#embed` — a real safety net, not just a
second attempt at another rate-limited external call.

### Similarity threshold recalibrated for real embeddings

`development.similarity_threshold` was `0.3`, calibrated specifically for
the stub's crude feature-hashing cosine scores (see the ADR-0007-era
comment still in `config/ai.yml`). Real Gemini embeddings produce a
completely different score distribution — empirically measured against
the seeded demo knowledge base (`db/seeds/knowledge_base.rb`, 7 approved
docs after ADR-0013's expansion):

| Query | Best match | Similarity |
|---|---|---|
| "Can she eat normal restaurant food this weekend?" | Eating Out and Travel Guide | 0.712 |
| "What are some easy low-salt snacks..." | Low-Salt Day Guide | 0.696 |
| "Is it okay for her to go for short walks?" | Activity and Exercise Guide | 0.796 |
| "What's the weather like tomorrow?" (off-topic) | Bathing and Hygiene Guide | 0.487 |
| "Who won the football match last night?" (off-topic) | Sleep and Rest Guide | 0.457 |

In-scope queries clustered 0.696–0.796; off-topic queries clustered
0.457–0.487. `similarity_threshold: 0.55` sits with real margin (0.14+)
on both sides of that gap. The production default (`0.75`, for real
Bedrock/Azure embeddings) is untouched — this project has never measured
those against this KB, so no basis to change it. **If this environment
ever runs with `primary: stub` again** (no `GEMINI_API_KEY`), 0.55 is far
too strict for the stub's much lower absolute scale — revert to 0.3 in
that case; this is noted inline in `config/ai.yml`.

### Existing knowledge_chunks needed re-embedding, not just re-threshold

The 7 approved `KnowledgeDoc`s' `knowledge_chunks.embedding` vectors were
computed and persisted by `KnowledgeChunkingJob` back when the only
provider was `stub` (at each doc's original approval time). Comparing a
freshly-computed Gemini query vector against a stub-computed stored chunk
vector is comparing two unrelated vector spaces — not meaningfully
different from comparing to random noise. This was the actual root cause
of an initial round of live testing where every question (even ones that
scored well in isolated embedding-similarity tests) still routed as
out-of-scope: the *raw* embedding calibration was correct, but the
*stored* chunk vectors hadn't been recomputed yet. Fixed by re-running
`KnowledgeChunkingJob.new.perform(doc.id)` for all 7 approved docs against
the now-real Gemini embedder. Anyone re-approving a doc, or adding a new
one, gets fresh Gemini-space embeddings automatically going forward (the
job already re-embeds on every approval) — this was a one-time backfill
for docs approved before this ADR.

### Credential storage

Real API keys live in `ops/.env` (already gitignored per
`.gitignore`), read into the `backend` service's environment via Docker
Compose's automatic `${VAR}` substitution — **not** hardcoded into the
tracked `docker-compose.yml`, unlike the self-generated/harmless
dev-only VAPID keypair (ADR-0006) already inline there. `ops/.env.example`
documents the variable names (`ANTHROPIC_API_KEY`/`ANTHROPIC_MODEL`,
`GEMINI_API_KEY`/`GEMINI_MODEL`/`GEMINI_EMBEDDING_MODEL`) with empty
values, as the template for anyone else setting this up.

## Known limitation: Gemini free tier rate limit

`gemini-2.5-flash`'s free tier caps at 20 requests/minute
(`generativelanguage.googleapis.com/generate_content_free_tier_requests`).
Sustained interactive use (or back-to-back manual testing) can exceed
this; when it does, Gemini returns `429 RESOURCE_EXHAUSTED`, which
`GeminiProvider#chat`/`#embed` correctly surface as `ProviderError`, and
`Gateway#call!`/`#embed!`'s existing retry-then-fallback chain correctly
and safely degrades to the stub provider for that one call — the
caregiver never sees an error, just a lower-quality (stub-templated)
response for that turn. This is the intended resilience behavior (same
as any other provider outage), not a bug, but worth knowing: real answers
will be visibly less frequent under heavy testing than they will be under
normal, spaced-out real usage.

## Consequences

- Real, working AI responses (chat *and* embeddings-driven retrieval) are
  now genuinely exercisable in this dev environment for the first time in
  the project.
- A second real, un-credentialed provider (`anthropic`) is fully built and
  spec-covered but currently unreachable in this environment (billing) —
  ready to switch to instantly if that changes.
- The R8 EU-only deviation is real, documented, and confined to
  `development` config only — `production`'s provider list is untouched.
- `docs/SUBPROCESSORS.md` gets two new rows, both marked non-EU/dev-only.
