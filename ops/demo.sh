#!/usr/bin/env bash
# Boots the full seeded system for a live demo: infra + backend + both
# Angular dev servers + the Ingrid/Sabine story seeded end to end
# (playbook Section 10, final delivery checklist: "Demo script: ops/demo.sh
# boots seeded system"). See README.md for the walkthrough this sets up
# for — caregiver PWA + cockpit side by side.
#
# Run from anywhere: ops/demo.sh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE="docker compose -f ${ROOT_DIR}/ops/docker-compose.yml"

step() { printf '\n\033[1;34m==> %s\033[0m\n' "$1"; }
ok() { printf '\033[1;32m✓ %s\033[0m\n' "$1"; }

step "Bringing up infra + backend"
$COMPOSE up -d postgres redis mailcatcher backend
$COMPOSE exec -T postgres sh -c 'until pg_isready -U nachcare >/dev/null 2>&1; do sleep 1; done'
ok "Backend up at http://localhost:3001"

step "Preparing the database (migrate, then baseline seeds: drugs, ruleset, knowledge base, Learn curriculum)"
$COMPOSE run --rm backend bin/rails db:prepare
$COMPOSE run --rm backend bin/rails db:seed
ok "Baseline data ready"

step "Seeding the Ingrid/Sabine demo scenario (idempotent — safe to re-run)"
$COMPOSE run --rm backend bin/rails runner db/seeds/ingrid_scenario.rb
ok "Ingrid scenario seeded — see the Rails log line above for the activation code, nurse login, and IDs"

step "Killing any stale frontend dev servers on :4200/:4300"
lsof -ti :4200 | xargs -r kill -9 2>/dev/null || true
lsof -ti :4300 | xargs -r kill -9 2>/dev/null || true

step "Starting the caregiver PWA (http://localhost:4200) and cockpit (http://localhost:4300)"
(cd "${ROOT_DIR}/frontend" && npx ng serve caregiver --port 4200 > /tmp/nachcare-caregiver-demo.log 2>&1 &)
(cd "${ROOT_DIR}/frontend" && npx ng serve cockpit --port 4300 > /tmp/nachcare-cockpit-demo.log 2>&1 &)

printf '\nWaiting for dev servers to come up'
for i in $(seq 1 60); do
  printf '.'
  if curl -s -o /dev/null http://localhost:4200 && curl -s -o /dev/null http://localhost:4300; then
    echo
    break
  fi
  sleep 1
done
ok "Both dev servers up (logs: /tmp/nachcare-caregiver-demo.log, /tmp/nachcare-cockpit-demo.log)"

cat <<'EOF'

================================================================
 NachCare AI — demo ready. See README.md for the full walkthrough.

   Caregiver PWA:  http://localhost:4200
   Cockpit:        http://localhost:4300
   Mailcatcher:    http://localhost:1080  (dev SMTP — weekly digest etc.)

   Nurse login (cockpit):
     email:    sabine.demo.nurse@example.eu
     password: correct horse battery staple

   Caregiver activation code: see the Rails log above
   ("Seeded Ingrid demo scenario: ... activation_code=...")

   Cockpit > Analytics shows the pilot metrics dashboard (widen the date
   range back ~90 days to see the day-17 RED flag's numbers).
================================================================
EOF
