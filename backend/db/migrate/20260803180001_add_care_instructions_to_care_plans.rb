# Product-owner request (post-M7): nurse-authored free-text "how to care
# for the patient at home" instructions, structured text authored directly
# in the cockpit (ADR-0010) — not a file upload, no OCR/PDF pipeline.
# Same versioning contract as the existing `diet_rules`/`thresholds`
# columns: a new care_plans row per edit, never mutated in place.
class AddCareInstructionsToCarePlans < ActiveRecord::Migration[7.2]
  def change
    add_column :care_plans, :care_instructions, :text
  end
end
