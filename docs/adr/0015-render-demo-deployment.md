# ADR-0015: Render Blueprint for the public demo/staging deployment

**Status:** Accepted
**Date:** 2026-08-05

## Context

The product owner asked for NachCareAI to be deployable to a real, public
URL on Render.com — explicitly a **demo/staging** deployment, not a
production system cleared for real patient data (see `docs/DEPLOYMENT.md`
and `docs/OPEN_DECISIONS.md`). This required several decisions the codebase
had left open, since everything to date has run only in
`ops/docker-compose.yml`'s dev stack (ADR-0001).

## Decisions

### 1. A separate `backend/Dockerfile.production`, not a restructured shared Dockerfile

`backend/Dockerfile` is explicitly dev-only per its own header comment
(bind-mount pattern, `bundle install` with dev/test gems, no non-root user).
Rewriting it in place to also serve production would risk breaking the
local dev loop this whole project depends on (explicit constraint: local
dev must keep working unchanged). A second file,
`backend/Dockerfile.production`, is a two-stage build (`build` stage
compiles native gem extensions with `build-essential`/`libpq-dev`/
`libyaml-dev`; final stage is `ruby:3.3-slim` + `libpq5`/`curl`/
`postgresql-client` only, no compiler toolchain) that:

- installs only production gems (`BUNDLE_WITHOUT="development:test"`)
- copies code in rather than bind-mounting it
- runs as a non-root `rails` user (uid/gid 1000)
- reuses `backend/bin/docker-entrypoint` unchanged (it already only runs
  `db:prepare` when the command is exactly `./bin/rails server`, and just
  execs anything else — e.g. the Sidekiq worker's `bundle exec sidekiq`
  override — untouched)

No `assets:precompile` step exists because the app is `config.api_only =
true` with no `sprockets`/`propshaft` gem in the Gemfile — confirmed by
reading `Gemfile` and `config/application.rb`, not assumed.

Verified locally: `docker build -f backend/Dockerfile.production
backend/` succeeds (689MB final image); the built image boots Rails in
`RAILS_ENV=production` (`bin/rails runner "puts 'boot ok'"` with a
throwaway `SECRET_KEY_BASE`/encryption-key env, no live DB) and runs as
`rails:rails`, not root (`docker run --rm <image> whoami` → `rails`).

### 2. Persistent disk for ActiveStorage, not S3 — scoped to the web service only

`config/environments/production.rb` already sets
`config.active_storage.service = :local` (disk, `storage.yml`'s `local:`
service, `Rails.root.join("storage")`). `docs/SUBPROCESSORS.md` already
flags a real S3-compatible bucket as a **separate, not-yet-made** decision
(EU region TBD) — introducing one here to solve a demo-scope problem would
make that call unilaterally, which is out of scope for a deployment-prep
task. Render supports persistent disks on paid (non-free) web
service/private-service/worker plans, single-instance only, incompatible
with autoscaling or cron jobs (render.com/docs/disks, fetched while
preparing this ADR) — a pragmatic fit for a single-instance demo backend.

`render.yaml` attaches a 1 GB disk to `nachcare-backend` only (mount path
`/app/storage`, matching the production image's `WORKDIR`), **not** to
`nachcare-sidekiq`. Checked directly (not assumed): `grep`ing
`backend/app/jobs` for ActiveStorage/attach/blob usage returns nothing —
only two web controllers (`check_in_photos_controller.rb`,
`messages_controller.rb`) touch ActiveStorage blobs, and PDF generation
(`code_sheet_pdf.rb`, `pilot_metrics_pdf.rb`) streams directly via
`send_data`, never persisting to `ActiveStorage`. A single disk on the web
service is therefore sufficient; Render disks can't be shared across
services anyway.

This forces `nachcare-backend`'s plan to be a paid tier (`starter`) even
though the rest of the demo defaults to free tiers where possible — see
`docs/DEPLOYMENT.md` for the cost breakdown.

### 3. `db:seed` auto-runs on every deploy; `ingrid_scenario.rb` stays a manual step

`db/seeds.rb` only requires four files (`drugs`, `rulesets`,
`knowledge_base`, `content_items`) — all four are idempotent (each checks
for existing rows before creating anything), so running `bin/rails
db:seed` in `render.yaml`'s `preDeployCommand` on every deploy is safe and
gives a fresh environment real drug type-ahead data, an active ruleset,
and RAG-citable knowledge content instead of empty screens.

`db/seeds/ingrid_scenario.rb` is **not** part of `db/seeds.rb` — it's a
separate, explicit script (`bin/rails runner db/seeds/ingrid_scenario.rb`)
that reproduces the full Ingrid/Sabine demo story end-to-end through the
real escalation pipeline, including a nurse (`sabine.demo.nurse@example.eu`)
and site admin login with a **fixed, human-readable password**
(`"correct horse battery staple"` — a well-known example password, not a
secret). Auto-running this on every deploy of a public-facing demo would
put a predictable staff credential live without the product owner
consciously deciding that's acceptable for a public URL. It stays a
manual, documented `render exec`/shell one-off — see
`docs/DEPLOYMENT.md`'s "Seed the Ingrid demo scenario" section, which also
surfaces the credential explicitly rather than burying it.

### 4. `preDeployCommand: bin/rails db:prepare && bin/rails db:seed`, on the web service only

`db:prepare` creates the database on the very first deploy and applies
pending migrations on every subsequent one (idempotent either way) —
chosen over a bare `db:migrate` because it also handles the
never-yet-existing fresh Render Postgres database on day one without a
separate manual `db:create` step. Declared only on `nachcare-backend`,
not `nachcare-sidekiq` — both services share one Postgres instance, and
Render syncs a Blueprint's services together, so one `preDeployCommand`
covers both before either takes traffic.

### 5. `DATABASE_URL`, not discrete `POSTGRES_*` vars, for production

`ops/docker-compose.yml`'s discrete-vars pattern
(`POSTGRES_HOST`/`PORT`/`USER`/`PASSWORD`) exists there specifically
because `RAILS_ENV` varies per invocation against the *same* Postgres
container (dev vs. test databases) — that reason doesn't apply to a
single-purpose production deployment. `backend/config/database.yml`'s
`production:` block was previously untouched Rails-generator boilerplate
(`database: app_production`, `username: app`,
`password: ENV["APP_DATABASE_PASSWORD"]`) — never wired to anything real,
confirmed by grepping for `APP_DATABASE_PASSWORD` (zero other references
in the codebase). Render's managed Postgres exposes a single
`connectionString` property; `render.yaml` wires it via `fromDatabase` to
`DATABASE_URL`, and `database.yml`'s `production:` block now reads
`url: <%= ENV["DATABASE_URL"] %>` (Rails merges URL-derived connection
info over the `default` anchor's `pool`/`encoding`, per the file's own
pre-existing comment block).

### 6. `SECRET_KEY_BASE` / encryption keys / peppers: Render-generated, not transported

`config/credentials.yml.enc` is tracked in git but `config/master.key` is
correctly gitignored and was never committed — confirmed by
`git ls-files | grep master.key` (no match). No code reads
`Rails.application.credentials` for anything load-bearing (only commented-out
example blocks in `storage.yml`) — confirmed by grepping the codebase.
This matches the task's assumption: nothing here has ever depended on
`credentials.yml.enc` being decryptable, so there's no real secret to
transport out of it.

Rather than running `bin/rails secret` locally and pasting a value into
`render.yaml` (which would mean the secret existed, however briefly, in
this agent's output/transcript and in a shell history), `SECRET_KEY_BASE`,
the three `ACTIVE_RECORD_ENCRYPTION_*` keys, and the two
`CAREGIVER_*_PEPPER` values all use Render's native `generateValue: true`
Blueprint field — Render generates and stores each one directly at
Blueprint-sync time, and they never appear in this repo, this ADR, or any
chat transcript. `DEVISE_JWT_SECRET_KEY` is left unset entirely;
`config/initializers/devise.rb` already falls back to
`Rails.application.secret_key_base` when it's absent, so a second
generated secret would be redundant.

### 7. VAPID keys are the one secret that had to be generated up front, not by Render

Every other secret above is backend-only, so Render's blueprint-time
`generateValue: true` works cleanly. VAPID keys are different: the
**public** half must be baked into the caregiver PWA's production
JavaScript bundle at Angular build time
(`frontend/projects/caregiver/src/environments/environment.prod.ts`),
which happens outside Render's control and before any backend env var
exists. That means the public and private halves of this specific EC
keypair had to be generated together, up front, by us — Render can't
retroactively compute a matching public key for a `generateValue`'d
private key (it has no curve math step in the Blueprint spec).

Generated the same way ADR-0006 generated the dev keypair — raw
`OpenSSL::PKey::EC.generate("prime256v1")`, base64url-encoded
(`padding: false`), the exact byte lengths (65-byte public, 32-byte
private) the `webpush` gem's `VapidKey` class expects — run inside the
built `backend/Dockerfile.production` image itself, so the keys are
generated under the identical Ruby 3.3 / OpenSSL 3.0 runtime they'll
actually run under in production (not the host's different Ruby/OpenSSL).
The public key is committed in `environment.prod.ts` and in
`render.yaml` as a plain value (VAPID public keys are meant to be
public — sent to every browser). The private key is `sync: false` in
`render.yaml` (Render prompts for it once at Blueprint creation) and was
handed to the product owner directly, once, outside git — see
`docs/DEPLOYMENT.md`.

### 8. AI provider keys stay unset in production — and production's real behavior without them

Per ADR-0014/R8, `ANTHROPIC_API_KEY`/`GEMINI_API_KEY` are dev-only,
non-EU, explicitly never meant for a real deployment config.
`config/ai.yml`'s `production:` block (`providers.primary:
bedrock_anthropic`, `fallback: azure_openai`) is left uncredentialed too
(no `AWS_*`/`AZURE_OPENAI_*` secrets in `render.yaml`) since there are no
real Bedrock/Azure contracts yet (`docs/OPEN_DECISIONS.md` #6).

Read `Domain::Ai::Gateway#call!`/`#attempt` directly to confirm what this
actually does, rather than assuming: with both `primary_provider` and
`fallback_provider` unconfigured, every `attempt` returns `nil`
(`provider.configured?` gate), `call!` raises `AllProvidersFailed`, and
each `Domain::Ai::Tasks::*` class catches that and returns its
already-documented graceful-degradation object per ADR-0007 (assistant →
`routed_to_nurse` response + cockpit task; brief → template-only,
non-AI text; drafts → `nil`, UI hides the draft panel). **This is not
"the stub provider" answering** — `config/ai.yml`'s `production` block
has no `stub` fallback (only `development`/`test` do), a deliberate
existing choice this deployment doesn't change. `AI_ASSISTANT_ENABLED`/
`AI_COPILOT_ENABLED` are left `true` so the demo shows these real
degraded-but-functional UI states rather than hiding AI-adjacent screens
outright.

### 9. Region: `frankfurt` for everything that accepts a region

Render's only EU region is `frankfurt` (`oregon|ohio|virginia|frankfurt|
singapore` per the current Blueprint schema). Every region-capable
service (`nachcare-backend`, `nachcare-sidekiq`, `nachcare-db`,
`nachcare-redis`) is pinned there, matching rule R8's EU-only posture even
though this is explicitly "just a demo" — consistency with the rest of
the project's stance, not a new requirement introduced here. Static sites
(`nachcare-caregiver`, `nachcare-cockpit`) don't accept a `region` field
at all (Render serves them from its global CDN); this is a genuine
platform constraint, not a deviation.

### 10. Free-tier defaults for Postgres and Key Value, flagged loudly, not silently chosen

Render's free Postgres plan expires 30 days after creation (14-day grace
period, then deletion of the database and all its data) —
render.com/changelog, confirmed while preparing this file. Defaulting
`nachcare-db` to `plan: free` avoids imposing a recurring cost on the
product owner's behalf without being asked, but the 30-day clock is a
real trap for a demo meant to stay up — it's called out prominently in
`docs/DEPLOYMENT.md`, with the one-line `render.yaml` change
(`plan: basic-256mb`) to remove it. `nachcare-redis` (Render's "Key
Value" product; `keyvalue` is the current Blueprint type, `redis` a
deprecated alias) also defaults to `free`; Sidekiq queue data would be
lost on a Redis restart on the free tier, but that's a demo-scope
inconvenience (missed/duplicate background jobs get retried), not a data
-loss risk on the same order as the primary database expiring.

### 11. pgvector on Render Postgres — confirmed available, but not blueprint-declarable

Confirmed via Render's own docs/community posts (not assumed): pgvector
is available on Render Postgres and enabled per-database with
`CREATE EXTENSION IF NOT EXISTS vector;` — but `render.yaml`'s `databases`
schema has no field for declaring extensions (checked against the current
Blueprint spec, no such key documented). This has to be a manual one-time
step after the first Blueprint sync — documented precisely in
`docs/DEPLOYMENT.md`, including the psql command and where to run it from
(Render's dashboard "Connect" shell, or `render psql` if the CLI is set
up), since the app's own migrations (`neighbor`/`pgvector` gems) assume
the extension already exists.

## Consequences

- Everything above that could be checked locally (Dockerfile build/boot/
  non-root user, Angular production builds and their real output paths,
  the full backend test suite + rubocop after the `database.yml` change,
  hand-validated YAML syntax against the documented Blueprint schema) was
  checked directly, not assumed — see `docs/DEPLOYMENT.md` for the exact
  commands and output.
- Everything that requires a real Render account — the Blueprint actually
  syncing, pgvector's `CREATE EXTENSION` step, whether `fromService`/
  `fromDatabase` wiring resolves the way the fetched docs describe,
  whether `preDeployCommand` behaves as documented for `runtime: docker`
  services — is genuinely unverified. `docs/DEPLOYMENT.md` marks each of
  these explicitly rather than implying they were tested.
- `backend/Dockerfile` (dev) and `ops/docker-compose.yml` are untouched;
  confirmed via `git diff --stat` showing no changes to either, and via a
  full `bundle exec rspec && bundle exec rubocop` re-run inside the
  existing dev container (616 examples / 0 failures, 392 files / no
  offenses) after the `database.yml` production-block edit.
