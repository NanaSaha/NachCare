class Medication < ApplicationRecord
  # ADR-0010: schedule shape is `{"times" => ["08:00", "20:00"], "instructions" => "..."}`.
  TIME_FORMAT = /\A([01]\d|2[0-3]):[0-5]\d\z/

  belongs_to :care_plan, foreign_key: :care_plan_ref, inverse_of: :medications
  belongs_to :drug, foreign_key: :drug_ref, inverse_of: false, optional: true
  has_many :medication_doses, foreign_key: :medication_ref, inverse_of: :medication

  validates :name, presence: true
  validate :schedule_shape_valid

  # Scheduled dose times, normalized/sorted/deduped, for reminder + care-
  # tasks computation (R10: schedule-timing logic, kept small and TDD'd).
  # Deduped because nothing on the editing side stops a nurse from adding
  # the same time twice (e.g. two "08:00" slots) — without this, a
  # duplicate produces two identical care-task rows sharing one
  # medication+time key (Angular duplicate-track-key warning on the
  # caregiver's care-tasks list) and two indistinguishable dose reminders.
  def schedule_times
    Array(schedule["times"]).select { |t| t.is_a?(String) && t.match?(TIME_FORMAT) }.uniq.sort
  end

  def schedule_instructions
    schedule["instructions"].presence
  end

  private

  def schedule_shape_valid
    return if schedule.blank?

    unless schedule.is_a?(Hash)
      errors.add(:schedule, "must be a JSON object")
      return
    end

    times = schedule["times"]
    return if times.nil?

    unless times.is_a?(Array) && times.all? { |t| t.is_a?(String) && t.match?(TIME_FORMAT) }
      errors.add(:schedule, "times must be an array of HH:MM strings")
    end
  end
end
