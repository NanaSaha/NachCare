module Domain
  module Ai
    module Guardrails
      # Section 6 #4 stage 4: second LLM pass over the drafted answer —
      # "does this contain medication/dosage/diagnosis advice or
      # contradict the care plan? YES/NO + span." A positive here discards
      # the drafted answer and routes, even though CategoryRouter already
      # said `in_scope` — defense in depth against the answer-generation
      # step itself drifting into disallowed territory.
      class PostChecker
        def self.check(drafted_answer:, gateway:)
          new(gateway:).check(drafted_answer:)
        end

        def initialize(gateway:)
          @gateway = gateway
        end

        def check(drafted_answer:)
          result = gateway.call!(
            task: :assistant,
            system: "Does the following drafted answer contain medication/dosage/diagnosis/prognosis advice, " \
                    "or contradict a care plan? Respond with flagged (boolean) and span (the offending text, or null).",
            messages: [ { role: "user", content: drafted_answer } ],
            json_schema: { kind: :post_check }
          )
          { "flagged" => result.json["flagged"] == true, "span" => result.json["span"] }
        end

        private

        attr_reader :gateway
      end
    end
  end
end
