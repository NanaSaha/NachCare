class CarePlan < ApplicationRecord
  belongs_to :episode, foreign_key: :episode_ref, inverse_of: :care_plans
  belongs_to :approver, class_name: "User", foreign_key: :approved_by, inverse_of: false, optional: true
  has_many :medications, foreign_key: :care_plan_ref, inverse_of: :care_plan

  validates :version, presence: true, uniqueness: { scope: :episode_ref }
end
