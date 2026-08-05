require "rails_helper"

RSpec.describe MedicationDose do
  it "is valid with a valid status" do
    expect(build(:medication_dose, status: "taken")).to be_valid
  end

  it "is invalid with an unknown status" do
    expect(build(:medication_dose, status: "snoozed")).not_to be_valid
  end

  it "requires scheduled_date and scheduled_time" do
    dose = build(:medication_dose, scheduled_date: nil, scheduled_time: nil)
    expect(dose).not_to be_valid
    expect(dose.errors[:scheduled_date]).to be_present
    expect(dose.errors[:scheduled_time]).to be_present
  end

  it "enforces one row per medication+date+time at the DB level" do
    create(:medication_dose, scheduled_date: Date.new(2026, 8, 3), scheduled_time: "08:00")
    dup = build(:medication_dose, scheduled_date: Date.new(2026, 8, 3), scheduled_time: "08:00")
    dup.medication = MedicationDose.first.medication

    expect { dup.save!(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
  end
end
