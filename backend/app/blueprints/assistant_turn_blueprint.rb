class AssistantTurnBlueprint < Blueprinter::Base
  identifier :id

  fields :role, :content, :retrieval_refs, :routed, :emergency_detected, :created_at

  field :routed_flag_id do |turn|
    turn.routed_flag_id
  end
end
