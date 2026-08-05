FactoryBot.define do
  factory :assistant_turn do
    assistant_conversation
    role { "caregiver" }
    content { "hello" }
    retrieval_refs { [] }
    guardrail_verdicts { {} }
    routed { false }
    emergency_detected { false }
  end
end
