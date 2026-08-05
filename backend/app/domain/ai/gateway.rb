module Domain
  module Ai
    # Domain::Ai::Gateway — Section 6. Two responsibilities:
    #
    # 1. `call!` — the low-level provider chain: primary provider, one
    #    retry on the same provider, one attempt on the fallback provider,
    #    each under the task's timeout. Raises AllProvidersFailed if every
    #    attempt fails. Used internally by guardrail stages and by the
    #    Tasks:: classes; logs every attempt's outcome to `ai_calls`.
    # 2. One public method per task (`assistant_reply`, `daily_brief`,
    #    `triage_draft`, `callnote_draft`, `episode_report`, `translate`)
    #    — each delegates to a Domain::Ai::Tasks:: class that assembles the
    #    prompt and, on AllProvidersFailed, returns that task's documented
    #    graceful-degradation object (ADR-0007) instead of raising.
    class Gateway
      class AllProvidersFailed < StandardError; end

      PROVIDER_CLASSES = {
        "stub" => Providers::StubProvider,
        "bedrock_anthropic" => Providers::BedrockAnthropicProvider,
        "azure_openai" => Providers::AzureOpenaiProvider,
        "anthropic" => Providers::AnthropicProvider,
        "gemini" => Providers::GeminiProvider
      }.freeze

      class << self
        def config
          @config ||= Rails.application.config_for(:ai)
        end

        def reset_config_cache!
          @config = nil
          @primary_provider = nil
          @fallback_provider = nil
        end

        def primary_provider
          @primary_provider ||= build_provider(:primary)
        end

        def fallback_provider
          @fallback_provider ||= build_provider(:fallback)
        end

        def build_provider(slot)
          key = ENV["AI_PROVIDER_OVERRIDE"].presence || config.providers[slot].to_s
          PROVIDER_CLASSES.fetch(key).new
        end

        # Low-level provider call with the timeout/retry/fallback chain.
        # Always logs an AiCall row. Raises AllProvidersFailed if every
        # attempt in the chain fails or is unconfigured.
        def call!(task:, messages:, system:, max_tokens: 512, temperature: 0.3, json_schema: nil,
                   caregiver: nil, episode: nil, conversation: nil)
          new.call!(task:, messages:, system:, max_tokens:, temperature:, json_schema:, caregiver:, episode:, conversation:)
        end

        [ :assistant_reply, :daily_brief, :triage_draft, :callnote_draft, :episode_report, :translate, :ai_watch_rationale, :explain_care_plan_item ].each do |m|
          define_method(m) { |ctx| new.public_send(m, ctx) }
        end

        # Embeddings don't need the timeout/json_schema machinery #call!
        # has — just primary-then-fallback, each attempt logged.
        def embed!(texts:)
          [ primary_provider, fallback_provider ].each do |provider|
            next unless provider.configured?

            started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
            vectors = provider.embed(texts: texts)
            latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
            AiCall.create!(task: "embedding", provider: provider.name, status: "success", latency_ms: latency_ms,
              prompt_sha256: Digest::SHA256.hexdigest(texts.join("\n")))
            return vectors
          rescue StandardError => e
            Rails.logger.warn("[Domain::Ai::Gateway] embed provider=#{provider.name} failed: #{e.class}")
          end

          raise AllProvidersFailed, "all providers failed for embed"
        end
      end

      def call!(task:, messages:, system:, max_tokens: 512, temperature: 0.3, json_schema: nil,
                 caregiver: nil, episode: nil, conversation: nil)
        timeout_s = self.class.config.timeouts_ms.fetch(task.to_sym, 20_000) / 1000.0
        retry_count = self.class.config.retry_count
        attempts = [ self.class.primary_provider ] * (1 + retry_count) + [ self.class.fallback_provider ]

        started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        last_error = nil

        attempts.each do |provider|
          result = attempt(provider:, timeout_s:, messages:, system:, max_tokens:, temperature:, json_schema:)
          if result
            latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
            log_call!(task:, provider:, status: "success", latency_ms:, messages:, system:, result:, caregiver:, episode:, conversation:)
            return result
          end
        rescue StandardError => e
          last_error = e
        end

        latency_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round
        log_call!(task:, provider: attempts.last, status: "failed", latency_ms:, messages:, system:, result: nil, caregiver:, episode:, conversation:, error: last_error)
        raise AllProvidersFailed, "all providers failed for task=#{task}: #{last_error&.message}"
      end

      # --- task methods (Section 6) ---

      def assistant_reply(ctx) = Tasks::Assistant.new(gateway: self).call(ctx)
      def daily_brief(ctx) = Tasks::Brief.new(gateway: self).call(ctx)
      def triage_draft(ctx) = Tasks::Triage.new(gateway: self).call(ctx)
      def callnote_draft(ctx) = Tasks::Callnote.new(gateway: self).call(ctx)
      def episode_report(ctx) = Tasks::Report.new(gateway: self).call(ctx)
      def translate(ctx) = Tasks::Translate.new(gateway: self).call(ctx)
      def ai_watch_rationale(ctx) = Tasks::AiWatchRationale.new(gateway: self).call(ctx)
      def explain_care_plan_item(ctx) = Tasks::ExplainCarePlanItem.new(gateway: self).call(ctx)

      private

      def attempt(provider:, timeout_s:, messages:, system:, max_tokens:, temperature:, json_schema:)
        return nil unless provider.configured?

        Timeout.timeout(timeout_s) do
          provider.chat(messages:, system:, max_tokens:, temperature:, json_schema:)
        end
      rescue Timeout::Error, Providers::Base::ProviderError => e
        Rails.logger.warn("[Domain::Ai::Gateway] provider=#{provider.name} failed: #{e.class}")
        nil
      end

      def log_call!(task:, provider:, status:, latency_ms:, messages:, system:, result:, caregiver:, episode:, conversation:, error: nil)
        redacted_prompt = Redactor.redact("#{system}\n#{messages.map { |m| m[:content] }.join("\n")}")
        redacted_response = Redactor.redact(result&.text || result&.json&.to_json || error&.message.to_s)

        AiCall.create!(
          task: task.to_s,
          provider: provider&.name || "unknown",
          model: result&.model,
          status: status,
          latency_ms: latency_ms,
          tokens_prompt: result&.tokens_prompt,
          tokens_completion: result&.tokens_completion,
          prompt_sha256: Digest::SHA256.hexdigest(redacted_prompt),
          response_sha256: (Digest::SHA256.hexdigest(redacted_response) if result),
          content: "#{redacted_prompt}\n---\n#{redacted_response}",
          caregiver_ref: caregiver&.id,
          episode_ref: episode&.id,
          conversation_ref: conversation&.id
        )
      rescue StandardError => e
        # Logging must never take down the actual AI call — surface loudly
        # instead (R6 spirit: audit gaps are a loud failure, not a silent one).
        Rails.logger.error("[Domain::Ai::Gateway] failed to log ai_call: #{e.class}: #{e.message}")
      end
    end
  end
end
