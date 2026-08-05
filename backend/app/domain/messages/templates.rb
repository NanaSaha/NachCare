module Domain
  module Messages
    # R1: only the 3 action-copy strings the playbook gives verbatim
    # (Section 7) may be reused as-is; anything else clinical-instruction-
    # shaped is `PLACEHOLDER_CLINICAL`, matching the same markers already
    # used in config/rulesets/ruleset_v0_1.json's action_templates — see
    # docs/OPEN_CLINICAL_ITEMS.md. The two operational templates (reminder/
    # thank-you) are ordinary app copy, not clinical content, and are
    # authored directly like the notification bodies in
    # Domain::Notifications::Templates.
    module Templates
      BANK = {
        "checkin_reminder" => "Please remember to complete today's check-in when you have a moment.",
        "thank_you" => "Thank you for your check-in today.",
        "low_salt_day" => "Low-salt day",
        "track_fluids_1_5l" => "Track fluids: 1.5 L",
        "elevate_legs_photo" => "Elevate legs + photo",
        "call_nurse_now" => "[PLACEHOLDER_CLINICAL: call-nurse-now copy]"
      }.freeze
    end
  end
end
