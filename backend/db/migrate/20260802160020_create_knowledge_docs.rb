class CreateKnowledgeDocs < ActiveRecord::Migration[7.2]
  def change
    create_table :knowledge_docs do |t|
      t.string :title, null: false
      t.string :language, null: false
      t.integer :version, null: false, default: 1
      t.string :status, null: false, default: "draft"
      t.text :body, null: false

      t.timestamps
    end

    add_index :knowledge_docs, [ :title, :language, :version ], unique: true

    add_check_constraint :knowledge_docs, "status IN ('draft','in_review','approved')", name: "knowledge_docs_status_check"
  end
end
