class AiCall < ApplicationRecord
  TASKS = %w[assistant brief triage callnote report translate embedding].freeze
  STATUSES = %w[success degraded failed].freeze

  belongs_to :episode, foreign_key: :episode_ref, inverse_of: false, optional: true
  belongs_to :caregiver, foreign_key: :caregiver_ref, inverse_of: false, optional: true
  belongs_to :assistant_conversation, foreign_key: :conversation_ref, inverse_of: false, optional: true

  # AI-11: caregiver deletion purges any AI content tied to them. Not
  # `encrypts` via Active Record encryption on this column alone — the
  # purge itself (nilling `content`) is the deletion mechanism; encryption
  # is defense in depth so the row is unreadable even before a purge runs.
  encrypts :content

  validates :task, inclusion: { in: TASKS }
  validates :status, inclusion: { in: STATUSES }
  validates :provider, presence: true
  validates :prompt_sha256, presence: true

  # AI-11: purge all AI-call content tied to a caregiver (e.g. on caregiver
  # deletion/right-to-erasure). Keeps the row (audit-adjacent: task,
  # provider, latency, guardrail verdicts) but nils the encrypted content.
  def self.purge_for_caregiver!(caregiver)
    where(caregiver_ref: caregiver.id).update_all(content: nil)
  end
end
