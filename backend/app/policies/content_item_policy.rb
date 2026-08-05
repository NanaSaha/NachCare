# Learn curriculum CMS (ADR-0008 #1): follows KnowledgeDocPolicy exactly —
# any site staff can read, the same managing roles author/approve. Not
# site-scoped (content_items aren't site-specific, same as knowledge_docs).
class ContentItemPolicy < ApplicationPolicy
  MANAGING_ROLES = %w[ward_nurse nurse physician site_admin sysadmin].freeze

  def index? = user.present?
  def show? = user.present?
  def create? = user.present? && MANAGING_ROLES.include?(user.role)
  def update? = create?

  def approve?
    user.present? && user.role != "ward_nurse" && MANAGING_ROLES.include?(user.role)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      scope.all
    end
  end
end
