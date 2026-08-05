# Be sure to restart your server when you modify this file.
#
# The caregiver and cockpit apps are served from different origins than the
# API (ops/.env.example: CAREGIVER_APP_ORIGIN, COCKPIT_APP_ORIGIN) — real
# cross-origin requests, not same-origin, so this isn't optional.
#
# `expose` for Authorization is required for devise-jwt: it dispatches the
# token via that response header, which browsers hide from JS on
# cross-origin responses unless explicitly exposed.

allowed_origins = [
  ENV.fetch("CAREGIVER_APP_ORIGIN", "http://localhost:4200"),
  ENV.fetch("COCKPIT_APP_ORIGIN", "http://localhost:4300")
]

Rails.application.config.middleware.insert_before 0, Rack::Cors do
  allow do
    origins(*allowed_origins)

    resource "/api/*",
      headers: :any,
      methods: %i[get post put patch delete options head],
      expose: %w[Authorization],
      credentials: false
  end
end
