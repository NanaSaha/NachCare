module Api
  module V1
    # Section 6 #5: "Kill switches: AI_ASSISTANT_ENABLED, AI_COPILOT_ENABLED
    # env flags; frontend feature-flag endpoint exposes state; UI degrades
    # per AI-5." Unauthenticated like /health — booleans only, no PHI, and
    # both apps (caregiver + cockpit) need it before/without a session.
    class FeatureFlagsController < ActionController::API
      def show
        render json: {
          assistant_enabled: ENV.fetch("AI_ASSISTANT_ENABLED", "true") != "false",
          copilot_enabled: ENV.fetch("AI_COPILOT_ENABLED", "true") != "false"
        }, status: :ok
      end
    end
  end
end
