require "rails_helper"

RSpec.describe Domain::Ai::Tasks::Brief do
  let(:episode) { create(:episode) }
  let!(:caregiver) { create(:caregiver, episode: episode) }
  let(:evaluation) { create(:evaluation, episode: episode, severity: "yellow") }
  let(:gateway) { Domain::Ai::Gateway.new }

  it "returns an AI-sourced brief on success" do
    result = described_class.new(gateway: gateway).call(evaluation: evaluation, episode: episode, language: "en")
    expect(result.source).to eq("ai")
    expect(result.text).to be_present
  end

  it "falls back to a non-AI template brief when the provider chain is exhausted (Section 6 #1)" do
    allow(Domain::Ai::Gateway).to receive_messages(
      primary_provider: instance_double(Domain::Ai::Providers::Base, name: "p", configured?: true).tap { |d|
        allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down")
      },
      fallback_provider: instance_double(Domain::Ai::Providers::Base, name: "f", configured?: true).tap { |d|
        allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down")
      }
    )

    result = described_class.new(gateway: gateway).call(evaluation: evaluation, episode: episode, language: "en")

    expect(result.source).to eq("template")
    expect(result.text).to be_present
  end
end
