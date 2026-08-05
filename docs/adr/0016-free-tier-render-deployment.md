# ADR-0016: Free-tier ($0/month) Render deployment

## Status

Accepted.

## Context

ADR-0015 designed the initial `render.yaml` Blueprint around a
closer-to-production shape: a paid `starter` `nachcare-backend` web
service with a persistent disk for Active Storage (check-in photos), and
a separate paid `starter` `nachcare-sidekiq` background worker for
`schedule.yml`'s cron jobs and async jobs — roughly $14/month combined.
The product owner asked for a genuinely free deployment instead, since
this is explicitly a demo/staging environment (`docs/DEPLOYMENT.md`'s
opening warning: not cleared for real patient data).

Checked against Render's docs (`render.com/docs/free`) before making any
change: Render's free instance type exists only for **web services**,
**static sites**, **Postgres**, and **Key Value** — there is no free tier
for background workers at all, and free web services cannot have a
persistent disk attached. So getting to $0/month isn't a plan-field
change; it requires two real trade-offs.

## Decision

### Sidekiq merged into the backend web service, not a separate worker

`nachcare-sidekiq` (the separate `type: worker` service from ADR-0015)
is removed. `nachcare-backend`'s `dockerCommand` now points at
`backend/bin/render-web-with-sidekiq`, a small script that starts both
`bundle exec sidekiq` and `bin/rails server` as background processes
inside the one container, traps `SIGTERM`/`SIGINT`, and forwards them to
both children on container stop/redeploy (a naive `bin/rails server &
exec bundle exec sidekiq` — or the reverse — would leave whichever
process isn't PID 1 unable to receive Docker's stop signal at all).
`schedule.yml`'s cron jobs still load automatically
(`config/initializers/sidekiq.rb`'s `Sidekiq.configure_server` block) —
no code change needed there, only how the process is launched.

Verified directly, not just read: built `backend/Dockerfile.production`
with this script as its `dockerCommand`, ran it against the real dev
Postgres/Redis containers, confirmed both Puma (health check on `/up`)
and Sidekiq (processing queued jobs) came up inside the one container,
then `docker stop`'d it and confirmed a clean exit within the grace
period — the signal-forwarding logic actually works, not just reads
correctly.

**Consequence**: `nachcare-backend`'s free-tier spin-down (15 minutes
with no inbound HTTP traffic) now also pauses Sidekiq and
`schedule.yml`'s cron jobs, since they're the same process. A demo
that's visited regularly stays warm; one left idle for hours will have a
slow cold-start first request and may have missed a scheduled job tick
in the meantime. Acceptable for a demo; not how this would be run for
real use (see "Reverting" below).

### No persistent disk — Active Storage becomes ephemeral

`nachcare-backend`'s `disk:` block (1GB, mounted at `/app/storage` for
check-in photo uploads) is removed — free web services can't have one
(Render docs, confirmed before removing it). `storage.yml`'s `local`
service still writes to that path inside the container; the difference
is that path is no longer durable. Uploaded check-in photos are lost on
every restart, redeploy, or spin-down/wake cycle.

No code change was made to route around this (e.g., no S3-compatible
fallback) — that would cost money too (`docs/SUBPROCESSORS.md`'s
S3-compatible storage row is still `TBD`, `docs/OPEN_DECISIONS.md`), and
this ADR's whole point is $0/month. This is a real, visible demo
limitation, not silently accepted: `docs/DEPLOYMENT.md`'s smoke-test
checklist and cost section both flag it.

### `preDeployCommand` doesn't exist on free-tier services

Discovered from a real Blueprint sync attempt, not docs: Render rejects
the whole Blueprint if a free-tier service sets `preDeployCommand`
("pre-deploy command is not supported for free tier services"). ADR-0015's
original design ran `bin/rails db:prepare && bin/rails db:seed` there.
Moved into `bin/render-web-with-sidekiq` itself instead, run on every
container boot rather than only on deploy — safe, since both are
idempotent (migrations no-op when already applied; every seed file
skips already-present rows).

### Database not guaranteed ready on first boot

Also discovered from a real deploy, not something testable without one:
the very first real Blueprint sync had `nachcare-backend` boot and hit
`db:prepare` before `nachcare-db` was actually accepting connections yet
(`PG::ConnectionBad: connection to server at "<private-ip>", port 5433
failed: Connection refused` — a real private-network host that just
wasn't listening yet, not a config/DNS problem). Render doesn't
guarantee a service's dependencies have finished starting before it
boots. Fixed by polling with `pg_isready -d "$DATABASE_URL"` (up to 30
attempts, 5s apart, ~2.5 minutes total) before running `db:prepare`, so
this is a wait, not a retry-forever hope — if the database genuinely
never comes up, the container exits with a clear log line instead of a
raw `PG::ConnectionBad` trace. Verified directly: build under normal
conditions ("Database is ready." within the same second, no added
delay); build against a deliberately unreachable host (confirmed it
polls instead of crashing on the first attempt).

### render.yaml also had three real schema bugs, fixed in the same pass

While rebuilding the service list, `render.yaml` was validated
programmatically against Render's actual published JSON Schema
(`render.com/schema/render.yaml.json`, via Python's `jsonschema` library)
for the first time — ADR-0015's original version had only been
hand-checked against doc prose, which turned out to have produced three
real, independent validation failures:

1. `envVarGroups` used directly on a service (`serverService` has no
   such property in the schema — it's `additionalProperties: false`).
   Groups must be pulled in via a `fromGroup: <name>` entry inside
   `envVars` instead.
2. `nachcare-caregiver`'s `headers` block used a nested
   `{path, headers: [{key, value}]}` shape; the schema's `header`
   definition is flat: `{path, name, value}`.
3. `ipAllowList` was removed entirely from `nachcare-redis` in an earlier
   fix attempt that misread Render's docs as saying an empty array was
   invalid. The schema actually makes `ipAllowList` a **required** field
   on `keyvalue` services, and `[]` is the documented, correct value for
   "no public internet access, same-region private network only" —
   exactly what the backend service needs. Restored.

All three were real causes of Render's opaque "Blueprint file was found,
but there was an issue" sync failure, not hypothetical — the file now
validates cleanly against the real schema.

### Two real, previously-undiscovered bugs found by actually booting the merged process

Neither of these is specific to the free-tier redesign — both were latent
bugs that this ADR's direct end-to-end testing (build the production
image, run it against real Postgres/Redis, watch it boot) happened to be
the first thing in this project's history to actually exercise. Neither
would have been caught by the test suite (which stubs/mocks around both)
or by ADR-0015's original preparation (which never ran a real Blueprint
sync or a live Sidekiq server).

1. **`KnowledgeChunkingJob` had no rescue for `Gateway::AllProvidersFailed`**,
   unlike every other AI task in `app/domain/ai` (`brief.rb`, `triage.rb`,
   `assistant.rb`, etc. all rescue it for graceful degradation). Seeding
   the knowledge base calls this job inline and synchronously
   (`db/seeds/knowledge_base.rb`), so on a fresh database with no AI
   provider configured — this deployment's deliberate default,
   `docs/DEPLOYMENT.md` section 8 — `db:prepare`'s automatic first-run
   seed would hard-crash the whole boot. Fixed in
   `app/jobs/knowledge_chunking_job.rb`: same rescue pattern as
   everywhere else, doc stays approved but un-embedded, a warning is
   logged. Covered by a new spec case.
2. **Sidekiq 7.3.9's scheduler thread crashes on boot** against
   `connection_pool` 3.0.2 — `Sidekiq::Scheduled::Poller#initial_wait`
   calls `@sleeper.pop(total)` with a positional argument, but
   `connection_pool` 3.0 made `TimedStack#pop`'s timeout keyword-only.
   This means `schedule.yml`'s cron jobs (missed-checkin scan, SLA watch,
   reminders, weekly digest, AI watch expiry — all of it) would never
   have fired in any real deployment of this app, free-tier or not. This
   went undetected because `ops/docker-compose.yml` has no `sidekiq`
   service — dev has only ever exercised jobs via direct `.perform`
   calls in specs/seeds, never a live `bundle exec sidekiq` server, until
   this ADR's testing ran one for the first time. Fixed by bumping
   `sidekiq` 7.3.9 -> 7.3.10 (`bundle update sidekiq connection_pool`,
   `backend/Gemfile.lock`) — 7.3.10 itself constrains its `connection_pool`
   dependency to `< 3`, which is the real fix (not a version this project
   chose arbitrarily). Verified directly: rebuilt the image, re-ran it,
   confirmed `SlaWatchJob`/`DailyReminderJob`/`DoseReminderJob`/etc. all
   fired via the scheduler, and shutdown logged a clean "Scheduler
   exiting..." instead of crashing.

## Consequences

- This deployment is genuinely $0/month as configured — 4 services
  (`nachcare-backend`, `nachcare-caregiver`, `nachcare-cockpit`,
  `nachcare-redis`) + 1 database (`nachcare-db`, free for its first 30
  days per Render's Postgres expiry policy, unchanged from ADR-0015).
- Check-in photo uploads don't survive a restart — a real, documented
  demo limitation.
- Scheduled/background jobs only run while the merged process is awake.
- `render.yaml` is now schema-validated, not just hand-checked, closing
  the gap that produced two rounds of Blueprint sync failures.

### Reverting to the paid, closer-to-production shape

If this demo needs to outlive its own limitations (e.g., photos need to
persist, or jobs need to run on a reliable schedule regardless of
traffic), the fix is mechanical: set `nachcare-backend`'s `plan` back to
`starter`, restore its `disk:` block, drop the `dockerCommand` override
(the image's default `CMD` is already plain `bin/rails server`), and
re-add a separate `nachcare-sidekiq` `type: worker` service pointing at
the same image with `dockerCommand: bundle exec sidekiq` — i.e., undo
this ADR's two trade-offs independently or together, each is a small,
self-contained `render.yaml` change.
