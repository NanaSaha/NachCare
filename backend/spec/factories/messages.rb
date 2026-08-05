FactoryBot.define do
  factory :message do
    episode
    sender { "nurse" }
    body_source { "Please remember to complete today's check-in when you have a moment." }
    language { "en" }
  end
end
