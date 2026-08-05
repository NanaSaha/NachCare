# Weekly pilot-metrics digest (Section 8/M7, ADR-0009 #5) — a staff-facing
# operational email, NOT the caregiver Domain::Notifications::EmailAdapter
# path (that one exists to minimize payload content per R5; this one exists
# to inform site_admin/physician staff). Aggregate counts/rates only, per
# Domain::Analytics::PilotMetrics's own R5-safe output — never a patient or
# caregiver identifier.
class DigestMailer < ApplicationMailer
  def weekly_digest(user:, site:, metrics:)
    @site = site
    @metrics = metrics
    mail(to: user.email, subject: "NachCare AI — weekly pilot digest for #{site.name}")
  end
end
