require "rails_helper"

RSpec.describe Domain::Risk::Scorer do
  let(:episode) { create(:episode) }

  def check_in_on(date, weight:, symptoms: {}, med_status: {})
    create(:check_in, episode: episode, effective_date: date, weight_kg: weight, symptoms: symptoms, med_status: med_status)
  end

  describe ".score" do
    it "scores 0 with no signal history (single check-in, no prior weight)" do
      ci = check_in_on(Date.current, weight: 70.0)

      result = described_class.score(episode: episode, check_in: ci)

      expect(result.score).to eq(0.0)
      expect(result.components).to eq(
        "weight_velocity" => 0.0, "symptom_drift" => 0.0, "adherence_gap" => 0.0
      )
    end

    it "scores weight_velocity from a 3-day gain, capped at 1.0" do
      check_in_on(Date.current - 3, weight: 70.0)
      ci = check_in_on(Date.current, weight: 71.2) # exactly VELOCITY_CAP_KG gain

      result = described_class.score(episode: episode, check_in: ci)

      expect(result.components["weight_velocity"]).to eq(1.0)
      expect(result.score).to eq(0.5) # weight component * 0.5 weight, others 0
    end

    it "does not score a weight loss as risk" do
      check_in_on(Date.current - 3, weight: 71.2)
      ci = check_in_on(Date.current, weight: 70.0)

      result = described_class.score(episode: episode, check_in: ci)

      expect(result.components["weight_velocity"]).to eq(0.0)
    end

    it "scores symptom_drift when recent toggles trend up vs. the prior window" do
      check_in_on(Date.current - 5, weight: 70.0, symptoms: {})
      check_in_on(Date.current - 4, weight: 70.0, symptoms: {})
      check_in_on(Date.current - 3, weight: 70.0, symptoms: {})
      check_in_on(Date.current - 2, weight: 70.0, symptoms: { "fatigue_increased" => true })
      check_in_on(Date.current - 1, weight: 70.0, symptoms: { "fatigue_increased" => true, "swelling_increased" => true })
      ci = check_in_on(Date.current, weight: 70.0, symptoms: { "fatigue_increased" => true, "swelling_increased" => true, "breathless_at_rest" => true })

      result = described_class.score(episode: episode, check_in: ci)

      expect(result.components["symptom_drift"]).to be > 0
    end

    it "scores adherence_gap from missed critical medication days in the trailing window" do
      care_plan = create(:care_plan, episode: episode, active: true)
      med = create(:medication, care_plan: care_plan, critical: true)

      6.downto(0) do |n|
        check_in_on(Date.current - n, weight: 70.0, med_status: { med.id.to_s => n.even? ? "missed" : "taken" })
      end
      ci = episode.check_ins.order(effective_date: :desc).first

      result = described_class.score(episode: episode, check_in: ci)

      expect(result.components["adherence_gap"]).to be_within(0.01).of(4.0 / 7)
    end

    it "clamps the combined score to a maximum of 1.0" do
      care_plan = create(:care_plan, episode: episode, active: true)
      med = create(:medication, care_plan: care_plan, critical: true)
      check_in_on(Date.current - 3, weight: 65.0)
      7.downto(1) do |n|
        check_in_on(Date.current - n, weight: 70.0 + (7 - n) * 0.5, med_status: { med.id.to_s => "missed" },
          symptoms: { "fatigue_increased" => true, "swelling_increased" => true, "breathless_at_rest" => true })
      end
      ci = check_in_on(Date.current, weight: 74.0, med_status: { med.id.to_s => "missed" },
        symptoms: { "fatigue_increased" => true, "swelling_increased" => true, "breathless_at_rest" => true })

      result = described_class.score(episode: episode, check_in: ci)

      expect(result.score).to be <= 1.0
    end
  end
end
