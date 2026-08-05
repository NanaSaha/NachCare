require "rails_helper"

RSpec.describe Domain::Messages::TranslateAssist do
  it "passes the source through unchanged when the target language matches the source" do
    result = described_class.suggest(body_source: "Hello", target_language: "en", source_language: "en")
    expect(result).to eq("Hello")
  end

  it "returns a real translation for a non-English target via T-TRANSLATE (M5)" do
    result = described_class.suggest(body_source: "Hello", target_language: "de", source_language: "en")
    expect(result).to be_present
  end

  it "returns nil (not-yet-translated) when the provider chain is exhausted, same contract as the M4 stub" do
    allow(Domain::Ai::Gateway).to receive_messages(
      primary_provider: instance_double(Domain::Ai::Providers::Base, name: "p", configured?: true).tap { |d|
        allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down")
      },
      fallback_provider: instance_double(Domain::Ai::Providers::Base, name: "f", configured?: true).tap { |d|
        allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down")
      }
    )

    result = described_class.suggest(body_source: "Hello", target_language: "de", source_language: "en")
    expect(result).to be_nil
  end
end
