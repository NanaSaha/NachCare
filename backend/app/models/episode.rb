class Episode < ApplicationRecord
  STATUSES = %w[active graduated withdrawn deceased].freeze

  belongs_to :patient, foreign_key: :patient_ref, inverse_of: :episodes
  has_many :caregivers, foreign_key: :episode_ref, inverse_of: :episode
  has_many :activation_codes, foreign_key: :episode_ref, inverse_of: :episode
  has_many :care_plans, foreign_key: :episode_ref, inverse_of: :episode
  has_many :check_ins, foreign_key: :episode_ref, inverse_of: :episode
  has_many :evaluations, foreign_key: :episode_ref, inverse_of: :episode
  has_many :flags, foreign_key: :episode_ref, inverse_of: :episode
  has_many :risk_scores, foreign_key: :episode_ref, inverse_of: false
  has_many :cadence_proposals, foreign_key: :episode_ref, inverse_of: false
  has_many :messages, foreign_key: :episode_ref, inverse_of: :episode
  has_many :assistant_conversations, foreign_key: :episode_ref, inverse_of: :episode

  validates :start_date, presence: true
  validates :status, inclusion: { in: STATUSES }
end
