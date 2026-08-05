module Domain
  module Enrollment
    # Generates and redeems activation codes (FR-N10/11). Only the SHA-256
    # digest of a code is ever persisted — the plaintext exists only in
    # memory between generation and being handed to the nurse for the A5
    # sheet / on-screen display, never logged, never stored.
    class Activator
      DEFAULT_EXPIRY = 14.days
      DEVICE_TOKEN_BYTES = 32

      Generated = Struct.new(:activation_code, :plaintext_code, keyword_init: true)
      CaregiverActivation = Struct.new(:caregiver, :plaintext_device_token, :activation_code, keyword_init: true)

      class InvalidCode < StandardError; end

      def self.generate!(episode:, role:)
        plaintext = CodeGenerator.call
        activation_code = episode.activation_codes.create!(
          code_digest: digest(plaintext),
          role: role,
          expires_at: DEFAULT_EXPIRY.from_now
        )
        Generated.new(activation_code: activation_code, plaintext_code: plaintext)
      end

      # Marks the code used and returns it. Raises rather than returning nil
      # on failure so the three rejection reasons (not found / used /
      # expired) stay distinguishable to the caller instead of collapsing
      # into one generic "invalid code" response.
      def self.redeem!(code:)
        activation_code = ActivationCode.find_by(code_digest: digest(code))
        raise InvalidCode, "code not found" unless activation_code
        raise InvalidCode, "code already used" if activation_code.used?
        raise InvalidCode, "code expired" if activation_code.expired?

        activation_code.update!(used_at: Time.current)
        activation_code
      end

      def self.digest(code)
        Digest::SHA256.hexdigest(code.to_s.upcase)
      end

      # Redeems the code and issues a device token to the caregiver record
      # the nurse created at enrollment. M1 only ever creates one (primary)
      # caregiver per episode, so "the episode's unactivated caregiver" is
      # unambiguous — FR-C5 (second caregiver, M2) will need to disambiguate
      # by role/invite instead once a second caregiver can exist.
      def self.activate_caregiver!(code:)
        activation_code = redeem!(code: code)
        caregiver = activation_code.episode.caregivers.find_by(device_token_digest: nil)
        raise InvalidCode, "no caregiver record to activate for this code" unless caregiver

        plaintext_token = SecureRandom.hex(DEVICE_TOKEN_BYTES)
        caregiver.update!(device_token_digest: device_token_digest(plaintext_token))

        CaregiverActivation.new(caregiver: caregiver, plaintext_device_token: plaintext_token, activation_code: activation_code)
      end

      def self.device_token_digest(token)
        Digest::SHA256.hexdigest("#{token}#{ENV.fetch('CAREGIVER_DEVICE_TOKEN_PEPPER', 'dev_only_pepper_do_not_use_in_prod')}")
      end
    end
  end
end
