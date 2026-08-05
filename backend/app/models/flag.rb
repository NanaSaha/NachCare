class Flag < ApplicationRecord
  SEVERITIES = %w[green yellow red].freeze
  # ai_watch (UC-23): the predictive "AI WATCH" class, only ever created
  # post-promotion (Domain::Risk::WatchFlagger). Always yellow-rank in
  # spirit but visually distinct (AI-purple, never coral/amber) and never
  # SLA-pressured — see Domain::Flags::Sla, which returns nil for it.
  SUBTYPES = %w[clinical adherence manual ai_watch].freeze
  STATES = %w[open in_progress resolved].freeze

  belongs_to :episode, foreign_key: :episode_ref, inverse_of: :flags
  has_many :interventions, foreign_key: :flag_ref, inverse_of: :flag
  has_many :notification_attempts, foreign_key: :flag_ref, inverse_of: :flag

  validates :severity, inclusion: { in: SEVERITIES }
  validates :subtype, inclusion: { in: SUBTYPES }
  validates :state, inclusion: { in: STATES }
  validates :opened_at, presence: true

  def open_or_in_progress?
    %w[open in_progress].include?(state)
  end
end
