class KnowledgeDocBlueprint < Blueprinter::Base
  identifier :id

  fields :title, :language, :version, :status, :approvals, :created_at, :updated_at
end
