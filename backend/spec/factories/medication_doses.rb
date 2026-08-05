FactoryBot.define do
  factory :medication_dose do
    medication
    caregiver
    scheduled_date { Date.current }
    scheduled_time { "08:00" }
    status { "pending" }
  end
end
