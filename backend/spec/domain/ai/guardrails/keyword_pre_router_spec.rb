require "rails_helper"

RSpec.describe Domain::Ai::Guardrails::KeywordPreRouter do
  it "routes an obvious English medication question without any LLM call" do
    expect(described_class.route("should I give her an extra dose today?")).to eq("medication_or_dosage")
  end

  it "routes an obvious German medication question" do
    expect(described_class.route("Soll ich die Dosis erhöhen?")).to eq("medication_or_dosage")
  end

  it "routes a diagnosis/prognosis question" do
    expect(described_class.route("what is her prognosis?")).to eq("diagnosis_or_prognosis")
  end

  it "returns nil for an ordinary message" do
    expect(described_class.route("how do I log a symptom?")).to be_nil
  end
end
