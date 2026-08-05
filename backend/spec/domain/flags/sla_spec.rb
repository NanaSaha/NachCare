require "rails_helper"

RSpec.describe Domain::Flags::Sla do
  let(:site) { create(:site, sla_red_minutes: 30, sla_yellow_minutes: 240) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let(:from) { Time.zone.parse("2026-08-03 10:00:00") }

  it "computes the red deadline from the site's sla_red_minutes" do
    deadline = described_class.deadline_for(episode: episode, severity: "red", from: from)
    expect(deadline).to eq(from + 30.minutes)
  end

  it "computes the yellow deadline from the site's sla_yellow_minutes" do
    deadline = described_class.deadline_for(episode: episode, severity: "yellow", from: from)
    expect(deadline).to eq(from + 240.minutes)
  end

  it "has no deadline for green" do
    deadline = described_class.deadline_for(episode: episode, severity: "green", from: from)
    expect(deadline).to be_nil
  end
end
