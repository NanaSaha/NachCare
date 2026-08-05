module Api
  module V1
    module Caregiver
      # One endpoint the onboarding wizard calls at each step (or once at
      # the end) — language-first, consents a-d, notification time, PIN
      # (Section 8 M1). All fields optional/PATCH-style so the UI can send
      # partial updates per wizard step without a stricter multi-endpoint
      # surface than the caregiver-facing app actually needs yet.
      class OnboardingsController < ApplicationController
        include CaregiverAuthenticatable

        def update
          current_caregiver.language = params[:language] if params[:language].present?
          current_caregiver.notification_time = params[:notification_time] if params[:notification_time].present?
          current_caregiver.pin_digest = pin_digest(params[:pin]) if params[:pin].present?
          current_caregiver.save!

          record_consents!

          render json: CaregiverSelfBlueprint.render_as_hash(current_caregiver), status: :ok
        end

        private

        # Idempotent: the onboarding wizard's "back" button (or a retried
        # PATCH after a dropped connection) can resubmit the same step more
        # than once — find_or_initialize avoids a unique-constraint 500 on
        # (caregiver_ref, kind, version) when that happens.
        def record_consents!
          params.fetch(:consents, {}).to_unsafe_h.each do |kind, granted|
            next unless Consent::KINDS.include?(kind.to_s)

            consent = current_caregiver.consents.find_or_initialize_by(kind: kind.to_s, version: 1)
            consent.granted = ActiveModel::Type::Boolean.new.cast(granted)
            consent.timestamp = Time.current
            consent.save!
          end
        end

        def pin_digest(pin)
          Digest::SHA256.hexdigest("#{pin}#{ENV.fetch('CAREGIVER_PIN_PEPPER', 'dev_only_pepper_do_not_use_in_prod')}")
        end
      end
    end
  end
end
