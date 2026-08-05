class MessageBlueprint < Blueprinter::Base
  identifier :id

  fields :episode_ref, :sender, :template_key, :body_source, :body_translated, :language, :created_at

  # ADR-0011: caregiver status-update media attachment (item #3).
  field :media_url do |message|
    Domain::Media::Url.for(message.media)
  end

  field :media_content_type do |message|
    message.media.attached? ? message.media.content_type : nil
  end
end
