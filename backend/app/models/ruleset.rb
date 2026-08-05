class Ruleset < ApplicationRecord
  STATUSES = %w[draft shadow active retired].freeze

  belongs_to :approver, class_name: "User", foreign_key: :approved_by, optional: true, inverse_of: false

  validates :version, presence: true, uniqueness: true
  validates :status, inclusion: { in: STATUSES }

  def self.active
    find_by(status: "active")
  end

  def self.shadow
    where(status: "shadow")
  end

  def to_domain
    Domain::Escalation::Ruleset.new(body)
  end
end
