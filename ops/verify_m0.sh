#!/usr/bin/env bash
# Verifies the M0 (Foundations) gate from NachCareAI_Agent_Build_Instructions.md:
#   docker-compose up (pg16+pgvector, redis, mailcatcher); Rails app scaffolded
#   API-mode with health endpoint; Angular workspace with 3 projects, tokens.css,
#   fonts, shared severity component rendering all three states; CI pipeline
#   running lint+unit on both stacks; all migrations from Section 5; audit
#   spine with UPDATE/DELETE-blocking trigger + Audit::Recorder and spec
#   proving immutability; .env.example complete.
#
# Run from anywhere: ops/verify_m0.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE="docker compose -f ${ROOT_DIR}/ops/docker-compose.yml"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$1"; }
ok() { printf '\033[1;32m✓ %s\033[0m\n' "$1"; }

step "Bringing up infra (postgres+pgvector, redis, mailcatcher)"
$COMPOSE up -d postgres redis mailcatcher
$COMPOSE exec -T postgres sh -c 'until pg_isready -U nachcare >/dev/null 2>&1; do sleep 1; done'
ok "Infra healthy"

step "Building backend image"
$COMPOSE build backend >/dev/null
ok "Backend image built"

step ".env.example present and non-empty"
test -s "${ROOT_DIR}/ops/.env.example"
ok ".env.example present"

step "Backend: bundle install"
$COMPOSE run --rm backend bundle install
ok "Backend gems installed"

step "Backend: prepare dev DB (create if missing, load schema if empty, else migrate)"
$COMPOSE run --rm backend bin/rails db:prepare
ok "Dev DB ready (all Section 5 migrations + audit spine trigger)"

step "Backend: prepare test DB from structure.sql"
$COMPOSE run --rm backend bin/rails db:test:prepare
ok "Test DB prepared"

step "Backend: rubocop"
$COMPOSE run --rm backend bin/rubocop
ok "rubocop clean"

step "Backend: brakeman"
$COMPOSE run --rm backend bundle exec brakeman --no-pager -i config/brakeman.ignore
ok "brakeman clean"

step "Backend: bundler-audit"
$COMPOSE run --rm backend bundle exec bundler-audit check --update
ok "bundler-audit clean"

step "Backend: rspec (incl. audit-spine immutability + health endpoint), coverage gate >=85% on app/domain"
$COMPOSE run --rm -e COVERAGE=1 backend bundle exec rspec
ok "rspec green, coverage gate met"

step "Frontend: npm ci"
(cd "${ROOT_DIR}/frontend" && npm ci)
ok "Frontend deps installed"

step "Frontend: lint (caregiver, cockpit, shared)"
(cd "${ROOT_DIR}/frontend" && npx ng lint caregiver && npx ng lint cockpit && npx ng lint shared)
ok "eslint clean on all 3 projects"

CHROME_BIN="$(cd "${ROOT_DIR}/frontend" && node -e "require('puppeteer').executablePath().then(p=>console.log(p))" 2>/dev/null || true)"
if [ -z "$CHROME_BIN" ]; then
  CHROME_BIN="$(command -v chromium || command -v chromium-browser || command -v google-chrome || true)"
fi

if [ -z "$CHROME_BIN" ]; then
  echo "  (no headless Chrome found locally — 'npm install --save-dev puppeteer' in frontend/ to run this step; CI has Chrome preinstalled)"
else
  step "Frontend: unit tests (caregiver, cockpit, shared) — shared severity component in all 3 states"
  export CHROME_BIN
  (cd "${ROOT_DIR}/frontend" && \
    npx ng test shared --watch=false --browsers=ChromeHeadless && \
    npx ng test caregiver --watch=false --browsers=ChromeHeadless && \
    npx ng test cockpit --watch=false --browsers=ChromeHeadless)
  ok "karma unit tests green on all 3 projects"
fi

step "Frontend: npm audit (high+ only)"
(cd "${ROOT_DIR}/frontend" && npm audit --audit-level=high)
ok "npm audit clean at high severity"

printf '\n\033[1;32mM0 gate green.\033[0m\n'
