require "rails_helper"

RSpec.describe Domain::Escalation::Processor do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let(:caregiver) { create(:caregiver, episode: episode) }

  let!(:active_ruleset) do
    create(:ruleset, version: "active-1", status: "active", body: {
      "version" => "active-1",
      "rules" => [
        { "id" => "R-1", "key" => "breathless", "severity" => "red",
          "condition" => { "type" => "symptom_toggle", "symptom_key" => "breathless_at_rest" } }
      ]
    })
  end

  describe "processing a check-in" do
    it "persists an evaluation with a stable inputs_sha256 and creates a flag when severity is non-green" do
      check_in = create(:check_in, episode: episode, caregiver: caregiver, symptoms: { "breathless_at_rest" => true })

      result = described_class.process!(episode: episode, check_in: check_in)

      expect(result.evaluation.severity).to eq("red")
      expect(result.evaluation.ruleset_version).to eq("active-1")
      expect(result.evaluation.inputs_sha256).to be_present
      expect(result.flag).to be_persisted
      expect(result.flag.severity).to eq("red")
    end

    it "does not create a flag for a green evaluation" do
      check_in = create(:check_in, episode: episode, caregiver: caregiver, symptoms: {})

      result = described_class.process!(episode: episode, check_in: check_in)

      expect(result.evaluation.severity).to eq("green")
      expect(result.flag).to be_nil
    end

    it "does nothing if there is no active ruleset" do
      active_ruleset.update!(status: "retired")
      check_in = create(:check_in, episode: episode, caregiver: caregiver)

      result = described_class.process!(episode: episode, check_in: check_in)

      expect(result.evaluation).to be_nil
      expect(Evaluation.count).to eq(0)
    end
  end

  describe "shadow rulesets" do
    it "evaluates shadow rulesets and persists their evaluations, but they never create flags" do
      create(:ruleset, version: "shadow-1", status: "shadow", body: {
        "version" => "shadow-1",
        "rules" => [
          { "id" => "R-1", "key" => "always_red", "severity" => "red",
            "condition" => { "type" => "symptom_toggle", "symptom_key" => "anything" } }
        ]
      })
      check_in = create(:check_in, episode: episode, caregiver: caregiver, symptoms: { "anything" => true, "breathless_at_rest" => false })

      described_class.process!(episode: episode, check_in: check_in)

      shadow_eval = Evaluation.find_by(ruleset_version: "shadow-1")
      expect(shadow_eval.severity).to eq("red")
      expect(Flag.count).to eq(0) # active ruleset didn't fire; shadow's red doesn't count
    end
  end

  describe "the R-8 nightly scan (check_in: nil)" do
    it "can evaluate an episode's silence without a check-in record" do
      result = described_class.process!(episode: episode, check_in: nil)
      expect(result.evaluation).to be_persisted
      expect(result.evaluation.check_in_ref).to be_nil
    end
  end
end
