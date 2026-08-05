module Api
  module V1
    module Caregiver
      # M4: the service worker's `push` event handler POSTs here immediately
      # on receipt, before showing the notification — this is the "confirm
      # beacon" PushConfirmWatchJob waits for to avoid escalating a RED push
      # that actually arrived (Section 8 M4 RED chain).
      class NotificationAttemptsController < ApplicationController
        include CaregiverAuthenticatable

        def confirm
          attempt = current_caregiver.notification_attempts.find(params[:id])
          attempt.update!(state: "confirmed") if attempt.state == "sent"
          head :no_content
        end
      end
    end
  end
end
