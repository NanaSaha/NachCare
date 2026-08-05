class ContentItemBlueprint < Blueprinter::Base
  identifier :id

  fields :kind, :week_no, :status, :approvals, :created_at, :updated_at
end
