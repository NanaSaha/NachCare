class ActivationCode < ApplicationRecord
  ROLES = %w[primary secondary].freeze

  belongs_to :episode, foreign_key: :episode_ref, inverse_of: :activation_codes

  validates :code_digest, presence: true, uniqueness: true
  validates :role, inclusion: { in: ROLES }
  validates :expires_at, presence: true

  def used?
    used_at.present?
  end

  def expired?
    expires_at < Time.current
  end
end
