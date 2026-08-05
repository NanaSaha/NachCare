module Domain
  module Ai
    module Tasks
      # UC-23 step 5: "a COPILOT rationale panel rendering the top
      # contributing signals in plain language ... never a bare score."
      # Same shape as T-TRIAGE (Domain::Ai::Tasks::Triage) — a copilot
      # explanation over structured data the nurse already has some
      # access to, not a new kind of pipeline. Unlike T-TRIAGE's graceful
      # degradation (nil, panel hides), this one degrades to a
      # deterministic plain-language rendering of the same component
      # breakdown the AI would have explained — the promise "never a bare
      # score" has to hold even when the AI call fails. ctx: {flag:,
      # language:}
      class AiWatchRationale
        def initialize(gateway:)
          @gateway = gateway
        end

        def call(ctx)
          flag = ctx.fetch(:flag)
          language = ctx.fetch(:language, "en")
          components = flag.ai_watch_meta["components"] || {}

          system = PromptAssembler.assemble(template: "ai_watch_rationale", vars: {
            "PATIENT_PSEUDONYM" => Pseudonymizer.for_patient(flag.episode.patient),
            "USER_LANGUAGE" => language,
            "RISK_COMPONENTS" => component_summary(components)
          })

          result = gateway.call!(task: :ai_watch_rationale, system: system,
            messages: [ { role: "user", content: "Explain the top contributing signals." } ], episode: flag.episode)
          result.text
        rescue Gateway::AllProvidersFailed
          template_rationale(components)
        end

        private

        attr_reader :gateway

        def component_summary(components)
          components.map { |k, v| "#{k.to_s.tr('_', ' ')}: #{format('%.2f', v.to_f)}" }.join(", ").presence || "no signal data"
        end

        # Deterministic plain-language fallback — still names the top
        # contributing signals, never just a bare number.
        def template_rationale(components)
          top = components.sort_by { |_, v| -v.to_f }.first(2).map { |k, _| k.to_s.tr("_", " ") }
          return "This trajectory crossed the watch threshold across multiple signals." if top.empty?

          "This trajectory crossed the watch threshold, driven mainly by: #{top.join(', ')}."
        end
      end
    end
  end
end
