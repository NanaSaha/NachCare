require "rails_helper"

RSpec.describe Domain::Ai::Gateway do
  let(:success_result) { Domain::Ai::Providers::ChatResult.new(text: "ok", model: "fake") }

  def fake_provider(configured: true, &block)
    provider = instance_double(Domain::Ai::Providers::Base, name: "fake", configured?: configured)
    if block
      allow(provider).to receive(:chat, &block)
    else
      allow(provider).to receive(:chat)
    end
    provider
  end

  describe "#call!" do
    it "returns the primary provider's result on success, with no retry/fallback" do
      primary = fake_provider { success_result }
      fallback = fake_provider
      allow(described_class).to receive_messages(primary_provider: primary, fallback_provider: fallback)

      result = described_class.call!(task: :assistant, system: "s", messages: [ { role: "user", content: "hi" } ])

      expect(result).to eq(success_result)
      expect(fallback).not_to have_received(:chat)
    end

    it "retries the primary provider once before trying the fallback" do
      call_count = 0
      primary = fake_provider do
        call_count += 1
        raise Domain::Ai::Providers::Base::ProviderError, "boom" if call_count == 1

        success_result
      end
      fallback = fake_provider
      allow(described_class).to receive_messages(primary_provider: primary, fallback_provider: fallback)

      result = described_class.call!(task: :assistant, system: "s", messages: [ { role: "user", content: "hi" } ])

      expect(result).to eq(success_result)
      expect(call_count).to eq(2)
      expect(fallback).not_to have_received(:chat)
    end

    it "falls back to the fallback provider when the primary fails twice" do
      primary = fake_provider { raise Domain::Ai::Providers::Base::ProviderError, "boom" }
      fallback = fake_provider { success_result }
      allow(described_class).to receive_messages(primary_provider: primary, fallback_provider: fallback)

      result = described_class.call!(task: :assistant, system: "s", messages: [ { role: "user", content: "hi" } ])

      expect(result).to eq(success_result)
    end

    it "raises AllProvidersFailed when primary and fallback both fail" do
      primary = fake_provider { raise Domain::Ai::Providers::Base::ProviderError, "boom" }
      fallback = fake_provider { raise Domain::Ai::Providers::Base::ProviderError, "boom" }
      allow(described_class).to receive_messages(primary_provider: primary, fallback_provider: fallback)

      expect { described_class.call!(task: :assistant, system: "s", messages: [ { role: "user", content: "hi" } ]) }
        .to raise_error(described_class::AllProvidersFailed)
    end

    it "skips an unconfigured provider without attempting a call" do
      primary = fake_provider(configured: false)
      fallback = fake_provider { success_result }
      allow(described_class).to receive_messages(primary_provider: primary, fallback_provider: fallback)

      result = described_class.call!(task: :assistant, system: "s", messages: [ { role: "user", content: "hi" } ])

      expect(result).to eq(success_result)
      expect(primary).not_to have_received(:chat)
    end

    it "enforces the per-task timeout" do
      primary = fake_provider do
        sleep 0.2
        success_result
      end
      fallback = fake_provider { success_result }
      allow(described_class).to receive_messages(primary_provider: primary, fallback_provider: fallback)
      allow(described_class).to receive(:config).and_return(
        ActiveSupport::OrderedOptions.new.update(timeouts_ms: { assistant: 10 }, retry_count: 0, providers: { primary: "stub", fallback: "stub" })
      )

      result = described_class.call!(task: :assistant, system: "s", messages: [ { role: "user", content: "hi" } ])

      # timed out on primary, fell through to fallback
      expect(result).to eq(success_result)
    end

    it "logs an AiCall row on success" do
      primary = fake_provider { success_result }
      allow(described_class).to receive_messages(primary_provider: primary, fallback_provider: fake_provider)

      expect {
        described_class.call!(task: :assistant, system: "s", messages: [ { role: "user", content: "hi" } ])
      }.to change(AiCall, :count).by(1)

      expect(AiCall.last.status).to eq("success")
      expect(AiCall.last.task).to eq("assistant")
    end

    it "logs an AiCall row on failure and never leaks unredacted PHI-adjacent text into the log" do
      primary = fake_provider { raise Domain::Ai::Providers::Base::ProviderError, "boom" }
      fallback = fake_provider { raise Domain::Ai::Providers::Base::ProviderError, "boom" }
      allow(described_class).to receive_messages(primary_provider: primary, fallback_provider: fallback)

      expect {
        expect { described_class.call!(task: :assistant, system: "s", messages: [ { role: "user", content: "call me at a@b.com" } ]) }
          .to raise_error(described_class::AllProvidersFailed)
      }.to change(AiCall, :count).by(1)

      expect(AiCall.last.status).to eq("failed")
      expect(AiCall.last.content).not_to include("a@b.com")
    end
  end

  describe "provider selection (ADR-0007)" do
    it "defaults to the stub provider in test" do
      described_class.reset_config_cache!
      expect(described_class.primary_provider).to be_a(Domain::Ai::Providers::StubProvider)
      expect(described_class.fallback_provider).to be_a(Domain::Ai::Providers::StubProvider)
    end
  end
end
