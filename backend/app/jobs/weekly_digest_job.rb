# Weekly digest (Section 8/M7, ADR-0009 #5) — the "digest" job the M4-era
# sidekiq-cron Gemfile comment already anticipated. Runs once a week
# (schedule.yml), computes Domain::Analytics::PilotMetrics for the trailing
# 7 days per site, and mails every site_admin/physician at that site
# (DigestMailer, not the caregiver notification pipeline — ADR-0009 #5).
class WeeklyDigestJob
  include Sidekiq::Job

  DIGEST_ROLES = %w[site_admin physician].freeze
  WINDOW_DAYS = 7

  def perform
    Site.find_each do |site|
      recipients = User.where(site_ref: site.id, role: DIGEST_ROLES)
      next if recipients.none?

      metrics = Domain::Analytics::PilotMetrics.compute(site: site, from: WINDOW_DAYS.days.ago.to_date, to: Date.current).to_h

      recipients.find_each do |user|
        # #deliver_now, not #deliver_later: this job is already the async
        # unit of work (Sidekiq) — a second ActiveJob hop would only add
        # indirection and a queue_adapter dependency this app hasn't
        # otherwise needed to configure.
        DigestMailer.weekly_digest(user: user, site: site, metrics: metrics).deliver_now
      end
    end
  end
end
