require "rails_helper"

RSpec.describe Domain::Ai::Tasks::AiWatchRationale do
  let(:episode) { create(:episode) }
  let(:flag) do
    create(:flag, episode: episode, subtype: "ai_watch", severity: "yellow",
      ai_watch_meta: { "components" => { "weight_velocity" => 0.9, "symptom_drift" => 0.2, "adherence_gap" => 0.0 } })
  end
  let(:gateway) { Domain::Ai::Gateway.new }

  it "returns an AI-generated rationale on success" do
    result = described_class.new(gateway: gateway).call(flag: flag, language: "en")
    expect(result).to be_present
  end

  it "falls back to a deterministic plain-language rendering of the top signals — never a bare score" do
    allow(Domain::Ai::Gateway).to receive_messages(
      primary_provider: instance_double(Domain::Ai::Providers::Base, name: "p", configured?: true).tap { |d|
        allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down")
      },
      fallback_provider: instance_double(Domain::Ai::Providers::Base, name: "f", configured?: true).tap { |d|
        allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down")
      }
    )

    result = described_class.new(gateway: gateway).call(flag: flag, language: "en")

    expect(result).to include("weight velocity")
  end
end
