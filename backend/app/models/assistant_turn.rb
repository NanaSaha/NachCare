class AssistantTurn < ApplicationRecord
  ROLES = %w[caregiver assistant].freeze

  belongs_to :assistant_conversation, foreign_key: :conversation_ref, inverse_of: :assistant_turns

  # R5: turn content can include free text the caregiver typed (which may
  # contain PHI-adjacent detail) — encrypted at rest like check_ins.note.
  encrypts :content

  validates :role, inclusion: { in: ROLES }

  def routed_flag_id
    guardrail_verdicts["routed_flag_id"]
  end
end
