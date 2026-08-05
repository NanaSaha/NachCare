# UC-21: one audited row per gate-evaluation/promotion decision, per site.
# A site is "promoted" (AI WATCH live) iff `RiskModelPromotion.promoted_for?(site)`
# is true — i.e. at least one row for that site has `promoted: true`.
class RiskModelPromotion < ApplicationRecord
  belongs_to :site, foreign_key: :site_ref, inverse_of: false
  belongs_to :decider, class_name: "User", foreign_key: :decided_by, inverse_of: false

  validates :version, presence: true, uniqueness: { scope: :site_ref }

  def self.promoted_for?(site)
    where(site_ref: site.id, promoted: true).exists?
  end

  def self.latest_for(site)
    where(site_ref: site.id).order(version: :desc).first
  end

  def self.next_version_for(site)
    (where(site_ref: site.id).maximum(:version) || 0) + 1
  end
end
