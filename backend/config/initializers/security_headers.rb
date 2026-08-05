# M7 hardening (Section 8, ADR-0009 #7). `require`d directly (not
# autoloaded): initializers run before Zeitwerk's autoload paths are ready
# to resolve a bare `SecurityHeaders` constant, and
# `ActionDispatch::MiddlewareStack#use` doesn't lazily constantize a String
# in this Rails version either (it calls `.new` on whatever it was given
# at build time) — a plain `require` of the file is the straightforward
# fix, same as any other custom Rack middleware wired up in an initializer.
require Rails.root.join("app/middleware/security_headers")

Rails.application.config.middleware.use SecurityHeaders
