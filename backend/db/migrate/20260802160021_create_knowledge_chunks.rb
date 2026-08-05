class CreateKnowledgeChunks < ActiveRecord::Migration[7.2]
  def change
    create_table :knowledge_chunks do |t|
      t.bigint :doc_ref, null: false
      t.text :chunk, null: false
      # Raw PG type string: the `pgvector` gem here is the low-level pg
      # encoder (used later by the `neighbor` gem for ActiveRecord nearest-
      # neighbor queries in M5); it doesn't patch the migration DSL itself.
      t.column :embedding, "vector(1024)"

      t.timestamps
    end

    add_foreign_key :knowledge_chunks, :knowledge_docs, column: :doc_ref
    add_index :knowledge_chunks, :doc_ref
  end
end
