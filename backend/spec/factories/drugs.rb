FactoryBot.define do
  factory :drug do
    sequence(:name) { |n| "Test Drug #{n}" }
    category { "Other" }
  end
end
