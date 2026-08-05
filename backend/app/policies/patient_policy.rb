class PatientPolicy < ApplicationPolicy
  ENROLLING_ROLES = %w[ward_nurse nurse physician site_admin sysadmin].freeze

  def index?
    staff_at_site?
  end

  def show?
    staff_at_site?
  end

  def create?
    user && ENROLLING_ROLES.include?(user.role) && (sysadmin? || same_site?)
  end

  def update?
    create?
  end

  # No destroy: R6 spirit — a patient/episode is withdrawn (episodes.status),
  # never deleted, so history stays reconstructable.

  private

  def staff_at_site?
    user.present? && (sysadmin? || same_site?)
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if sysadmin?

      scope.where(site_ref: user&.site_ref)
    end
  end
end
