FactoryBot.define do
  factory :medication do
    care_plan
    sequence(:name) { |n| "Test Medication #{n}" }
    critical { false }
    schedule { {} }
  end
end
