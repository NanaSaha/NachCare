module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      self.current_user = authenticate!
    end

    private

    # No cookie session (API-only, stateless JWT — same auth model as the
    # HTTP API). The client passes the same Bearer token it uses for HTTP
    # requests as a `token` query param on the cable URL, since WebSocket
    # connections can't set an Authorization header from the browser.
    #
    # ADR-0010: `TokenStore` (cockpit frontend) stores the *entire*
    # Authorization header value devise-jwt issues, `"Bearer <jwt>"` — the
    # correct thing to hand `HttpClient`'s Authorization header, but the
    # cable URL's `token` param needs the bare JWT. Every existing
    # `connect()` call site (FlagsLiveService, and this phase's
    # CareActivityLiveService) sends the value as-is with the `Bearer `
    # prefix still attached, which `Warden::JWTAuth::TokenDecoder`/`JWT.decode`
    # can't parse — every cable connection was silently rejected as
    # unauthorized before this fix (discovered while manually verifying
    # this phase's realtime caregiver-activity feed; it also silently
    # broke the pre-existing triage-queue live updates). Stripped here,
    # once, centrally — matching the same `.sub(/\ABearer /, "")` pattern
    # `CaregiverAuthenticatable` already uses for the HTTP path — rather
    # than fixing every frontend call site individually.
    def authenticate!
      token = request.params[:token].to_s.sub(/\ABearer /, "")
      reject_unauthorized_connection if token.blank?

      payload = Warden::JWTAuth::TokenDecoder.new.call(token)
      user = User.find_by(id: payload["sub"])
      reject_unauthorized_connection unless user && payload["jti"] == user.jti

      user
    rescue JWT::DecodeError
      reject_unauthorized_connection
    end
  end
end
