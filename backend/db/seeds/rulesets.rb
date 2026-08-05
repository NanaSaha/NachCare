# Loads the PLACEHOLDER_CLINICAL seed ruleset into the rulesets table
# (idempotent). Only activates it if nothing else is already active — the
# DB enforces at most one active ruleset (migration 20260802160024).
ruleset_path = Rails.root.join("config/rulesets/ruleset_v0_1.json")
body = JSON.parse(File.read(ruleset_path))
version = body.fetch("version")

unless Ruleset.exists?(version: version)
  status = Ruleset.active.present? ? "draft" : "active"
  Ruleset.create!(version: version, body: body, status: status)
  Rails.logger.info "Seeded ruleset #{version} as #{status}"
end
