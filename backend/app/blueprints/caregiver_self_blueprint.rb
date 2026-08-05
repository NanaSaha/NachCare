# The caregiver's own view of their profile — never exposes
# device_token_digest or pin_digest (write-only from the client's
# perspective), and contact is encrypted PII the caregiver already knows.
class CaregiverSelfBlueprint < Blueprinter::Base
  identifier :id

  fields :display_name, :relationship, :language, :notification_time, :episode_ref

  field :pin_set do |caregiver|
    caregiver.pin_digest.present?
  end

  # Section 8/M5: consent-(c)-declined behavior — the assistant entry
  # point is fully hidden, not just disabled, when consent (c) isn't
  # granted or the AI_ASSISTANT_ENABLED kill switch is off.
  field :assistant_available do |caregiver|
    ENV.fetch("AI_ASSISTANT_ENABLED", "true") != "false" && caregiver.consents.where(kind: "c", granted: true).exists?
  end
end
