class EpisodePolicy < ApplicationPolicy
  ENROLLING_ROLES = PatientPolicy::ENROLLING_ROLES

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

  # Day-90 graduation (ADR-0008 #4): same role gate as FlagPolicy#update? —
  # every managing role except ward_nurse (ADR-0003: discharge-side only).
  def graduate?
    user.present? && user.role != "ward_nurse" && ENROLLING_ROLES.include?(user.role) && (sysadmin? || same_site?)
  end

  # No destroy — see PatientPolicy.

  private

  def staff_at_site?
    user.present? && (sysadmin? || same_site?)
  end

  # Episode has no site_ref column of its own — it belongs to a site via
  # patient_ref -> patients.site_ref.
  def same_site?
    user && record&.patient && user.site_ref == record.patient.site_ref
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      return scope.all if sysadmin?

      scope.joins(:patient).where(patients: { site_ref: user&.site_ref })
    end
  end
end
