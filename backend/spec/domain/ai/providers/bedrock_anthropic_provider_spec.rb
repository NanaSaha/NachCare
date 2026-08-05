require "rails_helper"

RSpec.describe Domain::Ai::Providers::BedrockAnthropicProvider do
  describe "#configured?" do
    it "is false without AWS credentials" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("AWS_ACCESS_KEY_ID").and_return(nil)
      expect(described_class.new.configured?).to be false
    end
  end

  describe "#chat" do
    it "raises NotConfiguredError instead of attempting a network call when unconfigured" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("AWS_ACCESS_KEY_ID").and_return(nil)
      expect { described_class.new.chat(messages: [ { role: "user", content: "hi" } ], system: "x") }
        .to raise_error(Domain::Ai::Providers::Base::NotConfiguredError)
    end
  end

  describe "#embed" do
    it "raises NotConfiguredError instead of attempting a network call when unconfigured" do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with("AWS_ACCESS_KEY_ID").and_return(nil)
      expect { described_class.new.embed(texts: [ "hi" ]) }.to raise_error(Domain::Ai::Providers::Base::NotConfiguredError)
    end
  end
end
