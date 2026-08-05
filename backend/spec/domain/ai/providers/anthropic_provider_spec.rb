require "rails_helper"

RSpec.describe Domain::Ai::Providers::AnthropicProvider do
  def with_anthropic_env
    original = ENV["ANTHROPIC_API_KEY"]
    ENV["ANTHROPIC_API_KEY"] = "test-key"
    yield
  ensure
    original.nil? ? ENV.delete("ANTHROPIC_API_KEY") : ENV["ANTHROPIC_API_KEY"] = original
  end

  describe "#configured?" do
    it "is false when ANTHROPIC_API_KEY is unset" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil)
      expect(described_class.new.configured?).to be false
    end
  end

  describe "#chat" do
    it "raises NotConfiguredError instead of attempting a network call when unconfigured" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("ANTHROPIC_API_KEY").and_return(nil)
      expect { described_class.new.chat(messages: [ { role: "user", content: "hi" } ], system: "x") }
        .to raise_error(Domain::Ai::Providers::Base::NotConfiguredError)
    end

    it "parses a successful response via an injected Faraday test connection" do
      with_anthropic_env do
        stubs = Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post("/v1/messages") do |env|
            expect(env.request_headers["x-api-key"]).to eq("test-key")
            expect(env.request_headers["anthropic-version"]).to be_present
            [ 200, { "Content-Type" => "application/json" },
              { content: [ { type: "text", text: "hello caregiver" } ], model: "claude-sonnet-5",
                usage: { input_tokens: 12, output_tokens: 6 } }.to_json ]
          end
        end
        connection = Faraday.new { |b| b.adapter :test, stubs }

        result = described_class.new(connection: connection).chat(messages: [ { role: "user", content: "hi" } ], system: "x")

        expect(result.text).to eq("hello caregiver")
        expect(result.model).to eq("claude-sonnet-5")
        expect(result.tokens_prompt).to eq(12)
        expect(result.tokens_completion).to eq(6)
      end
    end

    it "raises ProviderError on a non-2xx response" do
      with_anthropic_env do
        stubs = Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post("/v1/messages") { [ 401, {}, "unauthorized" ] }
        end
        connection = Faraday.new { |b| b.adapter :test, stubs }

        expect { described_class.new(connection: connection).chat(messages: [ { role: "user", content: "hi" } ], system: "x") }
          .to raise_error(Domain::Ai::Providers::Base::ProviderError)
      end
    end
  end

  describe "#embed" do
    it "always raises NotConfiguredError — Anthropic has no embeddings endpoint" do
      with_anthropic_env do
        expect { described_class.new.embed(texts: [ "a" ]) }.to raise_error(Domain::Ai::Providers::Base::NotConfiguredError)
      end
    end
  end
end
