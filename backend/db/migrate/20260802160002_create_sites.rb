class CreateSites < ActiveRecord::Migration[7.2]
  def change
    create_table :sites do |t|
      t.string :name, null: false
      t.string :timezone, null: false, default: "Europe/Berlin"
      t.integer :sla_red_minutes, null: false, default: 30
      t.integer :sla_yellow_minutes, null: false, default: 240
      t.jsonb :config, null: false, default: {}

      t.timestamps
    end
  end
end
