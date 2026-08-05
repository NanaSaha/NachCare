require "rails_helper"

RSpec.describe Domain::Ai::Providers::AzureOpenaiProvider do
  def with_azure_env
    original = {
      "AZURE_OPENAI_ENDPOINT" => ENV["AZURE_OPENAI_ENDPOINT"],
      "AZURE_OPENAI_DEPLOYMENT" => ENV["AZURE_OPENAI_DEPLOYMENT"],
      "AZURE_OPENAI_KEY" => ENV["AZURE_OPENAI_KEY"]
    }
    ENV["AZURE_OPENAI_ENDPOINT"] = "https://example-eu.openai.azure.com"
    ENV["AZURE_OPENAI_DEPLOYMENT"] = "gpt-nachcare"
    ENV["AZURE_OPENAI_KEY"] = "test-key"
    yield
  ensure
    original.each { |k, v| v.nil? ? ENV.delete(k) : ENV[k] = v }
  end

  describe "#configured?" do
    it "is false when AZURE_OPENAI_KEY is unset" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("AZURE_OPENAI_KEY").and_return(nil)
      expect(described_class.new.configured?).to be false
    end
  end

  describe "#chat" do
    it "raises NotConfiguredError instead of attempting a network call when unconfigured" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("AZURE_OPENAI_KEY").and_return(nil)
      expect { described_class.new.chat(messages: [ { role: "user", content: "hi" } ], system: "x") }
        .to raise_error(Domain::Ai::Providers::Base::NotConfiguredError)
    end

    it "parses a successful response via an injected Faraday test connection" do
      with_azure_env do
        stubs = Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post(/chat\/completions/) do
            [ 200, { "Content-Type" => "application/json" },
              { choices: [ { message: { content: "hello caregiver" } } ], model: "gpt-nachcare", usage: { prompt_tokens: 10, completion_tokens: 5 } }.to_json ]
          end
        end
        connection = Faraday.new { |b| b.adapter :test, stubs }

        result = described_class.new(connection: connection).chat(messages: [ { role: "user", content: "hi" } ], system: "x")

        expect(result.text).to eq("hello caregiver")
        expect(result.tokens_prompt).to eq(10)
      end
    end

    it "raises ProviderError on a non-2xx response" do
      with_azure_env do
        stubs = Faraday::Adapter::Test::Stubs.new do |stub|
          stub.post(/chat\/completions/) { [ 500, {}, "boom" ] }
        end
        connection = Faraday.new { |b| b.adapter :test, stubs }

        expect { described_class.new(connection: connection).chat(messages: [ { role: "user", content: "hi" } ], system: "x") }
          .to raise_error(Domain::Ai::Providers::Base::ProviderError)
      end
    end
  end
end
