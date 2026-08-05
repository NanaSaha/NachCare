class CheckIn < ApplicationRecord
  SYNC_STATES = %w[synced pending conflict].freeze

  belongs_to :episode, foreign_key: :episode_ref, inverse_of: :check_ins
  belongs_to :caregiver, foreign_key: :caregiver_ref, inverse_of: false
  belongs_to :superseding_check_in, class_name: "CheckIn", foreign_key: :superseded_by, optional: true, inverse_of: false
  has_many :evaluations, foreign_key: :check_in_ref, inverse_of: :check_in
  # ADR-0011: caregiver photo/video attach on check-in submission.
  has_many :check_in_photos, foreign_key: :check_in_ref, inverse_of: :check_in, dependent: :destroy

  encrypts :note

  validates :client_uuid, presence: true, uniqueness: true
  validates :submitted_at, presence: true
  validates :effective_date, presence: true
  validates :weight_source, inclusion: { in: %w[manual] }
  validates :sync_state, inclusion: { in: SYNC_STATES }
end
