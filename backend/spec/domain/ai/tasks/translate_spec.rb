require "rails_helper"

RSpec.describe Domain::Ai::Tasks::Translate do
  let(:gateway) { Domain::Ai::Gateway.new }

  it "passes source text through unchanged when source and target languages match" do
    result = described_class.new(gateway: gateway).call(body_source: "hello", source_language: "en", target_language: "en")
    expect(result).to eq("hello")
  end

  it "returns a translated string when source and target differ" do
    result = described_class.new(gateway: gateway).call(body_source: "hello", source_language: "en", target_language: "de")
    expect(result).to be_present
  end

  it "returns nil when the provider chain is exhausted (matches the M4 TranslateAssist stub's contract)" do
    allow(Domain::Ai::Gateway).to receive_messages(
      primary_provider: instance_double(Domain::Ai::Providers::Base, name: "p", configured?: true).tap { |d|
        allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down")
      },
      fallback_provider: instance_double(Domain::Ai::Providers::Base, name: "f", configured?: true).tap { |d|
        allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down")
      }
    )

    result = described_class.new(gateway: gateway).call(body_source: "hello", source_language: "en", target_language: "de")
    expect(result).to be_nil
  end
end
