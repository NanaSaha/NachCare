# UC-21: gate viewing is open to any staff member at the site (the honest
# numbers, whatever they are, are not sensitive to show) — but making the
# actual promotion decision (including the dev/demo override) is
# MD/ADM-gated. `record` here is a Site, same convention as SitePolicy.
#
# Modeled as a single authorized approver from the MD/ADM roles (not a
# two-person dual-sign-off workflow, which would need its own
# pending-approval state) — a scoped-down piece of UC-21 step 3's "MD +
# ADM approve," noted in ADR-0012.
class RiskModelPromotionPolicy < ApplicationPolicy
  PROMOTING_ROLES = %w[physician site_admin sysadmin].freeze

  def show?
    staff_at_site?
  end

  def promote?
    user.present? && PROMOTING_ROLES.include?(user.role) && (sysadmin? || same_site?)
  end

  private

  def staff_at_site?
    user.present? && (sysadmin? || same_site?)
  end

  def same_site?
    user && record && user.site_ref == record.id
  end
end
