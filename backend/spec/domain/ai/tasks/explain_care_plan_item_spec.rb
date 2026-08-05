require "rails_helper"

RSpec.describe Domain::Ai::Tasks::ExplainCarePlanItem do
  let(:episode) { create(:episode) }
  let!(:caregiver) { create(:caregiver, episode: episode) }
  let(:gateway) { Domain::Ai::Gateway.new }

  it "returns an AI-sourced explanation grounded in the given item on success" do
    result = described_class.new(gateway: gateway).call(
      episode: episode, language: "en", item_type: "medication",
      item_label: "Furosemide", item_detail: "Medication: Furosemide. Scheduled times: 08:00. Nurse's instructions: with breakfast."
    )

    expect(result.source).to eq("ai")
    expect(result.text).to be_present
  end

  it "falls back to a non-AI template string when the provider chain is exhausted (Section 6 #1)" do
    allow(Domain::Ai::Gateway).to receive_messages(
      primary_provider: instance_double(Domain::Ai::Providers::Base, name: "p", configured?: true).tap { |d|
        allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down")
      },
      fallback_provider: instance_double(Domain::Ai::Providers::Base, name: "f", configured?: true).tap { |d|
        allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "down")
      }
    )

    result = described_class.new(gateway: gateway).call(
      episode: episode, language: "en", item_type: "diet_rules",
      item_label: "Diet", item_detail: "Low salt diet."
    )

    expect(result.source).to eq("template")
    expect(result.text).to be_present
  end
end
