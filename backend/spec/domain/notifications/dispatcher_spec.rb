require "rails_helper"

RSpec.describe Domain::Notifications::Dispatcher do
  it "records a sent attempt when the adapter delivers" do
    caregiver = create(:caregiver)
    caregiver.update!(contact_data: { "phone" => "+491234567" })

    attempt = described_class.send!(caregiver: caregiver, channel: "sms", kind: "daily_reminder")

    expect(attempt).to be_persisted
    expect(attempt.state).to eq("sent")
    expect(attempt.kind).to eq("daily_reminder")
    expect(attempt.channel).to eq("sms")
    expect(attempt.caregiver).to eq(caregiver)
  end

  it "records a failed attempt when the adapter cannot deliver" do
    caregiver = create(:caregiver) # no phone on file

    attempt = described_class.send!(caregiver: caregiver, channel: "sms", kind: "daily_reminder")

    expect(attempt.state).to eq("failed")
  end

  it "associates the attempt with a flag when given one" do
    caregiver = create(:caregiver)
    caregiver.update!(contact_data: { "phone" => "+491234567" })
    flag = create(:flag)

    attempt = described_class.send!(caregiver: caregiver, channel: "sms", kind: "red_escalation", flag: flag)

    expect(attempt.flag).to eq(flag)
  end

  it "raises for an unknown kind rather than sending an unrecognized body" do
    caregiver = create(:caregiver)

    expect do
      described_class.send!(caregiver: caregiver, channel: "sms", kind: "not_a_real_kind")
    end.to raise_error(KeyError)
  end
end
