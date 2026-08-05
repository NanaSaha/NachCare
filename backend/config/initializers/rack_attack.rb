# M7 hardening (Section 8, ADR-0009 #6): brute-force protection on the two
# unauthenticated credential-exchange surfaces — caregiver activation-code
# exchange (flagged as an M7 concern in ActivationsController's own comment
# since M1) and staff sign-in. Deliberately the gem's default in-process
# `ActiveSupport::Cache::MemoryStore`, not Redis-backed — see the ADR for
# why (rate-limit availability shouldn't depend on Redis health).
#
# Disabled by default in test (below) so the ~15 existing request specs
# that legitimately POST to these endpoints multiple times per file don't
# collide with each other's throttle counters across the whole suite run;
# spec/requests/rack_attack_spec.rb explicitly re-enables it around itself.
class Rack::Attack
  THROTTLE_LIMIT = 5
  THROTTLE_PERIOD = 20 # seconds

  # Explicit, not the gem's own default (`Rails.cache` when Rails is
  # defined): this app's test env sets `config.cache_store = :null_store`
  # (every write/read is a no-op), which would silently make every
  # throttle rule below inert in test. Explicit `MemoryStore` here is also
  # exactly ADR-0009 #6's decision either way — a real Redis-backed
  # `Rails.cache` in some future environment shouldn't couple rate-limit
  # availability to Redis health.
  self.cache.store = ActiveSupport::Cache::MemoryStore.new

  throttle("caregiver_activations/ip", limit: THROTTLE_LIMIT, period: THROTTLE_PERIOD) do |req|
    req.ip if req.path == "/api/v1/caregiver/activations" && req.post?
  end

  throttle("staff_sign_in/ip", limit: THROTTLE_LIMIT, period: THROTTLE_PERIOD) do |req|
    req.ip if req.path == "/api/v1/staff/sign_in" && req.post?
  end

  # Per-email as well as per-IP: a distributed brute-force attempt against
  # one specific staff account, spread across many source IPs, would
  # otherwise slip under the per-IP limit.
  throttle("staff_sign_in/email", limit: THROTTLE_LIMIT, period: THROTTLE_PERIOD) do |req|
    if req.path == "/api/v1/staff/sign_in" && req.post?
      email = req.params.dig("user", "email").presence || req.params["email"].presence
      email&.downcase
    end
  end

  self.throttled_responder = lambda do |_request|
    # No PHI (R5) — just a fixed, contentless 429.
    [ 429, { "Content-Type" => "application/json" }, [ { error: "rate_limited" }.to_json ] ]
  end
end

Rack::Attack.enabled = false if Rails.env.test?

# The gem's own Railtie (`Rack::Attack::Railtie`) inserts the middleware
# into the stack automatically — confirmed by reading the gem source
# directly rather than assuming; no manual `config.middleware.use` needed
# (and doubling it up would double-count every request against the
# throttle limits above).
