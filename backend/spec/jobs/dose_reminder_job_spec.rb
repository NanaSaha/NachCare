require "rails_helper"

RSpec.describe DoseReminderJob do
  def plan_with_schedule(times)
    episode = create(:episode)
    create(:caregiver, episode: episode)
    care_plan = create(:care_plan, episode: episode, active: true)
    create(:medication, care_plan: care_plan, schedule: { "times" => times })
    care_plan
  end

  it "sends a reminder when a scheduled dose time's window is now and it hasn't been resolved" do
    plan_with_schedule([ "09:00" ])

    travel_to(Time.zone.local(2026, 8, 3, 9, 4)) do
      expect { described_class.new.perform }.to change(NotificationAttempt, :count).by(1)
    end

    attempt = NotificationAttempt.last
    expect(attempt.kind).to eq("dose_reminder")
    expect(attempt.channel).to eq("webpush")
  end

  it "does not send when the dose was already marked taken" do
    plan = plan_with_schedule([ "09:00" ])
    medication = plan.medications.first
    caregiver = plan.episode.caregivers.first
    create(:medication_dose, medication: medication, caregiver: caregiver, scheduled_date: Date.new(2026, 8, 3), scheduled_time: "09:00", status: "taken")

    travel_to(Time.zone.local(2026, 8, 3, 9, 4)) do
      expect { described_class.new.perform }.not_to change(NotificationAttempt, :count)
    end
  end

  it "does not send when the dose was already marked missed" do
    plan = plan_with_schedule([ "09:00" ])
    medication = plan.medications.first
    caregiver = plan.episode.caregivers.first
    create(:medication_dose, medication: medication, caregiver: caregiver, scheduled_date: Date.new(2026, 8, 3), scheduled_time: "09:00", status: "missed")

    travel_to(Time.zone.local(2026, 8, 3, 9, 4)) do
      expect { described_class.new.perform }.not_to change(NotificationAttempt, :count)
    end
  end

  it "does not send outside the scheduled time's window" do
    plan_with_schedule([ "09:00" ])

    travel_to(Time.zone.local(2026, 8, 3, 14, 0)) do
      expect { described_class.new.perform }.not_to change(NotificationAttempt, :count)
    end
  end

  it "does not send during quiet hours" do
    plan_with_schedule([ "23:30" ])

    travel_to(Time.zone.local(2026, 8, 3, 23, 33)) do
      expect { described_class.new.perform }.not_to change(NotificationAttempt, :count)
    end
  end

  it "sends independently for two different scheduled times on the same medication" do
    plan_with_schedule([ "09:00", "20:00" ])

    travel_to(Time.zone.local(2026, 8, 3, 9, 4)) do
      expect { described_class.new.perform }.to change(NotificationAttempt, :count).by(1)
    end

    travel_to(Time.zone.local(2026, 8, 3, 20, 4)) do
      expect { described_class.new.perform }.to change(NotificationAttempt, :count).by(1)
    end
  end
end
