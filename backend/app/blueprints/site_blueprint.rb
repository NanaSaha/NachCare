class SiteBlueprint < Blueprinter::Base
  identifier :id

  fields :name, :timezone, :sla_red_minutes, :sla_yellow_minutes, :created_at, :updated_at
end
