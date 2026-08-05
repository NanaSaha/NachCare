module Domain
  module Ai
    module Tasks
      # T-TRIAGE copilot draft, Section 6 #1: "drafts: nil → UI hides
      # draft panel" on graceful degradation. ctx: {flag:, language:}
      class Triage
        def initialize(gateway:)
          @gateway = gateway
        end

        def call(ctx)
          flag = ctx.fetch(:flag)
          episode = flag.episode
          language = ctx.fetch(:language, "en")

          system = PromptAssembler.assemble(template: "triage", vars: {
            "PATIENT_PSEUDONYM" => Pseudonymizer.for_patient(episode.patient),
            "USER_LANGUAGE" => language,
            "FLAG_SEVERITY" => flag.severity,
            "FIRED_RULE_SUMMARIES" => fired_rule_summary(flag),
            "CHECKIN_CONTEXT" => checkin_context(episode),
            "CARE_PLAN_CONTEXT" => care_plan_context(episode)
          })

          result = gateway.call!(task: :triage, system: system, messages: [ { role: "user", content: "Draft the triage note." } ],
            episode: episode)
          result.text
        rescue Gateway::AllProvidersFailed
          nil
        end

        private

        attr_reader :gateway

        def fired_rule_summary(flag)
          Evaluation.where(id: flag.evaluation_refs).flat_map { |e| e.fired_rules || [] }.map { |r| r["key"] || r[:key] }.compact.join(", ").presence || "none"
        end

        def checkin_context(episode)
          last = episode.check_ins.order(effective_date: :desc).first
          last ? "last check-in #{last.effective_date}, weight #{last.weight_kg}" : "no recent check-in"
        end

        def care_plan_context(episode)
          plan = episode.care_plans.find_by(active: true)
          plan ? "diet_rules: #{plan.diet_rules}" : "no active care plan"
        end
      end
    end
  end
end
