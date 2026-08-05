# Product-owner request (post-M7, ADR-0010): a single caregiver action
# against one scheduled dose slot ("08:00 Furosemide, taken"). Created
# lazily (find_or_initialize_by medication_ref+scheduled_date+scheduled_time)
# only when a caregiver actually acts — never pre-populated by a job, so an
# untouched dose simply has no row (the caregiver-facing controller treats
# "no row" as the virtual `pending` state).
class MedicationDose < ApplicationRecord
  STATUSES = %w[pending taken missed].freeze

  belongs_to :medication, foreign_key: :medication_ref, inverse_of: :medication_doses
  belongs_to :caregiver, foreign_key: :caregiver_ref, inverse_of: false

  validates :scheduled_date, presence: true
  validates :scheduled_time, presence: true
  validates :status, inclusion: { in: STATUSES }
end
