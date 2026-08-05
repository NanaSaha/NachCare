class AuditEvent < ApplicationRecord
  ACTOR_TYPES = %w[user caregiver system ai].freeze

  # R6: append-only. The DB trigger (migration 20260802160022) is the real
  # enforcement — it fires even against a raw SQL client — this is defense
  # in depth at the app layer so the failure surfaces as a Ruby exception
  # before ever reaching the DB in the common case.
  before_update { raise ActiveRecord::ReadOnlyRecord, "audit_events is append-only: UPDATE is not permitted" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "audit_events is append-only: DELETE is not permitted" }

  validates :actor_type, inclusion: { in: ACTOR_TYPES }
  validates :action, :entity_type, :entity_ref, :payload_sha256, presence: true
end
