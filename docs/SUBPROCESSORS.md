# Subprocessors

EU-only external services wired into NachCareAI (rule R8). Each row must be
backed by env-var configuration, never hardcoded endpoints/regions.

| Service | Purpose | Region | Env vars | Status |
|---|---|---|---|---|
| AWS Bedrock (Anthropic Claude Sonnet-class) | Primary LLM gateway provider | `eu-central-1` | `LLM_PRIMARY_MODEL`, `AWS_REGION`, `AWS_*` creds | Real adapter built in M5 (`Domain::Ai::Providers::BedrockAnthropicProvider`, via `aws-sdk-bedrockruntime`), no live credentials/contract yet — see OPEN_DECISIONS #6. Dev/test use a network-free stub provider by default (ADR-0007); this adapter only activates with real creds. |
| Azure OpenAI (EU deployment) | Fallback LLM provider | EU deployment region (TBD) | `AZURE_OPENAI_ENDPOINT`, `AZURE_OPENAI_DEPLOYMENT`, `AZURE_OPENAI_KEY` | Real adapter built in M5 (`Domain::Ai::Providers::AzureOpenaiProvider`, Faraday REST), no live credentials/contract yet. Same stub-by-default behavior as Bedrock above (ADR-0007). |
| SMS adapter | RED-flag fallback chain, missed-day chain | EU provider (TBD) | `SMS_PROVIDER_URL`, `SMS_API_KEY` | `LogAdapter` (dev-only) until a real EU provider is contracted — see OPEN_DECISIONS #5 |
| Email adapter | Notification fallback | EU provider (TBD) | `EMAIL_PROVIDER_URL`, `EMAIL_API_KEY` | `LogAdapter` (dev-only) until a real EU provider is contracted |
| S3-compatible object storage | `check_in_photos` (ActiveStorage), production only | EU region (TBD) | `STORAGE_S3_REGION`, `STORAGE_S3_BUCKET`, `STORAGE_S3_*` creds | Local disk in dev; EU bucket to be selected |

No subprocessor here should ever be pointed at a non-EU region/endpoint.

## Dev/test-only exceptions (NOT EU, NOT for production — ADR-0014)

Added at the product owner's explicit request to get real (non-stub) AI
responses in this dev/demo environment. Both are US-hosted with no EU
region option, a deliberate, documented deviation from R8 confined to
`config/ai.yml`'s `development` block — `production`'s provider list
(the two rows above) is untouched. Neither should ever be set as
`LLM_PRIMARY_PROVIDER`/`LLM_FALLBACK_PROVIDER` in a real deployment.

| Service | Purpose | Region | Env vars | Status |
|---|---|---|---|---|
| Anthropic API (direct) | Dev-only alternate LLM provider | US (no EU option) | `ANTHROPIC_API_KEY`, `ANTHROPIC_MODEL` | Real adapter (`Domain::Ai::Providers::AnthropicProvider`). Registered but not the active `development` primary (see gemini below) — reachable via `AI_PROVIDER_OVERRIDE=anthropic`. As of ADR-0014, the configured account has no usable credit balance. |
| Google Gemini API (direct) | Dev-only active LLM + embeddings provider | US (no EU option) | `GEMINI_API_KEY`, `GEMINI_MODEL`, `GEMINI_EMBEDDING_MODEL` | Real adapter (`Domain::Ai::Providers::GeminiProvider`), active `development` primary. Has a real embeddings endpoint (unlike Anthropic direct), used for real RAG retrieval. Free tier caps at 20 req/min for `gemini-2.5-flash` — sustained heavy use safely degrades to the stub provider per call (Gateway's existing fallback chain), not an error. |
