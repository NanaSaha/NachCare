FactoryBot.define do
  factory :check_in do
    episode
    caregiver
    sequence(:client_uuid) { SecureRandom.uuid }
    submitted_at { Time.current }
    effective_date { Date.current }
    weight_kg { 70.0 }
    weight_source { "manual" }
    med_status { {} }
    symptoms { {} }
    sync_state { "synced" }
  end
end
