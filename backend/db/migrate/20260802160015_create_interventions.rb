class CreateInterventions < ActiveRecord::Migration[7.2]
  def change
    create_table :interventions do |t|
      t.bigint :flag_ref, null: false
      t.bigint :actor_ref, null: false
      t.string :outcome
      t.text :note_ai
      t.text :note_final
      t.decimal :ai_accept_ratio, precision: 4, scale: 3

      t.timestamps
    end

    add_foreign_key :interventions, :flags, column: :flag_ref
    add_foreign_key :interventions, :users, column: :actor_ref
    add_index :interventions, :flag_ref
    add_index :interventions, :actor_ref
  end
end
