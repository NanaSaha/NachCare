FactoryBot.define do
  factory :assistant_conversation do
    episode
    caregiver
    language { "en" }
    started_at { Time.current }
  end
end
