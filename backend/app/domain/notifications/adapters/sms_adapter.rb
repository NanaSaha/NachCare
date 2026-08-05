module Domain
  module Notifications
    module Adapters
      # Section 2: LogAdapter in dev, generic HTTP adapter (provider URL
      # configurable via env) once a real EU SMS provider is contracted —
      # see docs/SUBPROCESSORS.md.
      class SmsAdapter
        def send!(caregiver:, body:, notification_attempt_id: nil)
          phone = caregiver.phone
          return false if phone.blank?

          if ENV["SMS_PROVIDER_URL"].present?
            send_via_provider(phone, body)
          else
            log_only(phone, body)
          end
        end

        private

        def send_via_provider(phone, body)
          response = Faraday.post(ENV.fetch("SMS_PROVIDER_URL")) do |req|
            req.headers["Content-Type"] = "application/json"
            req.headers["Authorization"] = "Bearer #{ENV['SMS_API_KEY']}" if ENV["SMS_API_KEY"].present?
            req.body = { to: phone, body: body }.to_json
          end
          response.success?
        rescue Faraday::Error => e
          Rails.logger.warn("[SmsAdapter] delivery failed: #{e.class}")
          false
        end

        # R5: never log raw PHI/PII — not even a caregiver's phone number.
        def log_only(phone, body)
          Rails.logger.info("[LogAdapter SMS] to_hash=#{Digest::SHA256.hexdigest(phone)[0, 8]} body=#{body}")
          true
        end
      end
    end
  end
end
