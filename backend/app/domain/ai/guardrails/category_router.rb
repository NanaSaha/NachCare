module Domain
  module Ai
    module Guardrails
      # Section 6 #4 stage 2: deterministic keyword pre-router first
      # (KeywordPreRouter, no LLM call), then LLM classification into
      # {in_scope, medication_or_dosage, diagnosis_or_prognosis,
      # care_plan_conflict, out_of_scope}.
      #
      # R3's routing applies to the three clinically-sensitive categories
      # (medication_or_dosage, diagnosis_or_prognosis, care_plan_conflict)
      # — those create a cockpit task so a nurse follows up.
      # `out_of_scope` (small talk, off-topic, prompt-injection attempts)
      # is redirected with an empathetic non-answer but does *not* create
      # a cockpit task — it isn't a clinical signal, and routing every
      # off-topic message to a nurse queue would drown the signal R3 cares
      # about. This distinction is a reading of R3 applied to a category
      # the rule doesn't explicitly enumerate; documented here rather than
      # as a separate ADR since it follows directly from R3's own scope.
      class CategoryRouter
        ROUTED_TO_NURSE = %w[medication_or_dosage diagnosis_or_prognosis care_plan_conflict].freeze
        CATEGORIES = (ROUTED_TO_NURSE + %w[in_scope out_of_scope]).freeze

        def self.route(text:, language:, gateway:)
          new(gateway:).route(text:, language:)
        end

        def initialize(gateway:)
          @gateway = gateway
        end

        def route(text:, language:)
          pre_routed = Guardrails::KeywordPreRouter.route(text)
          return { "category" => pre_routed, "source" => "keyword_pre_router" } if pre_routed

          result = gateway.call!(
            task: :assistant,
            system: "You are a category classifier for a heart-failure caregiver assistant. " \
                    "Classify the caregiver's message into exactly one of: #{CATEGORIES.join(', ')}.",
            messages: [ { role: "user", content: text } ],
            json_schema: { kind: :category, language: language }
          )
          category = CATEGORIES.include?(result.json["category"]) ? result.json["category"] : "out_of_scope"
          { "category" => category, "source" => "llm" }
        end

        def self.routed_to_nurse?(category) = ROUTED_TO_NURSE.include?(category)

        private

        attr_reader :gateway
      end
    end
  end
end
