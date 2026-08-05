require "rails_helper"

RSpec.describe Domain::Ai::Providers::GeminiProvider do
  def with_gemini_env
    original = ENV["GEMINI_API_KEY"]
    ENV["GEMINI_API_KEY"] = "test-key"
    yield
  ensure
    original.nil? ? ENV.delete("GEMINI_API_KEY") : ENV["GEMINI_API_KEY"] = original
  end

  describe "#configured?" do
    it "is false when GEMINI_API_KEY is unset" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return(nil)
      expect(described_class.new.configured?).to be false
    end
  end

  describe "#chat" do
    it "raises NotConfiguredError instead of attempting a network call when unconfigured" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return(nil)
      expect { described_class.new.chat(messages: [ { role: "user", content: "hi" } ], system: "x") }
        .to raise_error(Domain::Ai::Providers::Base::NotConfiguredError)
    end

    it "parses a successful response via an injected Faraday test connection" do
      with_gemini_env do
        stubs = Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post(/generateContent/) do
            [ 200, { "Content-Type" => "application/json" },
              { candidates: [ { content: { parts: [ { text: "hello caregiver" } ] } } ],
                usageMetadata: { promptTokenCount: 8, candidatesTokenCount: 4 } }.to_json ]
          end
        end
        connection = Faraday.new { |b| b.adapter :test, stubs }

        result = described_class.new(connection: connection).chat(messages: [ { role: "user", content: "hi" } ], system: "x")

        expect(result.text).to eq("hello caregiver")
        expect(result.tokens_prompt).to eq(8)
        expect(result.tokens_completion).to eq(4)
      end
    end

    it "raises ProviderError on a non-2xx response" do
      with_gemini_env do
        stubs = Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post(/generateContent/) { [ 400, {}, "bad request" ] }
        end
        connection = Faraday.new { |b| b.adapter :test, stubs }

        expect { described_class.new(connection: connection).chat(messages: [ { role: "user", content: "hi" } ], system: "x") }
          .to raise_error(Domain::Ai::Providers::Base::ProviderError)
      end
    end
  end

  describe "#embed" do
    it "raises NotConfiguredError instead of attempting a network call when unconfigured" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return(nil)
      expect { described_class.new.embed(texts: [ "a" ]) }.to raise_error(Domain::Ai::Providers::Base::NotConfiguredError)
    end

    it "returns one vector per input text via an injected Faraday test connection" do
      with_gemini_env do
        stubs = Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post(/batchEmbedContents/) do
            [ 200, { "Content-Type" => "application/json" },
              { embeddings: [ { values: [ 0.1, 0.2 ] }, { values: [ 0.3, 0.4 ] } ] }.to_json ]
          end
        end
        connection = Faraday.new { |b| b.adapter :test, stubs }

        result = described_class.new(connection: connection).embed(texts: [ "a", "b" ])

        expect(result).to eq([ [ 0.1, 0.2 ], [ 0.3, 0.4 ] ])
      end
    end
  end
end
