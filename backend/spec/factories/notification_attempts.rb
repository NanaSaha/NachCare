FactoryBot.define do
  factory :notification_attempt do
    caregiver
    kind { "daily_reminder" }
    channel { "webpush" }
    state { "sent" }
  end
end
