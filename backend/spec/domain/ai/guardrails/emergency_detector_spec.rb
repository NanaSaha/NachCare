require "rails_helper"

RSpec.describe Domain::Ai::Guardrails::EmergencyDetector do
  let(:gateway) { Domain::Ai::Gateway.new }

  it "returns true when the message contains a configured emergency phrase" do
    phrase = Domain::Ai::GuardrailConfig.emergency_phrases("en").first
    expect(described_class.check(text: "I'm scared, #{phrase}", language: "en", gateway: gateway)).to be true
  end

  it "returns false for an ordinary message" do
    expect(described_class.check(text: "what does today's green result mean?", language: "en", gateway: gateway)).to be false
  end

  it "propagates Gateway::AllProvidersFailed when the provider chain is exhausted (fail-closed upstream)" do
    allow(Domain::Ai::Gateway).to receive_messages(
      primary_provider: instance_double(Domain::Ai::Providers::Base, name: "p", configured?: true,
        chat: nil).tap { |d| allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down") },
      fallback_provider: instance_double(Domain::Ai::Providers::Base, name: "f", configured?: true,
        chat: nil).tap { |d| allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down") }
    )

    expect { described_class.check(text: "hello", language: "en", gateway: gateway) }
      .to raise_error(Domain::Ai::Gateway::AllProvidersFailed)
  end
end
