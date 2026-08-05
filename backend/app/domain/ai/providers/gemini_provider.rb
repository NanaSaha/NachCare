module Domain
  module Ai
    module Providers
      # Google Gemini direct API (generativelanguage.googleapis.com), added
      # alongside AnthropicProvider at the product owner's request — see
      # ADR-0014. Same dev-only status: this endpoint has no EU-region
      # option, so it's wired as a dev-convenience primary only (R8 is
      # bedrock_anthropic/azure_openai's job for anything production).
      #
      # Unlike Anthropic, Gemini *does* have a real embeddings endpoint
      # (gemini-embedding-001, supports arbitrary output dimensionality via
      # MRL truncation) — requested at exactly 1024 dims to match the
      # existing `knowledge_chunks.embedding vector(1024)` column, so real
      # semantic retrieval is possible here instead of always falling back
      # to the stub's crude feature-hashing for #embed.
      class GeminiProvider < Base
        DEFAULT_MODEL = "gemini-2.5-flash".freeze
        DEFAULT_EMBEDDING_MODEL = "gemini-embedding-001".freeze
        EMBEDDING_DIM = 1024

        def initialize(connection: nil)
          @connection = connection
        end

        def configured?
          ENV["GEMINI_API_KEY"].present?
        end

        def chat(messages:, system:, max_tokens: 512, temperature: 0.3, json_schema: nil)
          raise NotConfiguredError, "GEMINI_API_KEY not set" unless configured?

          generation_config = { temperature: temperature, maxOutputTokens: max_tokens }
          generation_config[:responseMimeType] = "application/json" if json_schema

          body = {
            contents: messages.map { |m| { role: gemini_role(m[:role]), parts: [ { text: m[:content].to_s } ] } },
            systemInstruction: { parts: [ { text: system.to_s } ] },
            generationConfig: generation_config
          }

          response = connection.post("/v1beta/models/#{model_id}:generateContent?key=#{ENV.fetch('GEMINI_API_KEY')}") do |req|
            req.headers["Content-Type"] = "application/json"
            req.body = body.to_json
          end

          raise ProviderError, "GeminiProvider: HTTP #{response.status}: #{response.body}" unless response.success?

          payload = JSON.parse(response.body)
          text = payload.dig("candidates", 0, "content", "parts", 0, "text").to_s

          ChatResult.new(
            text: text,
            json: (json_schema ? safe_parse_json(text) : nil),
            model: model_id,
            tokens_prompt: payload.dig("usageMetadata", "promptTokenCount"),
            tokens_completion: payload.dig("usageMetadata", "candidatesTokenCount")
          )
        rescue Faraday::Error, JSON::ParserError => e
          raise ProviderError, "GeminiProvider: #{e.class}: #{e.message}"
        end

        def embed(texts:)
          raise NotConfiguredError, "GEMINI_API_KEY not set" unless configured?

          requests = texts.map do |t|
            { model: "models/#{embedding_model_id}", content: { parts: [ { text: t.to_s } ] }, outputDimensionality: EMBEDDING_DIM }
          end

          response = connection.post("/v1beta/models/#{embedding_model_id}:batchEmbedContents?key=#{ENV.fetch('GEMINI_API_KEY')}") do |req|
            req.headers["Content-Type"] = "application/json"
            req.body = { requests: requests }.to_json
          end

          raise ProviderError, "GeminiProvider#embed: HTTP #{response.status}: #{response.body}" unless response.success?

          JSON.parse(response.body).fetch("embeddings").map { |e| e.fetch("values") }
        rescue Faraday::Error, JSON::ParserError => e
          raise ProviderError, "GeminiProvider#embed: #{e.class}: #{e.message}"
        end

        private

        def gemini_role(role)
          role.to_s == "assistant" ? "model" : "user"
        end

        def model_id
          ENV.fetch("GEMINI_MODEL", DEFAULT_MODEL)
        end

        def embedding_model_id
          ENV.fetch("GEMINI_EMBEDDING_MODEL", DEFAULT_EMBEDDING_MODEL)
        end

        def connection
          @connection ||= Faraday.new(url: "https://generativelanguage.googleapis.com")
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
