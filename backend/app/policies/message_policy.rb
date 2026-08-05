class MessagePolicy < ApplicationPolicy
  MANAGING_ROLES = %w[ward_nurse nurse physician site_admin sysadmin].freeze

  def index?
    staff_at_site?
  end

  def create?
    user.present? && MANAGING_ROLES.include?(user.role) && (sysadmin? || same_site?)
  end

  private

  def staff_at_site?
    user.present? && (sysadmin? || same_site?)
  end

  # Message has no site_ref of its own — it belongs to a site via
  # episode_ref -> episodes.patient_ref -> patients.site_ref.
  def same_site?
    user && record&.episode&.patient && user.site_ref == record.episode.patient.site_ref
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if sysadmin?

      scope.joins(episode: :patient).where(patients: { site_ref: user&.site_ref })
    end
  end
end
