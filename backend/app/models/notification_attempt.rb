class NotificationAttempt < ApplicationRecord
  KINDS = %w[daily_reminder missed_day red_escalation message dose_reminder].freeze
  CHANNELS = %w[webpush sms email].freeze
  STATES = %w[sent confirmed failed].freeze

  belongs_to :caregiver, foreign_key: :caregiver_ref, inverse_of: false
  belongs_to :flag, foreign_key: :flag_ref, optional: true, inverse_of: false

  validates :kind, inclusion: { in: KINDS }
  validates :channel, inclusion: { in: CHANNELS }
  validates :state, inclusion: { in: STATES }
end
