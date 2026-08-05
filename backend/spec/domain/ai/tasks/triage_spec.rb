require "rails_helper"

RSpec.describe Domain::Ai::Tasks::Triage do
  let(:episode) { create(:episode) }
  let(:flag) { create(:flag, episode: episode, severity: "yellow") }
  let(:gateway) { Domain::Ai::Gateway.new }

  it "returns a drafted triage note on success" do
    result = described_class.new(gateway: gateway).call(flag: flag, language: "en")
    expect(result).to be_present
  end

  it "returns nil when the provider chain is exhausted (Section 6 #1: drafts -> nil -> UI hides panel)" do
    allow(Domain::Ai::Gateway).to receive_messages(
      primary_provider: instance_double(Domain::Ai::Providers::Base, name: "p", configured?: true).tap { |d|
        allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down")
      },
      fallback_provider: instance_double(Domain::Ai::Providers::Base, name: "f", configured?: true).tap { |d|
        allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down")
      }
    )

    expect(described_class.new(gateway: gateway).call(flag: flag, language: "en")).to be_nil
  end
end
