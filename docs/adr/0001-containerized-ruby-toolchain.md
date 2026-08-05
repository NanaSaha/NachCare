# ADR-0001: Run the Rails backend's Ruby toolchain inside Docker, not on host

**Status:** Accepted
**Date:** 2026-08-02

## Context

The build playbook (Section 2) locks the backend stack to Ruby 3.3 + Rails 7.2. The
development host has only Ruby 4.0.5 installed globally via Homebrew, with no
version manager (rbenv/rvm/asdf/chruby) present. Installing a second Ruby via
Homebrew is not viable (Homebrew keeps one linked version), and compiling 3.3
from source is slow and adds host-level state this project doesn't own.

Docker and Docker Compose are available and already required by the playbook
for Postgres/Redis/mailcatcher (Section 2, `ops/` row).

## Decision

The backend's Ruby 3.3 / Rails 7.2 toolchain runs exclusively inside Docker
(a `backend/Dockerfile` built from `ruby:3.3-slim`), invoked via
`docker compose run backend ...` / the `ops/verify_m0.sh` script. No Ruby
version is installed on the host. This preserves the locked stack decision
exactly (Ruby 3.3, Rails 7.2) — it changes *where* the toolchain runs, not
*what* it is, so it is not a stack deviation, just an execution environment
choice.

## Consequences

- All `rails`, `bundle`, `rspec`, `rubocop` invocations in docs/scripts go
  through `docker compose run backend <cmd>`.
- Local iteration is slightly slower than a native toolchain (container
  overhead); acceptable for an agent-driven build.
- If a future contributor has Ruby 3.3 natively (via rbenv etc.), they may
  run commands on host against the same `docker compose` Postgres/Redis —
  no code assumes containerized execution.
