# Caregiver requirement #4 (post-M7, ADR-0010): a reminder per scheduled
# medication-dose time, not just the once-daily DailyReminderJob. Follows
# that job's exact shape: same quiet-hours window, same "runs every 10 min,
# fires within a single non-overlapping 10-min window per scheduled time"
# idempotency strategy (no separate "already sent" tracking needed — the
# window width equals the cron cadence, so a given medication+time can only
# ever be `due_now?` during one run per day, same as DailyReminderJob).
#
# Payload stays as generic as `daily_reminder` (R5) — no drug name, no dose
# amount, no "medication"/"dose" wording (see Templates::BODIES["dose_reminder"]).
class DoseReminderJob
  include Sidekiq::Job

  QUIET_HOURS = DailyReminderJob::QUIET_HOURS
  WINDOW_MINUTES = DailyReminderJob::WINDOW_MINUTES

  def perform
    now = Time.current
    return if QUIET_HOURS.include?(now.hour)

    CarePlan.where(active: true).includes(:medications, episode: :caregivers).find_each do |plan|
      caregiver = plan.episode.caregivers.first
      next unless caregiver

      plan.medications.each do |medication|
        medication.schedule_times.each do |time_str|
          next unless due_now?(time_str, now)
          next if dose_resolved?(medication, now.to_date, time_str)

          Domain::Notifications::Dispatcher.send!(caregiver: caregiver, channel: "webpush", kind: "dose_reminder")
        end
      end
    end
  end

  private

  def due_now?(time_str, now)
    hour, minute = time_str.split(":").map(&:to_i)
    now.hour == hour && now.min.between?(minute, minute + WINDOW_MINUTES - 1)
  end

  def dose_resolved?(medication, date, time_str)
    MedicationDose.exists?(medication_ref: medication.id, scheduled_date: date, scheduled_time: time_str, status: %w[taken missed])
  end
end
