module Domain
  module Notifications
    module Adapters
      class EmailAdapter
        def send!(caregiver:, body:, notification_attempt_id: nil)
          email = caregiver.email
          return false if email.blank?

          if ENV["EMAIL_PROVIDER_URL"].present?
            send_via_provider(email, body)
          else
            log_only(email, body)
          end
        end

        private

        def send_via_provider(email, body)
          response = Faraday.post(ENV.fetch("EMAIL_PROVIDER_URL")) do |req|
            req.headers["Content-Type"] = "application/json"
            req.headers["Authorization"] = "Bearer #{ENV['EMAIL_API_KEY']}" if ENV["EMAIL_API_KEY"].present?
            req.body = { to: email, body: body }.to_json
          end
          response.success?
        rescue Faraday::Error => e
          Rails.logger.warn("[EmailAdapter] delivery failed: #{e.class}")
          false
        end

        def log_only(email, body)
          Rails.logger.info("[LogAdapter Email] to_hash=#{Digest::SHA256.hexdigest(email)[0, 8]} body=#{body}")
          true
        end
      end
    end
  end
end
