require "rails_helper"

RSpec.describe Domain::Ai::AcceptRatio do
  it "returns 1.0 when the nurse saved the draft unedited" do
    expect(described_class.compute("call the caregiver about fluid intake", "call the caregiver about fluid intake")).to eq(1.0)
  end

  it "returns a partial ratio for a lightly edited draft" do
    ratio = described_class.compute("call the caregiver about fluid intake", "call the caregiver about salt intake")
    expect(ratio).to be_between(0.4, 0.9)
  end

  it "returns 0.0 for completely unrelated text" do
    expect(described_class.compute("call about fluid", "totally different words here")).to eq(0.0)
  end

  it "returns nil when either side is blank" do
    expect(described_class.compute(nil, "something")).to be_nil
    expect(described_class.compute("something", "")).to be_nil
  end
end
