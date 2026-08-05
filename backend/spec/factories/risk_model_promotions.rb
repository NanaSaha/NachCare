FactoryBot.define do
  factory :risk_model_promotion do
    site
    association :decider, factory: :user
    sequence(:version) { |n| n }
    gate_results { {} }
    gates_met { false }
    override { false }
    promoted { false }
  end
end
