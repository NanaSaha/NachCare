module Domain
  module Ai
    module Providers
      # Real primary provider (ADR-0007, Section 6): AWS Bedrock, Anthropic
      # Claude Sonnet-class model, region eu-central-1 (R8: EU-only). Uses
      # the `aws-sdk-bedrockruntime` gem rather than a bare Faraday client
      # because Bedrock requires AWS SigV4 request signing, which the SDK
      # handles; Faraday alone would mean reimplementing SigV4 by hand.
      # Titan Embed Text v2 (1024-dim, matching the pgvector column) is
      # used for #embed via the same client/region/credentials.
      class BedrockAnthropicProvider < Base
        CHAT_MODEL_ID = ENV.fetch("LLM_PRIMARY_MODEL", "")
        EMBED_MODEL_ID = ENV.fetch("LLM_EMBEDDING_MODEL", "amazon.titan-embed-text-v2:0")

        def initialize(client: nil)
          @client = client
        end

        def configured?
          ENV["AWS_ACCESS_KEY_ID"].present? && ENV["AWS_SECRET_ACCESS_KEY"].present? && CHAT_MODEL_ID.present?
        end

        def chat(messages:, system:, max_tokens: 512, temperature: 0.3, json_schema: nil)
          raise NotConfiguredError, "AWS credentials / LLM_PRIMARY_MODEL not set" unless configured?

          body = {
            anthropic_version: "bedrock-2023-05-31",
            max_tokens: max_tokens,
            temperature: temperature,
            system: system,
            messages: messages.map { |m| { role: m[:role].to_s, content: m[:content].to_s } }
          }

          response = client.invoke_model(model_id: CHAT_MODEL_ID, body: body.to_json, content_type: "application/json", accept: "application/json")
          payload = JSON.parse(response.body.read)
          text = payload.dig("content", 0, "text").to_s

          ChatResult.new(
            text: text,
            json: (json_schema ? safe_parse_json(text) : nil),
            model: CHAT_MODEL_ID,
            tokens_prompt: payload.dig("usage", "input_tokens"),
            tokens_completion: payload.dig("usage", "output_tokens")
          )
        rescue Aws::Errors::ServiceError, JSON::ParserError => e
          raise ProviderError, "BedrockAnthropicProvider: #{e.class}: #{e.message}"
        end

        def embed(texts:)
          raise NotConfiguredError, "AWS credentials not set" unless configured?

          texts.map do |text|
            response = client.invoke_model(model_id: EMBED_MODEL_ID, body: { inputText: text, dimensions: 1024 }.to_json,
              content_type: "application/json", accept: "application/json")
            JSON.parse(response.body.read).fetch("embedding")
          end
        rescue Aws::Errors::ServiceError, JSON::ParserError => e
          raise ProviderError, "BedrockAnthropicProvider#embed: #{e.class}: #{e.message}"
        end

        private

        def client
          @client ||= Aws::BedrockRuntime::Client.new(region: ENV.fetch("AWS_REGION", "eu-central-1"))
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
