class CreateEpisodes < ActiveRecord::Migration[7.2]
  def change
    create_table :episodes do |t|
      t.uuid :patient_ref, null: false
      t.date :start_date, null: false
      t.string :status, null: false, default: "active"
      t.jsonb :milestones, null: false, default: {}

      t.timestamps
    end

    add_foreign_key :episodes, :patients, column: :patient_ref
    add_index :episodes, :patient_ref
    add_index :episodes, :status

    add_check_constraint :episodes,
      "status IN ('active','graduated','withdrawn','deceased')",
      name: "episodes_status_check"
  end
end
