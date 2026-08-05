class EpisodeBlueprint < Blueprinter::Base
  identifier :id

  fields :patient_ref, :start_date, :status
end
