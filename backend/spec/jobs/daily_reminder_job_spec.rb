require "rails_helper"

RSpec.describe DailyReminderJob do
  it "sends a reminder push when the caregiver's notification_time window is now and they haven't checked in" do
    caregiver = create(:caregiver, notification_time: "09:00")

    travel_to(Time.zone.local(2026, 8, 2, 9, 3)) do
      expect do
        described_class.new.perform
      end.to change(NotificationAttempt, :count).by(1)
    end

    attempt = NotificationAttempt.last
    expect(attempt.kind).to eq("daily_reminder")
    expect(attempt.channel).to eq("webpush")
  end

  it "does not send when the caregiver already checked in today" do
    caregiver = create(:caregiver, notification_time: "09:00")
    create(:check_in, episode: caregiver.episode, effective_date: Date.new(2026, 8, 2))

    travel_to(Time.zone.local(2026, 8, 2, 9, 3)) do
      expect do
        described_class.new.perform
      end.not_to change(NotificationAttempt, :count)
    end
  end

  it "does not send outside the caregiver's notification window" do
    create(:caregiver, notification_time: "09:00")

    travel_to(Time.zone.local(2026, 8, 2, 14, 0)) do
      expect do
        described_class.new.perform
      end.not_to change(NotificationAttempt, :count)
    end
  end

  it "does not send during quiet hours even if a notification_time somehow falls there" do
    create(:caregiver, notification_time: "23:30")

    travel_to(Time.zone.local(2026, 8, 2, 23, 33)) do
      expect do
        described_class.new.perform
      end.not_to change(NotificationAttempt, :count)
    end
  end
end
