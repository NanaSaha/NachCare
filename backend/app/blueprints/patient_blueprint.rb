class PatientBlueprint < Blueprinter::Base
  identifier :id

  fields :pseudonym_code, :initials, :birth_year, :nyha_class, :site_ref

  # UC-25: a direction only (rising/stable/improving), never a raw score —
  # R5 explicit instruction. `nil` pre-promotion (shadow mode enforced)
  # and whenever there isn't enough score history yet to say anything.
  field :risk_trend do |patient|
    next nil unless patient.site.ai_watch_promoted?

    episode = patient.episodes.order(start_date: :desc).first
    episode ? Domain::Risk::TrendSummarizer.for_episode(episode) : nil
  end
end
