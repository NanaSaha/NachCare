FactoryBot.define do
  factory :risk_score do
    episode
    check_in
    score { 0.1 }
    components { {} }
    rules_severity { "green" }
    alert_eligible { false }
  end
end
