FactoryBot.define do
  factory :ruleset do
    sequence(:version) { |n| "test-#{n}" }
    status { "draft" }
    body do
      {
        "version" => version,
        "rules" => [
          {
            "id" => "R-1", "key" => "test_rule", "severity" => "red",
            "condition" => { "type" => "symptom_toggle", "symptom_key" => "test_symptom" }
          }
        ]
      }
    end
  end
end
