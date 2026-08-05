FactoryBot.define do
  factory :evaluation do
    episode
    check_in { nil }
    ruleset_version { "test" }
    sequence(:inputs_sha256) { |n| Digest::SHA256.hexdigest("test-#{n}") }
    severity { "green" }
    fired_rules { [] }
    created_at { Time.current }
  end
end
