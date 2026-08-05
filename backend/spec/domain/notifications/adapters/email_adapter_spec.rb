require "rails_helper"

RSpec.describe Domain::Notifications::Adapters::EmailAdapter do
  it "returns false when the caregiver has no email on file" do
    caregiver = create(:caregiver)
    expect(described_class.new.send!(caregiver: caregiver, body: "hi")).to be false
  end

  it "logs and returns true (LogAdapter) when no EMAIL_PROVIDER_URL is configured" do
    caregiver = create(:caregiver)
    caregiver.update!(contact_data: { "email" => "family@example.eu" })

    expect(ENV["EMAIL_PROVIDER_URL"]).to be_nil # dev/test default
    expect(described_class.new.send!(caregiver: caregiver, body: "hi")).to be true
  end

  it "never logs the raw email address" do
    caregiver = create(:caregiver)
    caregiver.update!(contact_data: { "email" => "family@example.eu" })

    expect(Rails.logger).to receive(:info) do |message|
      expect(message).not_to include("family@example.eu")
    end
    described_class.new.send!(caregiver: caregiver, body: "hi")
  end
end
