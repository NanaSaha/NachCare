require "rails_helper"

RSpec.describe Domain::Ai::Redactor do
  it "redacts email addresses" do
    expect(described_class.redact("call me at sabine.mueller@example.com please"))
      .to eq("call me at [REDACTED_EMAIL] please")
  end

  it "redacts phone numbers with a leading +" do
    expect(described_class.redact("reach me on +49 171 2345678 anytime"))
      .to eq("reach me on [REDACTED_PHONE] anytime")
  end

  it "redacts phone numbers without a +" do
    expect(described_class.redact("call 0171-2345678"))
      .to eq("call [REDACTED_PHONE]")
  end

  it "redacts both an email and a phone number in the same text" do
    result = described_class.redact("email a@b.com or call 030 1234567")
    expect(result).to eq("email [REDACTED_EMAIL] or call [REDACTED_PHONE]")
  end

  it "leaves ordinary short numbers (dates, weights) untouched" do
    expect(described_class.redact("weight was 72.5 kg on day 14")).to eq("weight was 72.5 kg on day 14")
  end

  it "returns blank input unchanged" do
    expect(described_class.redact(nil)).to be_nil
    expect(described_class.redact("")).to eq("")
  end
end
