FactoryBot.define do
  factory :care_plan do
    episode
    sequence(:version) { |n| n }
    active { false }
    thresholds { {} }
    cadence { {} }
  end
end
