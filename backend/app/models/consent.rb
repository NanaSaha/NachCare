class Consent < ApplicationRecord
  KINDS = %w[a b c d].freeze

  belongs_to :caregiver, foreign_key: :caregiver_ref, inverse_of: :consents

  validates :kind, inclusion: { in: KINDS }
  validates :version, presence: true
  validates :granted, inclusion: { in: [ true, false ] }
  validates :timestamp, presence: true
end
