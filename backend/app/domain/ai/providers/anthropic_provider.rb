module Domain
  module Ai
    module Providers
      # Direct Anthropic API (api.anthropic.com), not AWS Bedrock. Added at
      # the product owner's explicit request for real dev/test answers —
      # see ADR-0014. Unlike BedrockAnthropicProvider (the app's original
      # R8-compliant EU-region primary), this endpoint is US-hosted, so it
      # is wired as a dev-only primary (config/ai.yml's development block),
      # never production, and documented as a deliberate, known deviation
      # in docs/SUBPROCESSORS.md rather than silently ignored.
      #
      # Anthropic has no embeddings endpoint, so #embed always raises
      # NotConfiguredError — Domain::Ai::Gateway#embed! catches that per
      # provider and falls through to the next one in the chain (the stub
      # provider, kept as `fallback` in config/ai.yml specifically so RAG
      # retrieval still works via its deterministic feature-hashing
      # embeddings even though the real chat provider can't embed).
      class AnthropicProvider < Base
        API_VERSION = "2023-06-01".freeze
        DEFAULT_MODEL = "claude-sonnet-5".freeze

        def initialize(connection: nil)
          @connection = connection
        end

        def configured?
          ENV["ANTHROPIC_API_KEY"].present?
        end

        def chat(messages:, system:, max_tokens: 512, temperature: 0.3, json_schema: nil)
          raise NotConfiguredError, "ANTHROPIC_API_KEY not set" unless configured?

          body = {
            model: model_id,
            max_tokens: max_tokens,
            temperature: temperature,
            system: system,
            messages: messages.map { |m| { role: m[:role].to_s, content: m[:content].to_s } }
          }

          response = connection.post("/v1/messages") do |req|
            req.headers["Content-Type"] = "application/json"
            req.headers["x-api-key"] = ENV.fetch("ANTHROPIC_API_KEY")
            req.headers["anthropic-version"] = API_VERSION
            req.body = body.to_json
          end

          raise ProviderError, "AnthropicProvider: HTTP #{response.status}: #{response.body}" unless response.success?

          payload = JSON.parse(response.body)
          text = payload.dig("content", 0, "text").to_s

          ChatResult.new(
            text: text,
            json: (json_schema ? safe_parse_json(text) : nil),
            model: payload["model"],
            tokens_prompt: payload.dig("usage", "input_tokens"),
            tokens_completion: payload.dig("usage", "output_tokens")
          )
        rescue Faraday::Error, JSON::ParserError => e
          raise ProviderError, "AnthropicProvider: #{e.class}: #{e.message}"
        end

        def embed(texts:)
          raise NotConfiguredError, "AnthropicProvider has no embeddings endpoint — see class comment"
        end

        private

        def model_id
          ENV.fetch("ANTHROPIC_MODEL", DEFAULT_MODEL)
        end

        def connection
          @connection ||= Faraday.new(url: "https://api.anthropic.com")
        end

        def safe_parse_json(text)
          JSON.parse(text)
        rescue JSON::ParserError
          nil
        end
      end
    end
  end
end
