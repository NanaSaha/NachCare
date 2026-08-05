require "rails_helper"

RSpec.describe Domain::Ai::Tasks::Report do
  let(:episode) { create(:episode) }
  let(:gateway) { Domain::Ai::Gateway.new }

  it "returns a drafted report on success" do
    expect(described_class.new(gateway: gateway).call(episode: episode, language: "en")).to be_present
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

    expect(described_class.new(gateway: gateway).call(episode: episode, language: "en")).to be_nil
  end
end
