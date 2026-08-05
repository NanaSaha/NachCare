FactoryBot.define do
  factory :caregiver do
    episode
    display_name { "Sabine" }
    relationship { "daughter" }
    language { "en" }
  end
end
