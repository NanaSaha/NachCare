require "rails_helper"

# ADR-0010: schedule shape is `{"times" => ["08:00", "20:00"], "instructions" => "..."}`.
# R10: schedule-timing logic is TDD'd, kept small.
RSpec.describe Medication do
  it "is valid with a blank schedule" do
    expect(build(:medication, schedule: {})).to be_valid
  end

  it "is valid with well-formed HH:MM times" do
    med = build(:medication, schedule: { "times" => [ "08:00", "20:30" ], "instructions" => "with food" })
    expect(med).to be_valid
  end

  it "is invalid when times is not an array" do
    med = build(:medication, schedule: { "times" => "08:00" })
    expect(med).not_to be_valid
    expect(med.errors[:schedule]).to be_present
  end

  it "is invalid when a time entry is not HH:MM" do
    med = build(:medication, schedule: { "times" => [ "8am" ] })
    expect(med).not_to be_valid
  end

  it "is invalid when schedule is not a hash" do
    med = build(:medication, schedule: "not a hash")
    expect(med).not_to be_valid
  end

  describe "#schedule_times" do
    it "returns valid times sorted, dropping malformed entries" do
      med = build(:medication, schedule: { "times" => [ "20:00", "08:00", "not-a-time" ] })
      expect(med.schedule_times).to eq([ "08:00", "20:00" ])
    end

    it "returns an empty array when schedule has no times" do
      expect(build(:medication, schedule: {}).schedule_times).to eq([])
    end

    it "dedupes exact-duplicate times" do
      med = build(:medication, schedule: { "times" => [ "08:00", "08:00", "20:00" ] })
      expect(med.schedule_times).to eq([ "08:00", "20:00" ])
    end
  end

  describe "#schedule_instructions" do
    it "returns the instructions text, nil if blank" do
      expect(build(:medication, schedule: { "instructions" => "1 tablet" }).schedule_instructions).to eq("1 tablet")
      expect(build(:medication, schedule: {}).schedule_instructions).to be_nil
      expect(build(:medication, schedule: { "instructions" => "" }).schedule_instructions).to be_nil
    end
  end
end
