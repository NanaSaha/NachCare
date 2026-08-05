require "rails_helper"

RSpec.describe Domain::Ai::Tasks::Callnote do
  let(:episode) { create(:episode) }
  let(:flag) { create(:flag, episode: episode, severity: "yellow") }
  let(:gateway) { Domain::Ai::Gateway.new }

  it "returns a drafted call note on success" do
    expect(described_class.new(gateway: gateway).call(flag: flag, language: "en")).to be_present
  end

  it "returns nil when the provider chain is exhausted" do
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
