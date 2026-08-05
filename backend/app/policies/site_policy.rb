class SitePolicy < ApplicationPolicy
  def index?
    sysadmin?
  end

  def show?
    sysadmin? || same_site?
  end

  def create?
    sysadmin?
  end

  def update?
    sysadmin? || (user&.role == "site_admin" && same_site?)
  end

  # No destroy: a site is never deleted once it has staff/patients attached.

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if sysadmin?

      scope.where(id: user&.site_ref)
    end
  end

  private

  # The record here IS the site — it has no site_ref column of its own
  # (that's what ApplicationPolicy#same_site? assumes for other resources).
  def same_site?
    user && record && user.site_ref == record.id
  end
end
