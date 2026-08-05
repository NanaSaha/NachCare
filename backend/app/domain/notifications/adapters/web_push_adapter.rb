module Domain
  module Notifications
    module Adapters
      class WebPushAdapter
        # `notification_attempt_id` rides along in the payload (as an
        # opaque id, not PHI — R5) so the service worker's push handler can
        # POST a confirm beacon back for this specific attempt.
        def send!(caregiver:, body:, notification_attempt_id: nil)
          subscription = caregiver.push_subscription
          return false if subscription.blank? || subscription["endpoint"].blank?

          Webpush.payload_send(
            message: { id: notification_attempt_id, body: body }.to_json,
            endpoint: subscription["endpoint"],
            p256dh: subscription.dig("keys", "p256dh"),
            auth: subscription.dig("keys", "auth"),
            vapid: {
              subject: ENV.fetch("VAPID_SUBJECT", "mailto:ops@example.eu"),
              public_key: ENV.fetch("VAPID_PUBLIC_KEY", ""),
              private_key: ENV.fetch("VAPID_PRIVATE_KEY", "")
            }
          )
          true
        rescue StandardError => e
          # See ADR-0006: the webpush gem has a known OpenSSL 3.0
          # incompatibility in this build. Treated the same as any other
          # delivery failure (expired subscription, unreachable push
          # service) — correct regardless of that specific bug, since the
          # fallback chain needs to react uniformly to "push didn't work."
          Rails.logger.warn("[WebPushAdapter] delivery failed: #{e.class}")
          false
        end
      end
    end
  end
end
