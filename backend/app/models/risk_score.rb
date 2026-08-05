# UC-05: one row per check-in, written by Domain::Risk::Scorer in shadow
# mode alongside (never inside) Domain::Escalation::Processor. See
# docs/adr/0012-shadow-risk-scoring-and-promotion.md.
class RiskScore < ApplicationRecord
  RULES_SEVERITIES = %w[green yellow red].freeze
  # UC-23 step 7 / UC-21 step 2: what eventually happened downstream of
  # this trajectory, backfilled by Domain::Risk::OutcomeLinker once known.
  OUTCOMES = %w[flag_yellow flag_red resolved_uneventful no_flag].freeze

  belongs_to :episode, foreign_key: :episode_ref, inverse_of: false
  belongs_to :check_in, foreign_key: :check_in_ref, inverse_of: false

  validates :score, presence: true, numericality: { in: 0..1 }
  validates :rules_severity, inclusion: { in: RULES_SEVERITIES }
  validates :outcome, inclusion: { in: OUTCOMES }, allow_nil: true
end
