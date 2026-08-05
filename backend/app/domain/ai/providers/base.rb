module Domain
  module Ai
    module Providers
      # Provider abstraction (Section 6). Every provider — real or stub —
      # implements #chat and #embed with this exact signature so
      # Domain::Ai::Gateway can swap between primary/fallback/stub without
      # any caller caring which one actually ran.
      class Base
        class NotConfiguredError < StandardError; end
        class ProviderError < StandardError; end

        # @return [Boolean] whether this provider has the credentials/config
        #   it needs to actually make a call. Checked before attempting a
        #   call so unavailable providers fail fast, not via a hung timeout.
        def configured?
          raise NotImplementedError
        end

        # @param messages [Array<Hash>] [{role:, content:}, ...]
        # @param system [String] system prompt
        # @param max_tokens [Integer]
        # @param temperature [Float]
        # @param json_schema [Hash, nil] when present, the provider must
        #   return JSON matching this shape (used by guardrail
        #   classification calls); when nil, free-text generation.
        # @return [Domain::Ai::Providers::ChatResult]
        def chat(messages:, system:, max_tokens: 512, temperature: 0.3, json_schema: nil)
          raise NotImplementedError
        end

        # @param texts [Array<String>]
        # @return [Array<Array<Float>>] one embedding vector per input text
        def embed(texts:)
          raise NotImplementedError
        end

        def name
          self.class.name.demodulize.underscore.sub(/_provider\z/, "")
        end
      end

      ChatResult = Struct.new(:text, :json, :model, :tokens_prompt, :tokens_completion, keyword_init: true)
    end
  end
end
