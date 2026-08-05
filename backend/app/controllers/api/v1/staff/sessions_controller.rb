module Api
  module V1
    module Staff
      # JSON session endpoints for cockpit staff. devise-jwt dispatches the
      # Authorization: Bearer <token> response header automatically for any
      # request matching the configured dispatch/revocation routes
      # (config/initializers/devise.rb) — this controller only needs to
      # shape the JSON body, not touch JWT itself.
      class SessionsController < Devise::SessionsController
        respond_to :json

        # Devise's own `verify_signed_out_user` before_action checks
        # `warden.user(scope: :user, run_callbacks: false)` — with a
        # stateless JWT (no session), Warden has no cached user for this
        # request unless something actually ran the :jwt strategy first.
        #
        # `authenticate_user!` does NOT reliably do that here: it cascades
        # through every default strategy registered for the :user scope
        # (two_factor_authenticatable, then jwt), and if an earlier
        # strategy in that list halts the cascade instead of soft-failing,
        # :jwt never runs even though the Bearer token is valid — verified
        # by hand: `warden.authenticate(:jwt, scope: :user)` (naming the
        # strategy explicitly, skipping the cascade) works every time,
        # `authenticate_user!` does not. Naming :jwt explicitly is also
        # simply correct here regardless of the cascade quirk — signing out
        # is a token operation, not a password/OTP one.
        prepend_before_action -> { warden.authenticate!(:jwt, scope: :user) }, only: :destroy

        private

        def respond_with(resource, _opts = {})
          render json: { user: staff_json(resource) }, status: :ok
        end

        def staff_json(user)
          { id: user.id, email: user.email, role: user.role, language: user.language, site_ref: user.site_ref }
        end
      end
    end
  end
end
