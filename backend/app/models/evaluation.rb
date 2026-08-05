class Evaluation < ApplicationRecord
  SEVERITIES = %w[green yellow red].freeze

  belongs_to :check_in, foreign_key: :check_in_ref, optional: true, inverse_of: :evaluations
  belongs_to :episode, foreign_key: :episode_ref, inverse_of: :evaluations

  validates :ruleset_version, presence: true
  validates :inputs_sha256, presence: true
  validates :severity, inclusion: { in: SEVERITIES }
end
