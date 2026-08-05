require "rails_helper"

RSpec.describe Domain::Notifications::Adapters::SmsAdapter do
  it "returns false when the caregiver has no phone on file" do
    caregiver = create(:caregiver)
    expect(described_class.new.send!(caregiver: caregiver, body: "hi")).to be false
  end

  it "logs and returns true (LogAdapter) when no SMS_PROVIDER_URL is configured" do
    caregiver = create(:caregiver)
    caregiver.update!(contact_data: { "phone" => "+491234567" })

    expect(ENV["SMS_PROVIDER_URL"]).to be_nil # dev/test default
    expect(described_class.new.send!(caregiver: caregiver, body: "hi")).to be true
  end

  it "never logs the raw phone number" do
    caregiver = create(:caregiver)
    caregiver.update!(contact_data: { "phone" => "+491234567" })

    expect(Rails.logger).to receive(:info) do |message|
      expect(message).not_to include("+491234567")
    end
    described_class.new.send!(caregiver: caregiver, body: "hi")
  end
end
