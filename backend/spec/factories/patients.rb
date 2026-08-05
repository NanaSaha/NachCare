FactoryBot.define do
  factory :patient do
    site
    sequence(:pseudonym_code) { |n| "PT-#{n.to_s.rjust(6, '0')}" }
    initials { "I.M." }
    birth_year { 1950 }
    nyha_class { "II" }
  end
end
