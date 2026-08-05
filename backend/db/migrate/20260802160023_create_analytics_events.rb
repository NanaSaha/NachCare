class CreateAnalyticsEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :analytics_events do |t|
      t.string :episode_pseudonym_ref, null: false
      t.string :name, null: false
      t.jsonb :properties, null: false, default: {}
      t.datetime :occurred_at, null: false

      t.datetime :created_at, null: false
    end

    add_index :analytics_events, :episode_pseudonym_ref
    add_index :analytics_events, :name
    add_index :analytics_events, :occurred_at
  end
end
