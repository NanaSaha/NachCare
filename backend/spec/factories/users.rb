FactoryBot.define do
  factory :user do
    site
    role { "nurse" }
    sequence(:email) { |n| "nurse#{n}@example.eu" }
    password { "correct horse battery staple" }
    password_confirmation { "correct horse battery staple" }
  end
end
