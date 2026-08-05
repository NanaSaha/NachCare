FactoryBot.define do
  factory :flag do
    episode
    evaluation_refs { [] }
    severity { "yellow" }
    subtype { "clinical" }
    state { "open" }
    opened_at { Time.current }
  end
end
