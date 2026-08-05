require "rails_helper"

RSpec.describe PushConfirmWatchJob do
  it "escalates an unconfirmed red-escalation push older than the confirm window to SMS" do
    caregiver = create(:caregiver)
    caregiver.update!(contact_data: { "phone" => "+491234567" })
    flag = create(:flag, episode: caregiver.episode)
    attempt = create(:notification_attempt, caregiver: caregiver, flag: flag,
                                             kind: "red_escalation", channel: "webpush", state: "sent")
    attempt.update_column(:created_at, 6.minutes.ago)

    expect do
      described_class.new.perform
    end.to change(NotificationAttempt, :count).by(1)
      .and change(AuditEvent, :count).by(1)

    expect(attempt.reload.state).to eq("failed")
    sms_attempt = NotificationAttempt.where(channel: "sms", kind: "red_escalation").last
    expect(sms_attempt.flag).to eq(flag)
  end

  it "leaves a red-escalation push within the confirm window untouched" do
    caregiver = create(:caregiver)
    flag = create(:flag, episode: caregiver.episode)
    attempt = create(:notification_attempt, caregiver: caregiver, flag: flag,
                                             kind: "red_escalation", channel: "webpush", state: "sent")
    attempt.update_column(:created_at, 1.minute.ago)

    expect do
      described_class.new.perform
    end.not_to change(NotificationAttempt, :count)

    expect(attempt.reload.state).to eq("sent")
  end

  it "does not touch an already-confirmed push" do
    caregiver = create(:caregiver)
    flag = create(:flag, episode: caregiver.episode)
    attempt = create(:notification_attempt, caregiver: caregiver, flag: flag,
                                             kind: "red_escalation", channel: "webpush", state: "confirmed")
    attempt.update_column(:created_at, 6.minutes.ago)

    described_class.new.perform

    expect(attempt.reload.state).to eq("confirmed")
  end
end
