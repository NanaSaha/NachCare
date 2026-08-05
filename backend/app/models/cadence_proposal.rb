# UC-24: a proposal to taper or densify check-in cadence, computed by
# Domain::Risk::CadenceAdvisor from a promoted site's risk trend. Only
# becomes real (a new CarePlan version) once a nurse approves it —
# Domain::Risk::CadenceAdvisor#approve!.
class CadenceProposal < ApplicationRecord
  DIRECTIONS = %w[taper densify].freeze
  STATUSES = %w[pending approved dismissed].freeze

  belongs_to :episode, foreign_key: :episode_ref, inverse_of: false
  belongs_to :decider, class_name: "User", foreign_key: :decided_by, inverse_of: false, optional: true

  validates :direction, inclusion: { in: DIRECTIONS }
  validates :status, inclusion: { in: STATUSES }
end
