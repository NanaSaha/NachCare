module Domain
  module Ai
    module Tasks
      ExplainResult = Struct.new(:text, :source, keyword_init: true) # source: "ai" | "template"

      # Product-owner feedback item #1 (post-M7, ADR-0013): a caregiver taps
      # a specific care-plan item on Home (a medication, or the nurse's
      # free-text care_instructions/diet_rules) and gets a plain-language
      # explanation of it. Deliberately NOT built on top of AssistantPipeline
      # (Tasks::Assistant) — that pipeline depends on fuzzy knowledge-base
      # retrieval and would suffer the exact same "no match -> routed"
      # failure this feedback round already fixed once (see
      # docs/OPEN_CLINICAL_ITEMS.md row 12); explaining a specific,
      # already-known structured item doesn't need retrieval at all, only
      # the item's own data.
      #
      # R3 boundary: this task explains an already-prescribed fact the
      # nurse already committed to — it never decides or advises on any
      # change. It takes no caregiver free text as input (only the
      # structured item passed in by the controller from the caregiver's
      # own active care plan), so there is no user message for a caregiver
      # to redirect toward "should we change this" — the prompt template
      # additionally constrains the model to explain-only framing as a
      # second layer of defense (config/prompts/explain_care_plan_item.md).
      #
      # ctx: {episode:, language:, item_type:, item_label:, item_detail:}
      # item_type: "medication" | "care_instructions" | "diet_rules"
      class ExplainCarePlanItem
        def initialize(gateway:)
          @gateway = gateway
        end

        def call(ctx)
          episode = ctx.fetch(:episode)
          language = ctx.fetch(:language, "en")

          system = PromptAssembler.assemble(template: "explain_care_plan_item", vars: {
            "PATIENT_PSEUDONYM" => Pseudonymizer.for_patient(episode.patient),
            "USER_LANGUAGE" => language,
            "ITEM_TYPE" => ctx.fetch(:item_type),
            "ITEM_LABEL" => ctx.fetch(:item_label),
            "ITEM_DETAIL" => ctx.fetch(:item_detail)
          })

          result = gateway.call!(
            task: :explain_care_plan_item, system: system,
            messages: [ { role: "user", content: "Explain this care-plan item to the caregiver." } ],
            caregiver: episode.caregivers.first, episode: episode
          )
          ExplainResult.new(text: result.text, source: "ai")
        rescue Gateway::AllProvidersFailed
          ExplainResult.new(text: template_fallback, source: "template")
        end

        private

        attr_reader :gateway

        # Non-AI fallback (Section 6 #1 graceful-degradation spirit, same
        # pattern as Tasks::Brief#template_brief): no generation at all,
        # just a safe, generic pointer back to the nurse.
        def template_fallback
          "Ask your nurse if you'd like more detail on this."
        end
      end
    end
  end
end
