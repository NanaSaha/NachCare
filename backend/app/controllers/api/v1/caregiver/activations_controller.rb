module Api
  module V1
    module Caregiver
      # Public (no auth) — this IS the auth: exchanging an activation code
      # for a device token. Rate limiting against brute-force code guessing
      # is a rack-attack concern for M7 hardening, not this controller.
      class ActivationsController < ApplicationController
        def create
          result = Domain::Enrollment::Activator.activate_caregiver!(code: params[:code].to_s)

          Domain::Audit::Recorder.record!(
            actor: result.caregiver, action: "caregiver.activated", entity: result.caregiver, payload: {}
          )

          render json: {
            device_token: result.plaintext_device_token,
            caregiver: CaregiverSelfBlueprint.render_as_hash(result.caregiver)
          }, status: :created
        rescue Domain::Enrollment::Activator::InvalidCode
          render json: { error: "invalid_code" }, status: :unprocessable_content
        end
      end
    end
  end
end
