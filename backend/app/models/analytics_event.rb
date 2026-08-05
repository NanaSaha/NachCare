# Table created at M0 (Section 5), used since M6 (ADR-0008 #3) for Learn
# completion events. M7 (ADR-0009 #2) formalizes AN-1: a closed event-name
# taxonomy, enforced here. `pilot_metrics` (Domain::Analytics::PilotMetrics)
# deliberately does NOT read this table — see ADR-0009 #1 — so this
# taxonomy exists for event-level export/future consumers, not as the
# metrics source of truth.
class AnalyticsEvent < ApplicationRecord
  TAXONOMY = %w[
    checkin.submitted
    flag.opened
    flag.resolved
    episode.graduated
    episode.withdrawn
    episode.deceased
    assistant.turn.routed
    content_item.completed
    medication_dose.recorded
  ].freeze

  validates :episode_pseudonym_ref, presence: true
  validates :name, presence: true, inclusion: { in: TAXONOMY }
  validates :occurred_at, presence: true
end
