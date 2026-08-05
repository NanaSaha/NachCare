# FR-N15 (knowledge-base CMS, two-person approval). Follows the same
# managing-roles shape as FlagPolicy/CarePlanPolicy (ADR-0003) — any site
# staff can read, the same "managing" roles can author/approve. No
# per-site scoping (knowledge docs aren't site-specific, unlike patients).
class KnowledgeDocPolicy < ApplicationPolicy
  MANAGING_ROLES = %w[ward_nurse nurse physician site_admin sysadmin].freeze

  def index? = user.present?
  def show? = user.present?
  def create? = user.present? && MANAGING_ROLES.include?(user.role)
  def update? = create?

  # Two-person approval (FR-N15): approving is a stricter action than
  # authoring — narrowed to the same roles CarePlanPolicy trusts with
  # clinically-consequential content (nurse/physician/site_admin/sysadmin),
  # not ward_nurse (ADR-0003: ward_nurse is discharge-side only).
  def approve?
    user.present? && user.role != "ward_nurse" && MANAGING_ROLES.include?(user.role)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
