require "rails_helper"

RSpec.describe Domain::Enrollment::Activator do
  let(:episode) { create(:episode) }

  describe ".generate!" do
    it "creates an activation code and returns the plaintext once" do
      result = described_class.generate!(episode: episode, role: "primary")

      expect(result.activation_code).to be_persisted
      expect(result.activation_code.role).to eq("primary")
      expect(result.plaintext_code.length).to eq(8)
    end

    it "never persists the plaintext code" do
      result = described_class.generate!(episode: episode, role: "primary")

      expect(result.activation_code.code_digest).not_to eq(result.plaintext_code)
      expect(ActivationCode.pluck(:code_digest)).not_to include(result.plaintext_code)
    end

    it "sets an expiry in the future" do
      result = described_class.generate!(episode: episode, role: "primary")
      expect(result.activation_code.expires_at).to be > Time.current
    end
  end

  describe ".redeem!" do
    it "marks the code used and returns it" do
      generated = described_class.generate!(episode: episode, role: "primary")

      redeemed = described_class.redeem!(code: generated.plaintext_code)

      expect(redeemed.id).to eq(generated.activation_code.id)
      expect(redeemed.used_at).to be_present
    end

    it "is case-insensitive (caregiver may type it in any case)" do
      generated = described_class.generate!(episode: episode, role: "primary")

      redeemed = described_class.redeem!(code: generated.plaintext_code.downcase)

      expect(redeemed.id).to eq(generated.activation_code.id)
    end

    it "raises for an unknown code" do
      expect { described_class.redeem!(code: "ZZZZZZZZ") }
        .to raise_error(Domain::Enrollment::Activator::InvalidCode, /not found/)
    end

    it "raises for an already-used code" do
      generated = described_class.generate!(episode: episode, role: "primary")
      described_class.redeem!(code: generated.plaintext_code)

      expect { described_class.redeem!(code: generated.plaintext_code) }
        .to raise_error(Domain::Enrollment::Activator::InvalidCode, /already used/)
    end

    it "raises for an expired code" do
      generated = described_class.generate!(episode: episode, role: "primary")
      generated.activation_code.update!(expires_at: 1.minute.ago)

      expect { described_class.redeem!(code: generated.plaintext_code) }
        .to raise_error(Domain::Enrollment::Activator::InvalidCode, /expired/)
    end
  end

  describe ".activate_caregiver!" do
    let!(:caregiver) { create(:caregiver, episode: episode) }

    it "issues a device token and links it to the episode's unactivated caregiver" do
      generated = described_class.generate!(episode: episode, role: "primary")

      result = described_class.activate_caregiver!(code: generated.plaintext_code)

      expect(result.caregiver.id).to eq(caregiver.id)
      expect(result.caregiver.reload.activated?).to be true
      expect(result.plaintext_device_token).to be_present
    end

    it "never persists the plaintext device token" do
      generated = described_class.generate!(episode: episode, role: "primary")
      result = described_class.activate_caregiver!(code: generated.plaintext_code)

      expect(Caregiver.pluck(:device_token_digest)).not_to include(result.plaintext_device_token)
    end

    it "raises if the episode has no unactivated caregiver record" do
      caregiver.update!(device_token_digest: "already-activated")
      generated = described_class.generate!(episode: episode, role: "primary")

      expect { described_class.activate_caregiver!(code: generated.plaintext_code) }
        .to raise_error(Domain::Enrollment::Activator::InvalidCode, /no caregiver record/)
    end

    it "raises for an invalid code without touching any caregiver" do
      expect { described_class.activate_caregiver!(code: "ZZZZZZZZ") }
        .to raise_error(Domain::Enrollment::Activator::InvalidCode)
      expect(caregiver.reload.activated?).to be false
    end
  end
end
