require "rails_helper"

RSpec.describe Domain::Ai::Tasks::Assistant do
  let(:episode) { create(:episode) }
  let(:caregiver) { create(:caregiver, episode: episode) }
  let(:conversation) { create(:assistant_conversation, episode: episode, caregiver: caregiver) }
  let(:gateway) { Domain::Ai::Gateway.new }

  it "returns the pipeline's result on success" do
    result = described_class.new(gateway: gateway).call(
      episode: episode, caregiver: caregiver, conversation: conversation, language: "en", message: "how do I log a symptom?"
    )
    expect(result).to be_a(Domain::Ai::AssistantPipeline::Result)
  end

  it "degrades to routed_to_nurse and opens a flag when the provider chain is exhausted" do
    allow(Domain::Ai::Gateway).to receive_messages(
      primary_provider: instance_double(Domain::Ai::Providers::Base, name: "p", configured?: true).tap { |d|
        allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down")
      },
      fallback_provider: instance_double(Domain::Ai::Providers::Base, name: "f", configured?: true).tap { |d|
        allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down")
      }
    )

    result = described_class.new(gateway: gateway).call(
      episode: episode, caregiver: caregiver, conversation: conversation, language: "en", message: "how do I log a symptom?"
    )

    expect(result.degraded).to be true
    expect(result.routed).to be true
    expect(result.routed_flag_id).to be_present
    expect(Flag.find(result.routed_flag_id).state).to eq("open")
  end
end
