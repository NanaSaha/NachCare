module Api
  module V1
    module Caregiver
      # M4: the caregiver PWA's service worker calls this once it has a
      # PushManager subscription (endpoint + keys), so the backend has
      # somewhere to send webpush notifications for this caregiver.
      class PushSubscriptionsController < ApplicationController
        include CaregiverAuthenticatable

        def update
          current_caregiver.update!(push_subscription: subscription_params.to_h)
          head :no_content
        end

        private

        def subscription_params
          params.require(:subscription).permit(:endpoint, keys: [ :p256dh, :auth ])
        end
      end
    end
  end
end
