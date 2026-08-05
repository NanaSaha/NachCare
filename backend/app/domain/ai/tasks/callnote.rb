module Domain
  module Ai
    module Tasks
      # T-CALLNOTE prefill, Section 6 #1: "drafts: nil → UI hides draft
      # panel" on graceful degradation. ctx: {flag:, language:}
      class Callnote
        def initialize(gateway:)
          @gateway = gateway
        end

        def call(ctx)
          flag = ctx.fetch(:flag)
          episode = flag.episode
          language = ctx.fetch(:language, "en")

          system = PromptAssembler.assemble(template: "callnote", vars: {
            "PATIENT_PSEUDONYM" => Pseudonymizer.for_patient(episode.patient),
            "USER_LANGUAGE" => language,
            "FIRED_RULE_SUMMARIES" => fired_rule_summary(flag),
            "INTERVENTION_HISTORY" => intervention_history(flag)
          })

          result = gateway.call!(task: :callnote, system: system, messages: [ { role: "user", content: "Draft the call note." } ],
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

        def intervention_history(flag)
          flag.interventions.order(:created_at).map { |i| i.note_final || i.note_ai }.compact.join("; ").presence || "none yet"
        end
      end
    end
  end
end
