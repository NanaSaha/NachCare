require "rails_helper"

RSpec.describe Domain::Enrollment::CodeGenerator do
  it "generates an 8-character code" do
    expect(described_class.call.length).to eq(8)
  end

  it "never includes visually-confusable characters (0/O, 1/I/L)" do
    codes = Array.new(200) { described_class.call }
    expect(codes.join).not_to match(/[01ILO]/)
  end

  it "is randomized, not constant" do
    codes = Array.new(50) { described_class.call }
    expect(codes.uniq.size).to be > 1
  end
end
