class CheckInBlueprint < Blueprinter::Base
  identifier :id

  fields :client_uuid, :effective_date, :weight_kg, :symptoms, :med_status, :submitted_at

  field :superseded do |check_in|
    check_in.superseded_by.present?
  end
end
