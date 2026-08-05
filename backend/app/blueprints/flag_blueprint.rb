class FlagBlueprint < Blueprinter::Base
  identifier :id

  fields :episode_ref, :severity, :subtype, :state, :sla_deadline_at, :breach,
    :opened_at, :first_action_at, :resolved_at, :outcome, :watch_expires_at

  field :patient do |flag|
    patient = flag.episode.patient
    { pseudonym_code: patient.pseudonym_code, initials: patient.initials, nyha_class: patient.nyha_class }
  end
end
