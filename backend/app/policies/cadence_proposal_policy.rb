# UC-24: same managing-role gate as care-plan/flag actions — any managing
# role (not just physician) can approve/dismiss a cadence proposal, since
# it's an operational scheduling change, not a clinical-threshold change
# (FR-N8's physician-only gate is specifically for `care_plans.thresholds`).
class CadenceProposalPolicy < ApplicationPolicy
  MANAGING_ROLES = %w[ward_nurse nurse physician site_admin sysadmin].freeze

  def index?
    staff_at_site?
  end

  def decide?
    user.present? && user.role != "ward_nurse" && MANAGING_ROLES.include?(user.role) && (sysadmin? || same_site?)
  end

  private

  def staff_at_site?
    user.present? && (sysadmin? || same_site?)
  end

  def same_site?
    user && record&.episode&.patient && user.site_ref == record.episode.patient.site_ref
  end
end
