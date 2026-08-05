require "rails_helper"

RSpec.describe Domain::Notifications::Adapters::WebPushAdapter do
  it "returns false without raising when the caregiver has no push subscription" do
    caregiver = create(:caregiver, push_subscription: {})
    expect(described_class.new.send!(caregiver: caregiver, body: "hi")).to be false
  end

  it "returns false without raising on any delivery error (ADR-0006)" do
    caregiver = create(:caregiver, push_subscription: {
      "endpoint" => "https://push.example.eu/abc", "keys" => { "p256dh" => "x", "auth" => "y" }
    })

    expect(described_class.new.send!(caregiver: caregiver, body: "hi")).to be false
  end

  it "embeds the notification_attempt id alongside the body in the push payload" do
    caregiver = create(:caregiver, push_subscription: {
      "endpoint" => "https://push.example.eu/abc", "keys" => { "p256dh" => "x", "auth" => "y" }
    })

    expect(Webpush).to receive(:payload_send) do |args|
      expect(JSON.parse(args[:message])).to eq("id" => "attempt-123", "body" => "hi")
    end

    described_class.new.send!(caregiver: caregiver, body: "hi", notification_attempt_id: "attempt-123")
  end
end
