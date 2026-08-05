require "rails_helper"

RSpec.describe Domain::Risk::ShadowPipeline do
  let(:episode) { create(:episode) }
  let(:check_in) { create(:check_in, episode: episode, weight_kg: 70.0) }
  let(:evaluation) { create(:evaluation, episode: episode, check_in: check_in, severity: "green") }

  it "persists a RiskScore paired with the rules verdict, shadow-only" do
    risk_score = described_class.process!(episode: episode, check_in: check_in, evaluation: evaluation)

    expect(risk_score).to be_persisted
    expect(risk_score.episode_ref).to eq(episode.id)
    expect(risk_score.check_in_ref).to eq(check_in.id)
    expect(risk_score.rules_severity).to eq("green")
  end

  it "does nothing for the missed-check-in scan (no check-in to score)" do
    expect { described_class.process!(episode: episode, check_in: nil, evaluation: nil) }
      .not_to change(RiskScore, :count)
  end

  it "never creates a flag by itself, however risky the trajectory" do
    care_plan = create(:care_plan, episode: episode, active: true)
    med = create(:medication, care_plan: care_plan, critical: true)
    create(:check_in, episode: episode, effective_date: check_in.effective_date - 3, weight_kg: 65.0)
    7.downto(1) { |n| create(:check_in, episode: episode, effective_date: check_in.effective_date - n,
      weight_kg: 68.0, med_status: { med.id.to_s => "missed" }, symptoms: { "fatigue_increased" => true }) }

    expect { described_class.process!(episode: episode, check_in: check_in, evaluation: evaluation) }
      .not_to change(Flag, :count)
  end

  it "defaults rules_severity to green when no evaluation is given" do
    risk_score = described_class.process!(episode: episode, check_in: check_in, evaluation: nil)

    expect(risk_score.rules_severity).to eq("green")
  end
end
