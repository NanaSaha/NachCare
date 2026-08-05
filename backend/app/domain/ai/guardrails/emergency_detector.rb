module Domain
  module Ai
    module Guardrails
      # Section 6 #4 stage 1: "small LLM classification call with
      # recall-oriented prompt over the user message, 5 languages; on
      # positive: return emergency payload (frontend renders static 112
      # block on top), notify nurse, still allow a calm grounded answer
      # beneath." This class only decides positive/negative — the
      # "renders static 112 block" part is the frontend's static markup
      # (R4: never gated on this call succeeding), and "notify nurse" /
      # "calm answer beneath" are orchestrated by AssistantPipeline.
      #
      # Raises Gateway::AllProvidersFailed if the provider chain is
      # exhausted — callers must treat that as fail-closed (route), never
      # as "assume no emergency," per R3's "if any layer is uncertain, route."
      class EmergencyDetector
        def self.check(text:, language:, gateway:)
          new(gateway:).check(text:, language:)
        end

        def initialize(gateway:)
          @gateway = gateway
        end

        def check(text:, language:)
          result = gateway.call!(
            task: :assistant,
            system: "You are an emergency classifier for a heart-failure caregiver assistant. " \
                    "Err on the side of flagging possible emergencies (recall over precision).",
            messages: [ { role: "user", content: text } ],
            json_schema: { kind: :emergency, language: language }
          )
          result.json["emergency"] == true
        end

        private

        attr_reader :gateway
      end
    end
  end
end
