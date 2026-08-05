FactoryBot.define do
  factory :episode do
    patient
    start_date { Date.current }
    status { "active" }
  end
end
