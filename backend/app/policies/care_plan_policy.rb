class CarePlanPolicy < ApplicationPolicy
  MANAGING_ROLES = %w[ward_nurse nurse physician site_admin sysadmin].freeze
  THRESHOLD_ROLES = %w[physician sysadmin].freeze

  def show?
    staff_at_site?
  end

  def create?
    user.present? && MANAGING_ROLES.include?(user.role) && (sysadmin? || same_site?)
  end

  # FR-N8: "physician-gated threshold bounds" — only a physician (or
  # sysadmin) may set/change care_plans.thresholds. Everyone in
  # MANAGING_ROLES can edit the rest of a care plan (diet_rules, cadence,
  # medications).
  def update_thresholds?
    user.present? && THRESHOLD_ROLES.include?(user.role) && (sysadmin? || same_site?)
  end

  private

  def staff_at_site?
    user.present? && (sysadmin? || same_site?)
  end

  def same_site?
    user && record&.episode&.patient && user.site_ref == record.episode.patient.site_ref
  end
end
