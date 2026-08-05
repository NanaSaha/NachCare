class Intervention < ApplicationRecord
  belongs_to :flag, foreign_key: :flag_ref, inverse_of: :interventions
  belongs_to :actor, class_name: "User", foreign_key: :actor_ref, inverse_of: false

  validates :actor_ref, presence: true
end
