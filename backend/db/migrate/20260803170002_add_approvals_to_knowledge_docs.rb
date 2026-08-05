# FR-N15: two-person approval before a knowledge_doc's chunks are
# eligible for retrieval. `approvals` mirrors content_items' shape (an
# array of {"user_ref" => .., "at" => ..} — distinct user_refs required)
# rather than a single approved_by/approved_at pair like care_plans, since
# two *different* people must approve, not one.
class AddApprovalsToKnowledgeDocs < ActiveRecord::Migration[7.2]
  def change
    add_column :knowledge_docs, :approvals, :jsonb, null: false, default: []
  end
end
