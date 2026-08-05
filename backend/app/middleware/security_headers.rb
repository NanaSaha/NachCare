# M7 hardening (Section 8, ADR-0009 #7): baseline security headers on every
# response. A thin Rack middleware, not the `secure_headers` gem —
# ActionController::API has no view-layer CSP DSL to hook into and this app
# has no server-rendered HTML surface, so a new gem is unjustified weight
# for a handful of fixed headers. `default-src 'none'` is correct (not
# lazy-strict): a pure JSON API originates no scripts/styles/images of its
# own for a browser to ever load directly.
class SecurityHeaders
  def initialize(app)
    @app = app
  end

  def call(env)
    status, headers, body = @app.call(env)

    headers["X-Content-Type-Options"] = "nosniff"
    headers["X-Frame-Options"] = "DENY"
    headers["Referrer-Policy"] = "strict-origin-when-cross-origin"
    headers["Content-Security-Policy"] = "default-src 'none'"
    # HTTPS-only, so only meaningful (and only ever served over HTTPS) in
    # production — dev/test run over plain HTTP.
    headers["Strict-Transport-Security"] = "max-age=63072000; includeSubDomains" if Rails.env.production?

    [ status, headers, body ]
  end
end
