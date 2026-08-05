require "rails_helper"

RSpec.describe Domain::CareActivity::Feed do
  it "returns check-ins and medication doses for the episode, newest first" do
    episode = create(:episode)
    caregiver = create(:caregiver, episode: episode)
    care_plan = create(:care_plan, episode: episode, active: true)
    medication = create(:medication, care_plan: care_plan)

    check_in = create(:check_in, episode: episode, caregiver: caregiver, submitted_at: 2.hours.ago)
    dose = create(:medication_dose, medication: medication, caregiver: caregiver, status: "taken", taken_at: 1.hour.ago)

    result = described_class.recent(episode: episode)

    expect(result.size).to eq(2)
    expect(result.first[:type]).to eq("medication_dose")
    expect(result.first[:id]).to eq(dose.id)
    expect(result.second[:type]).to eq("check_in")
    expect(result.second[:id]).to eq(check_in.id)
  end

  it "does not leak activity from other episodes" do
    episode = create(:episode)
    other_episode = create(:episode)
    create(:check_in, episode: other_episode)

    expect(described_class.recent(episode: episode)).to eq([])
  end

  it "respects the limit" do
    episode = create(:episode)
    caregiver = create(:caregiver, episode: episode)
    5.times { |i| create(:check_in, episode: episode, caregiver: caregiver, effective_date: i.days.ago.to_date) }

    expect(described_class.recent(episode: episode, limit: 2).size).to eq(2)
  end
end
