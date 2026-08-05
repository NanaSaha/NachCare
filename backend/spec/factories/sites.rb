FactoryBot.define do
  factory :site do
    sequence(:name) { |n| "Demo Site #{n}" }
    timezone { "Europe/Berlin" }
  end
end
