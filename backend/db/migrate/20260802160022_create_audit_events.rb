class CreateAuditEvents < ActiveRecord::Migration[7.2]
  def change
    create_table :audit_events do |t|
      t.string :actor_type, null: false
      t.string :actor_ref
      t.string :action, null: false
      t.string :entity_type, null: false
      t.string :entity_ref, null: false
      t.string :payload_sha256, null: false
      t.jsonb :payload, null: false, default: {}

      t.datetime :created_at, null: false
    end

    add_index :audit_events, [ :entity_type, :entity_ref ]
    add_index :audit_events, [ :actor_type, :actor_ref ]
    add_index :audit_events, :created_at

    add_check_constraint :audit_events, "actor_type IN ('user','caregiver','system','ai')", name: "audit_events_actor_type_check"

    # R6 — append-only audit spine: no clinical row is ever hard-deleted or
    # updated in place. Enforced at the DB level (not just app-level) so it
    # holds even against a raw SQL client or a future ORM change.
    reversible do |dir|
      dir.up do
        execute <<~SQL
          CREATE OR REPLACE FUNCTION audit_events_block_mutation()
          RETURNS trigger AS $$
          BEGIN
            RAISE EXCEPTION 'audit_events is append-only: % is not permitted', TG_OP;
          END;
          $$ LANGUAGE plpgsql;
        SQL

        execute <<~SQL
          CREATE TRIGGER audit_events_no_update
          BEFORE UPDATE ON audit_events
          FOR EACH ROW EXECUTE FUNCTION audit_events_block_mutation();
        SQL

        execute <<~SQL
          CREATE TRIGGER audit_events_no_delete
          BEFORE DELETE ON audit_events
          FOR EACH ROW EXECUTE FUNCTION audit_events_block_mutation();
        SQL
      end

      dir.down do
        execute "DROP TRIGGER IF EXISTS audit_events_no_update ON audit_events;"
        execute "DROP TRIGGER IF EXISTS audit_events_no_delete ON audit_events;"
        execute "DROP FUNCTION IF EXISTS audit_events_block_mutation();"
      end
    end
  end
end
