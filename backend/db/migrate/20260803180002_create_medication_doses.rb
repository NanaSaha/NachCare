# Product-owner request (post-M7): per-scheduled-dose recording (ADR-0010).
# `medications.schedule` (Section 5, existed unused since M0) now holds
# `{"times" => ["08:00", "20:00"], "instructions" => "..."}`. Each entry in
# `times` is a schedule *slot*, not a row here — rows are created lazily,
# only when a caregiver actually marks a specific date+time dose taken or
# missed (never pre-populated by a job), same "derive, don't pre-populate"
# posture as ADR-0008 #2's Learn-unlock computation.
class CreateMedicationDoses < ActiveRecord::Migration[7.2]
  def change
    create_table :medication_doses do |t|
      t.bigint :medication_ref, null: false
      t.uuid :caregiver_ref, null: false
      t.date :scheduled_date, null: false
      t.time :scheduled_time, null: false
      t.datetime :taken_at
      t.string :status, null: false, default: "pending"

      t.timestamps
    end

    add_foreign_key :medication_doses, :medications, column: :medication_ref
    add_foreign_key :medication_doses, :caregivers, column: :caregiver_ref
    add_index :medication_doses, :medication_ref
    add_index :medication_doses, :caregiver_ref
    # One row per scheduled slot per day — the lazy find_or_initialize_by
    # key the caregiver-facing controller upserts against.
    add_index :medication_doses, [ :medication_ref, :scheduled_date, :scheduled_time ],
      unique: true, name: "index_medication_doses_on_med_date_time"

    add_check_constraint :medication_doses, "status IN ('pending','taken','missed')", name: "medication_doses_status_check"
  end
end
