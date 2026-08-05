class KnowledgeDoc < ApplicationRecord
  STATUSES = %w[draft in_review approved].freeze
  REQUIRED_APPROVALS = 2 # FR-N15: two-person approval

  has_many :knowledge_chunks, foreign_key: :doc_ref, inverse_of: :knowledge_doc, dependent: :destroy

  validates :title, presence: true
  validates :language, presence: true
  validates :version, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :body, presence: true

  # Records one person's approval. Returns true once the doc has 2 *distinct*
  # approvers and flips status to "approved" (idempotent: the same user
  # approving twice only counts once).
  def approve!(user)
    self.approvals = (approvals || []) + [ { "user_ref" => user.id, "at" => Time.current.iso8601 } ]
    self.status = "in_review" if status == "draft"

    distinct_approvers = approvals.map { |a| a["user_ref"] }.uniq
    newly_approved = distinct_approvers.size >= REQUIRED_APPROVALS && status != "approved"
    self.status = "approved" if distinct_approvers.size >= REQUIRED_APPROVALS
    save!
    enqueue_chunking! if newly_approved
    status == "approved"
  end

  def approved?
    status == "approved"
  end

  private

  # M7 hardening failure drill (ADR-0009 #8, "redis down"): this is the
  # only synchronous-path Sidekiq enqueue in the app (grepped `perform_async`/
  # `perform_in` across app/ to confirm). If Redis is unreachable, the
  # *approval itself* must still succeed — a doc silently stuck un-chunked
  # is recoverable (re-run `KnowledgeChunkingJob.perform_async(id)` later);
  # 500ing the whole approve request and rolling back an already-recorded
  # two-person approval is not.
  def enqueue_chunking!
    KnowledgeChunkingJob.perform_async(id)
  rescue StandardError => e
    Rails.logger.error("[KnowledgeDoc#approve!] KnowledgeChunkingJob enqueue failed (doc_id=#{id}): #{e.class}: #{e.message}")
  end
end
