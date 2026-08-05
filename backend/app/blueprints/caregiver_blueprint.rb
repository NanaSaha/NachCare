# Staff-facing view: never exposes contact (encrypted PII), pin_digest,
# device_token_digest, or push_subscription.
class CaregiverBlueprint < Blueprinter::Base
  identifier :id

  fields :display_name, :relationship, :language, :episode_ref

  field :activated do |caregiver|
    caregiver.activated?
  end
end
