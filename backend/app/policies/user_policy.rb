class UserPolicy < ApplicationPolicy
  def index?
    sysadmin? || user&.role == "site_admin"
  end

  def show?
    sysadmin? || same_site_admin? || self?
  end

  def create?
    return false unless user

    return true if sysadmin?

    # site_admin may create any role except sysadmin, and only at their own site
    user.role == "site_admin" && record.role != "sysadmin" && same_site?
  end

  def update?
    return false unless user

    return true if sysadmin?
    return true if self? # a user may always edit their own profile

    user.role == "site_admin" && record.role != "sysadmin" && same_site?
  end

  # No destroy: staff accounts are deactivated (out of scope for M1 — no
  # `active` column yet), never hard-deleted — they're audit actors
  # (Domain::Audit::Recorder actor_ref) and interventions.actor_ref.

  private

  def self?
    user && record && user.id == record.id
  end

  def same_site_admin?
    user&.role == "site_admin" && same_site?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if sysadmin?
      return scope.where(site_ref: user.site_ref) if user&.role == "site_admin"

      scope.where(id: user&.id)
    end
  end
end
