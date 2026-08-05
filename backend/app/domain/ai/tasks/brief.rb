module Domain
  module Ai
    module Tasks
      BriefResult = Struct.new(:text, :source, keyword_init: true) # source: "ai" | "template"

      # T-BRIEF, Section 6 #1: "brief: template-only non-AI brief" on
      # graceful degradation. ctx: {evaluation:, episode:, language:}
      class Brief
        FIRED_RULE_KEY = "fired_rules"

        def initialize(gateway:)
          @gateway = gateway
        end

        def call(ctx)
          evaluation = ctx.fetch(:evaluation)
          episode = ctx.fetch(:episode)
          language = ctx.fetch(:language, "en")

          system = PromptAssembler.assemble(template: "brief", vars: {
            "PATIENT_PSEUDONYM" => Pseudonymizer.for_patient(episode.patient),
            "USER_LANGUAGE" => language,
            "EVALUATION_SEVERITY" => evaluation.severity,
            "FIRED_RULE_SUMMARIES" => fired_rule_summary(evaluation),
            "TREND_SUMMARY" => trend_summary(episode)
          })

          result = gateway.call!(task: :brief, system: system, messages: [ { role: "user", content: "Generate the brief." } ],
            caregiver: episode.caregivers.first, episode: episode)
          BriefResult.new(text: result.text, source: "ai")
        rescue Gateway::AllProvidersFailed
          BriefResult.new(text: template_brief(evaluation), source: "template")
        end

        private

        attr_reader :gateway

        def fired_rule_summary(evaluation)
          (evaluation.fired_rules || []).map { |r| r["key"] || r[:key] }.compact.join(", ").presence || "none"
        end

        def trend_summary(episode)
          last = episode.check_ins.where.not(weight_kg: nil).order(effective_date: :desc).limit(2).pluck(:weight_kg)
          last.size == 2 ? "weight change: #{(last[0] - last[1]).round(1)} kg" : "insufficient history"
        end

        # Non-AI fallback: plain severity-keyed copy, no generation at all.
        def template_brief(evaluation)
          case evaluation.severity
          when "red" then "Today's check-in needs attention — your care team has been notified."
          when "yellow" then "Today's check-in shows something worth watching. See your action steps below."
          else "Today's check-in looks good. Keep up the daily routine."
          end
        end
      end
    end
  end
end
