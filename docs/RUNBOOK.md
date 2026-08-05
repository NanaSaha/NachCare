# RUNBOOK

Operational reference for running, verifying, and operating NachCare AI
locally. Final delivery-checklist item (playbook Section 10). Companion
docs: `docs/TRACEABILITY.md` (what's built), `docs/OPEN_CLINICAL_ITEMS.md`
/ `docs/OPEN_DECISIONS.md` (what's still placeholder/needs a human), `docs/
adr/` (why things are built the way they are).

## 1. Starting the stack

```
docker compose -f ops/docker-compose.yml up -d postgres redis mailcatcher backend
```

- Backend API: `http://localhost:3001` (container's internal port 3000).
- Mailcatcher UI (dev SMTP): `http://localhost:1080`.
- Postgres: host port `5433` (5432 is commonly taken by other local projects).
- Redis: host port `6379`.

One-off backend commands (rspec, rubocop, rails console/runner, rake
tasks) always go through `docker compose run --rm backend <cmd>` — there
is no local Ruby toolchain on the host (ADR-0001). Code changes hot-reload
into the running `backend` container via the bind mount; if a change
doesn't seem to take effect (rare, but happened once verifying M7 — see
`docs/adr/0009-m7-analytics-hardening.md` #9's writeup), recreate it:
`docker compose -f ops/docker-compose.yml up -d --force-recreate backend`.

Frontend dev servers (from `frontend/`): `npx ng serve caregiver --port
4200`, `npx ng serve cockpit --port 4300`. Check for and kill stale
processes first: `lsof -ti :4200 | xargs -r kill -9` (same for `:4300`).

## 2. Seeding demo data

```
docker compose -f ops/docker-compose.yml run --rm backend bin/rails db:seed
docker compose -f ops/docker-compose.yml run --rm backend bin/rails runner db/seeds/ingrid_scenario.rb
```

`db:seed` loads baseline reference data (drug list, ruleset, knowledge
base, Learn curriculum). `ingrid_scenario.rb` is separate and opt-in (not
run by `db:seed`) — it seeds the full Ingrid/Sabine demo story: a 90-day
episode with 90 real check-ins run through the actual escalation engine, a
day-17 RED flag opened and resolved by a nurse (the "save"), and printed
activation code / nurse login in the Rails log. Idempotent — safe to
re-run. See `ops/demo.sh` for the scripted walkthrough.

## 3. Running the gates

| Gate | Command |
|---|---|
| M0 (foundations) | `ops/verify_m0.sh` |
| M7 (this milestone — analytics/reports/hardening) | `ops/verify_m7.sh` |
| Full backend suite | `docker compose -f ops/docker-compose.yml run --rm -e COVERAGE=1 backend bundle exec rspec` |
| Rubocop | `docker compose -f ops/docker-compose.yml run --rm backend bin/rubocop` |
| Brakeman | `docker compose -f ops/docker-compose.yml run --rm backend bundle exec brakeman --no-pager -i config/brakeman.ignore` |
| bundler-audit | `docker compose -f ops/docker-compose.yml run --rm backend bundle exec bundler-audit check --update` |
| AI eval harness | `docker compose -f ops/docker-compose.yml run --rm backend bundle exec rake ai:eval` (writes `docs/AI_EVAL_REPORT.md`) |
| Frontend (each of `caregiver`/`cockpit`/`shared`) | `npx ng build <project>`, `npx ng lint <project>`, `npx ng test <project> --watch=false --browsers=ChromeHeadless` (from `frontend/`) |
| Playwright e2e | `npm test` (from `e2e/`) — requires both `ng serve` dev servers and the backend running |

## 4. M7 load gate (`ops/k6/load_checkins.js`)

```
docker compose -f ops/docker-compose.yml run --rm backend bin/rails 'load_test:seed[300]'
cp backend/tmp/load_test_tokens.json ops/k6/load_test_tokens.json
docker run --rm --network nachcare_default -v "$(pwd)/ops/k6:/scripts" \
  -e BASE_URL=http://backend:3000 grafana/k6 run /scripts/load_checkins.js
docker compose -f ops/docker-compose.yml run --rm backend bin/rails load_test:teardown
rm -f ops/k6/load_test_tokens.json
```

Posts 300 concurrent, idempotent `POST /api/v1/caregiver/check_ins`
requests against the running dev backend, asserting p95 < 2000ms from k6's
own threshold output. `ops/verify_m7.sh` runs this sequence automatically.
**Known gap** (`docs/OPEN_DECISIONS.md` #12): even after Puma tuning
(`WEB_CONCURRENCY=10`/`RAILS_MAX_THREADS=6`, `ops/docker-compose.yml`),
this converges around p95 ~2.3-2.4s in a local Docker Desktop dev
environment, not fully under the 2s bar — backend CPU never exceeded ~50%
during any run, so this reads as environment overhead (a single shared
dev container), not an application defect. Re-run against a real
deployment target before treating the gate as proven.

`client_uuid` is a native Postgres `uuid` column — any load/smoke-test
script posting to this endpoint must send real UUIDs (`SecureRandom.uuid`
in Ruby, a proper v4 generator in JS/etc.); an invalid-format string is
silently cast to `NULL` by Rails and fails presence validation with a
plain 422, which looks exactly like an application bug until you notice
the input wasn't actually a UUID (this cost real debugging time building
this gate — see ADR-0009 #9).

## 5. Failure drills (`spec/hardening/failure_drills_spec.rb`)

Scripted, not manual: `bundle exec rspec spec/hardening/failure_drills_spec.rb`
exercises LLM-down (both AI providers exhausted -> assistant degrades to
`routed_to_nurse` + opens a cockpit task), push-down (simulated webpush
failure -> immediate SMS fallback, AT-3), and redis-down (Sidekiq enqueue
unreachable -> the triggering action, e.g. a knowledge-doc approval, still
completes instead of 500ing) — all via stubbed failure conditions against
the real domain code, not by stopping the shared docker-compose stack
(see ADR-0009 #8 for why).

## 6. Rate limiting (Rack::Attack)

Throttles: `POST /api/v1/caregiver/activations` and `POST
/api/v1/staff/sign_in`, 5 requests / 20s per IP (sign-in also per-email).
429 response body is `{"error":"rate_limited"}` (no PHI). Uses an
in-process store (`ActiveSupport::Cache::MemoryStore`), not Redis — see
`docs/OPEN_DECISIONS.md` #11 for the multi-process caveat. Disabled by
default in `test` env (`config/initializers/rack_attack.rb`) so the
existing request-spec suite doesn't collide with itself; re-enabled around
`spec/requests/rack_attack_spec.rb` specifically.

## 7. Scheduled jobs (`config/schedule.yml`, sidekiq-cron)

| Job | Schedule | Purpose |
|---|---|---|
| `missed_checkin_scan` | 23:59 daily | R-8: flags episodes with no check-in that day |
| `sla_watch` | every 5 min | Marks open/in_progress flags breached past `sla_deadline_at` |
| `push_confirm_watch` | every 1 min | RED chain: escalates to SMS after 5 min unconfirmed push |
| `daily_reminder` | every 10 min | Sends each caregiver's check-in reminder at their `notification_time` |
| `weekly_digest` | Monday 07:00 | Mails trailing-7-day pilot metrics to each site's site_admin/physician staff |

These only run under a real `sidekiq` worker process consuming the Redis
queue (`bundle exec sidekiq`) — the dev `docker-compose.yml` only runs
`bin/rails server`, so enqueued jobs accumulate in Redis but aren't
processed unless a worker is started separately. Not wired into
`docker-compose.yml` as a default service since none of M0-M7's manual
verification needed a live worker (jobs are exercised directly in specs);
add a `worker: command: ["bundle", "exec", "sidekiq"]` service before
relying on scheduled jobs firing in a running dev/demo instance.

## 8. Analytics / pilot metrics / reports (M7)

`GET /api/v1/staff/analytics/pilot_metrics` (JSON/`.csv`/`.pdf`) — the
five AN-1 metrics (`docs/adr/0009-m7-analytics-hardening.md` #1) for the
requesting staff member's own site (or `?site_id=` for `sysadmin`),
`?from=`/`?to=` (default trailing 30 days). Every staff role can read it,
scoped to their site (`SitePolicy#show?`, reused rather than a new
policy). Computed live from `check_ins`/`flags`/`episodes`/
`assistant_turns` — no caching, so it's always current as of the request.

## 9. Audit reconstruction (AT-8)

`Domain::Audit::EpisodeReconstructor.call(episode:, date: nil)` — given an
episode (and optionally a date), returns the ordered timeline of
`audit_events` rows touching that episode's check-ins/flags/interventions.
Demonstrated end-to-end in `spec/acceptance/at8_audit_reconstruction_spec.rb`.
Use from a Rails console for a real incident review:

```ruby
episode = Episode.find(123)
Domain::Audit::EpisodeReconstructor.call(episode: episode, date: Date.new(2026, 5, 17)).each do |e|
  puts "#{e.at} #{e.actor} #{e.action} #{e.entity_type}/#{e.entity_ref} #{e.payload}"
end
```

## 10. Common operational scenarios

- **AI provider outage**: kill switches `AI_ASSISTANT_ENABLED=false` /
  `AI_COPILOT_ENABLED=false` (env vars, `GET /api/v1/feature_flags`
  reflects state to the frontend) degrade gracefully per-task (Section 6
  #1) without a deploy. The gateway's own provider-chain fallback
  (primary -> retry -> fallback provider) usually absorbs a single
  provider outage before a human needs to touch a kill switch at all.
- **Redis outage**: rate limiting keeps working (in-process store).
  Sidekiq-dependent scheduled jobs stop firing; the one synchronous-path
  enqueue (`KnowledgeDoc#approve!` -> `KnowledgeChunkingJob`) degrades to
  "approval succeeds, chunking silently doesn't happen" — check
  `Rails.logger` for `KnowledgeChunkingJob enqueue failed` and re-run
  `KnowledgeChunkingJob.perform_async(doc_id)` manually once Redis is
  back.
- **Push provider outage**: the RED fallback chain falls back to SMS
  immediately on a simulated/real push failure (AT-3), not just after the
  5-minute unconfirmed window — no operator action needed.
- **Suspected brute-force against caregiver activation or staff login**:
  already throttled (Section 6 above); check `nachcare-backend-1` logs for
  repeated `rate_limited` 429s from a given IP.

## 11. Known environment gaps at end of M7 (see `docs/OPEN_DECISIONS.md` for the full list)

- #11: Rack::Attack's in-process store doesn't coordinate across more than
  one backend process — fine today (single container), revisit before
  horizontal scaling.
- #12: the 300-concurrent load gate doesn't clear <2s p95 in this local
  Docker Desktop environment (~2.3-2.4s observed) — re-verify against a
  real deployment target.
- #10 (pre-existing): Rails 7.2 EOL — planned upgrade out of scope for
  this build per explicit instruction.
