module Domain
  module Ai
    module Providers
      # Real fallback provider (ADR-0007, Section 6): Azure OpenAI, EU
      # deployment region (docs/SUBPROCESSORS.md — region TBD, set via
      # AZURE_OPENAI_ENDPOINT). Plain REST + api-key header, so a bare
      # Faraday client is sufficient here (no request signing needed,
      # unlike Bedrock).
      class AzureOpenaiProvider < Base
        def initialize(connection: nil)
          @connection = connection
        end

        def configured?
          ENV["AZURE_OPENAI_ENDPOINT"].present? && ENV["AZURE_OPENAI_DEPLOYMENT"].present? && ENV["AZURE_OPENAI_KEY"].present?
        end

        def chat(messages:, system:, max_tokens: 512, temperature: 0.3, json_schema: nil)
          raise NotConfiguredError, "AZURE_OPENAI_* env vars not set" unless configured?

          body = {
            messages: [ { role: "system", content: system } ] + messages.map { |m| { role: m[:role].to_s, content: m[:content].to_s } },
            max_tokens: max_tokens,
            temperature: temperature
          }
          body[:response_format] = { type: "json_object" } if json_schema

          response = connection.post(chat_path) do |req|
            req.headers["Content-Type"] = "application/json"
            req.headers["api-key"] = ENV.fetch("AZURE_OPENAI_KEY")
            req.body = body.to_json
          end

          raise ProviderError, "AzureOpenaiProvider: HTTP #{response.status}" unless response.success?

          payload = JSON.parse(response.body)
          text = payload.dig("choices", 0, "message", "content").to_s

          ChatResult.new(
            text: text,
            json: (json_schema ? safe_parse_json(text) : nil),
            model: payload["model"],
            tokens_prompt: payload.dig("usage", "prompt_tokens"),
            tokens_completion: payload.dig("usage", "completion_tokens")
          )
        rescue Faraday::Error, JSON::ParserError => e
          raise ProviderError, "AzureOpenaiProvider: #{e.class}: #{e.message}"
        end

        def embed(texts:)
          raise NotConfiguredError, "AZURE_OPENAI_* env vars not set" unless configured?

          response = connection.post("/openai/deployments/#{ENV.fetch('AZURE_OPENAI_EMBEDDING_DEPLOYMENT', ENV['AZURE_OPENAI_DEPLOYMENT'])}/embeddings?api-version=2024-02-01") do |req|
            req.headers["Content-Type"] = "application/json"
            req.headers["api-key"] = ENV.fetch("AZURE_OPENAI_KEY")
            req.body = { input: texts }.to_json
          end
          raise ProviderError, "AzureOpenaiProvider#embed: HTTP #{response.status}" unless response.success?

          JSON.parse(response.body).fetch("data").map { |d| d.fetch("embedding") }
        rescue Faraday::Error, JSON::ParserError => e
          raise ProviderError, "AzureOpenaiProvider#embed: #{e.class}: #{e.message}"
        end

        private

        def chat_path
          "/openai/deployments/#{ENV.fetch('AZURE_OPENAI_DEPLOYMENT', '')}/chat/completions?api-version=2024-02-01"
        end

        def connection
          @connection ||= Faraday.new(url: ENV.fetch("AZURE_OPENAI_ENDPOINT", ""))
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
