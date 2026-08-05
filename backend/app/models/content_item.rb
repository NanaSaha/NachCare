class ContentItem < ApplicationRecord
  # Section 5 schema; kind is a content-*format* distinction (ADR-0008 #1),
  # not clinical content, so it's decided here rather than sourced from the
  # (unavailable) SRS.
  KINDS = %w[article tip video].freeze
  STATUSES = %w[draft in_review approved].freeze
  REQUIRED_APPROVALS = 2 # Mirrors KnowledgeDoc (FR-N15) two-person approval.

  validates :kind, inclusion: { in: KINDS }
  validates :week_no, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :status, inclusion: { in: STATUSES }

  # Same two-distinct-approvers contract as KnowledgeDoc#approve! (ADR-0008
  # #1: content_items follows the FR-N15 CMS shape exactly).
  def approve!(user)
    self.approvals = (approvals || []) + [ { "user_ref" => user.id, "at" => Time.current.iso8601 } ]
    self.status = "in_review" if status == "draft"

    distinct_approvers = approvals.map { |a| a["user_ref"] }.uniq
    self.status = "approved" if distinct_approvers.size >= REQUIRED_APPROVALS
    save!
    status == "approved"
  end

  def approved?
    status == "approved"
  end

  # Falls back to English if the caregiver's language has no authored
  # variant yet (ADR-0008 #1 — same fallback contract as M5's Retrieval).
  def variant_for(language)
    variants = language_variants || {}
    variants[language.to_s] || variants["en"] || {}
  end
end
