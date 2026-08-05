class CreateContentItems < ActiveRecord::Migration[7.2]
  def change
    create_table :content_items do |t|
      t.string :kind, null: false
      t.integer :week_no, null: false
      t.string :status, null: false, default: "draft"
      t.jsonb :language_variants, null: false, default: {}
      t.jsonb :approvals, null: false, default: []

      t.timestamps
    end

    add_index :content_items, [ :kind, :week_no ]

    add_check_constraint :content_items, "status IN ('draft','in_review','approved')", name: "content_items_status_check"
  end
end
