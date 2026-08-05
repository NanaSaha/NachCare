# Scheduled daily reminder (Section 8/M4), honoring each caregiver's own
# notification_time and a quiet-hours window. Runs every 10 minutes
# (schedule.yml) and fires once per caregiver per day, in whichever 10-min
# window contains their notification_time.
#
# Quiet hours (22:00-07:00 server time) are an operational default, not a
# clinical one — no SRS content backs the exact bounds, but "don't push at
# 3am" doesn't need clinical sign-off either. Revisit if a real per-site/
# per-caregiver quiet-hours requirement shows up.
class DailyReminderJob
  include Sidekiq::Job

  QUIET_HOURS = ((22..23).to_a + (0..6).to_a).freeze
  WINDOW_MINUTES = 10

  def perform
    now = Time.current
    return if QUIET_HOURS.include?(now.hour)

    Caregiver.where.not(notification_time: nil).find_each do |caregiver|
      next unless due_now?(caregiver.notification_time, now)
      next if checked_in_today?(caregiver)

      Domain::Notifications::Dispatcher.send!(caregiver: caregiver, channel: "webpush", kind: "daily_reminder")
    end
  end

  private

  def due_now?(notification_time, now)
    now.hour == notification_time.hour && now.min.between?(notification_time.min, notification_time.min + WINDOW_MINUTES - 1)
  end

  def checked_in_today?(caregiver)
    caregiver.episode.check_ins.exists?(effective_date: Date.current)
  end
end
