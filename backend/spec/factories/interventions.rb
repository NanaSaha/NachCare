FactoryBot.define do
  factory :intervention do
    flag
    association :actor, factory: :user
    outcome { "acknowledged" }
    note_final { "Called caregiver, advised to monitor." }
  end
end
