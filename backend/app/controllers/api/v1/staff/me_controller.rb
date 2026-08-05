module Api
  module V1
    module Staff
      # Minimal authenticated "who am I" endpoint — also doubles as the
      # simplest possible probe that JWT auth (issue/verify/revoke) works
      # end to end; see spec/requests/api/v1/staff/sessions_spec.rb.
      class MeController < ApplicationController
        before_action :authenticate_user!

        def show
          render json: {
            id: current_user.id, email: current_user.email, role: current_user.role,
            language: current_user.language, site_ref: current_user.site_ref
          }, status: :ok
        end
      end
    end
  end
end
