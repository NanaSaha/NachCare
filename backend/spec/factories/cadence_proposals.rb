FactoryBot.define do
  factory :cadence_proposal do
    episode
    direction { "taper" }
    proposed_cadence { { "times_per_week" => 3 } }
    rationale { "Stable low-risk trend." }
    status { "pending" }
  end
end
