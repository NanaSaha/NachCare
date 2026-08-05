require "rails_helper"

RSpec.describe Domain::Ai::Guardrails::PostChecker do
  let(:gateway) { Domain::Ai::Gateway.new }

  it "flags a drafted answer that drifted into medication advice" do
    result = described_class.check(drafted_answer: "you should increase your dose to be safe", gateway: gateway)
    expect(result["flagged"]).to be true
  end

  it "does not flag a clean drafted answer" do
    result = described_class.check(drafted_answer: "great job checking in today, keep it up", gateway: gateway)
    expect(result["flagged"]).to be false
  end
end
