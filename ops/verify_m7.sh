#!/usr/bin/env bash
# Verifies the M7 (Analytics, reports, hardening) gate from
# NachCareAI_Agent_Build_Instructions.md, Section 8:
#   "verify_m7.sh = AT suite below green + load + failure drills"
# i.e. this is the LAST milestone gate — the AT-1..AT-10 acceptance suite,
# the k6 load script, and the scripted failure drills, on top of the
# standard rubocop/brakeman/bundler-audit/rspec bar every prior verify_*
# script also holds.
#
# Run from anywhere: ops/verify_m7.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE="docker compose -f ${ROOT_DIR}/ops/docker-compose.yml"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$1"; }
ok() { printf '\033[1;32m✓ %s\033[0m\n' "$1"; }

step "Bringing up infra (postgres, redis, mailcatcher, backend)"
$COMPOSE up -d postgres redis mailcatcher backend
$COMPOSE exec -T postgres sh -c 'until pg_isready -U nachcare >/dev/null 2>&1; do sleep 1; done'
ok "Infra healthy"

step "Backend: bundle install (rack-attack, csv gems added this milestone)"
$COMPOSE run --rm backend bundle install
ok "Backend gems installed"

step "Backend: rubocop"
$COMPOSE run --rm backend bin/rubocop
ok "rubocop clean"

step "Backend: brakeman"
$COMPOSE run --rm backend bundle exec brakeman --no-pager -i config/brakeman.ignore
ok "brakeman clean"

step "Backend: bundler-audit"
$COMPOSE run --rm backend bundle exec bundler-audit check --update
ok "bundler-audit clean"

step "Backend: full rspec suite (incl. M7 domain/hardening/acceptance specs), coverage gate >=85% on app/domain"
$COMPOSE run --rm -e COVERAGE=1 backend bundle exec rspec
ok "rspec green — includes AT-8 (audit reconstruction) and AT-10 (pilot-metrics exact-match) as spec/acceptance/*, and the LLM-down/push-down/redis-down failure drills as spec/hardening/failure_drills_spec.rb"

step "Backend: rack-attack throttle spec explicitly (disabled by default in test env, see config/initializers/rack_attack.rb)"
$COMPOSE run --rm backend bundle exec rspec spec/requests/rack_attack_spec.rb
ok "rate limiting verified"

step "Backend: security headers spec explicitly"
$COMPOSE run --rm backend bundle exec rspec spec/requests/security_headers_spec.rb
ok "security headers verified"

step "M7 failure drills (LLM down, push down, redis down) — explicit step per the gate's own wording"
$COMPOSE run --rm backend bundle exec rspec spec/hardening/failure_drills_spec.rb
ok "failure drills green"

step "Seeding db/seeds/ingrid_scenario.rb (full demo story incl. the day-17 save)"
$COMPOSE run --rm backend bin/rails runner db/seeds/ingrid_scenario.rb
ok "Ingrid scenario seeded (idempotent — safe if already present)"

step "M7 load gate: 300 concurrent check-ins, p95 < 2s (ops/k6/load_checkins.js)"
$COMPOSE run --rm backend bin/rails 'load_test:seed[300]'
cp "${ROOT_DIR}/backend/tmp/load_test_tokens.json" "${ROOT_DIR}/ops/k6/load_test_tokens.json"
# The docker-compose network is named after the project's `name:` directive
# (ops/docker-compose.yml declares `name: nachcare`), NOT this directory's
# basename — a prior version of this script computed it wrong
# ("NachCareAi_default", which doesn't exist) and the k6 container never
# even started as a result. Read the actual declared name instead of
# assuming.
PROJECT_NAME="$(grep -m1 '^name:' "${ROOT_DIR}/ops/docker-compose.yml" | awk '{print $2}')"
NETWORK_NAME="${PROJECT_NAME}_default"
K6_EXIT=0
docker run --rm --network "${NETWORK_NAME}" -v "${ROOT_DIR}/ops/k6:/scripts" \
  -e BASE_URL=http://backend:3000 grafana/k6 run /scripts/load_checkins.js || K6_EXIT=$?
$COMPOSE run --rm backend bin/rails load_test:teardown
rm -f "${ROOT_DIR}/ops/k6/load_test_tokens.json"
if [ "$K6_EXIT" = "0" ]; then
  ok "load gate green: 300 concurrent check-ins, p95 < 2s"
elif [ "$K6_EXIT" = "99" ]; then
  # k6's own documented convention: exit 99 means it ran to completion
  # (every request actually sent/received) but at least one `thresholds`
  # assertion failed — exactly our case (checks: rate=100%, but
  # http_req_duration's p(95)<2000 threshold crossed). Any OTHER non-zero
  # code means k6 itself didn't run cleanly (e.g. the network-name bug
  # this script had earlier, where the container never started at all).
  printf '\n\033[1;31m✗ load gate ran to completion but did NOT clear p95 < 2s in this environment.\033[0m\n'
  printf 'k6''s own summary above shows the actual per-request results (checks/error rate) — read that,\n'
  printf 'not this message, for what really happened. See docs/OPEN_DECISIONS.md #12 and\n'
  printf 'docs/adr/0009-m7-analytics-hardening.md #9 for the measured breakdown from building this gate\n'
  printf '(backend CPU never exceeded ~50%% during prior runs, so it read as Docker-Desktop/single-shared-\n'
  printf 'container overhead, not an application defect — but verify against the summary above, not this\n'
  printf 'canned text). This script fails honestly here rather than silently passing.\n'
  exit 1
else
  printf '\n\033[1;31m✗ k6 itself failed to run (exit %s, see output above — e.g. network/container setup), not a threshold miss.\033[0m\n' "$K6_EXIT"
  exit 1
fi

step "Frontend: npm ci"
(cd "${ROOT_DIR}/frontend" && npm ci)
ok "Frontend deps installed"

step "Frontend: build + lint + test (caregiver, cockpit, shared)"
(cd "${ROOT_DIR}/frontend" && \
  npx ng build shared && npx ng build caregiver && npx ng build cockpit && \
  npx ng lint shared && npx ng lint caregiver && npx ng lint cockpit && \
  npx ng test shared --watch=false --browsers=ChromeHeadless && \
  npx ng test caregiver --watch=false --browsers=ChromeHeadless && \
  npx ng test cockpit --watch=false --browsers=ChromeHeadless)
ok "Frontend build/lint/test clean on all 3 projects"

step "npm audit (high+ only)"
(cd "${ROOT_DIR}/frontend" && npm audit --audit-level=high)
ok "npm audit clean at high severity"

printf '\n\033[1;32mM7 gate green (load latency caveat noted above, if any).\033[0m\n'
printf 'This is the final playbook milestone — see docs/RUNBOOK.md and docs/TRACEABILITY.md for the whole-project state.\n'
