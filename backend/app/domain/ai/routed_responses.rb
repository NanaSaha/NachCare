module Domain
  module Ai
    # Non-clinical app copy shown to the caregiver when a message is
    # routed instead of answered. Follows the same i18n convention as the
    # rest of the backend-generated copy (Domain::Notifications::Templates,
    # Domain::Messages::Templates) and R7's EN+DE-authored /
    # TR-RU-AR-EN-fallback pattern (playbook Section 2). Not clinical
    # content (R1) — it never states a clinical fact, just "I've told the
    # care team" — so it isn't an OPEN_CLINICAL_ITEMS entry.
    module RoutedResponses
      EN = {
        "medication_or_dosage" => "That's a question for your nurse, since it depends on the care plan. I've let the care team know you asked — they'll follow up soon.",
        "diagnosis_or_prognosis" => "That's something your care team is best placed to talk through with you. I've flagged this for them.",
        "care_plan_conflict" => "That touches on the care plan, so I've passed it straight to your care team rather than guessing.",
        "out_of_scope" => "I can only help with questions about today's check-in and general caregiving guidance from the approved guide. I've let the care team know if this needs their attention."
      }.freeze

      DE = {
        "medication_or_dosage" => "[MACHINE_DRAFT] Das ist eine Frage für Ihre Pflegekraft, da es vom Pflegeplan abhängt. Ich habe das Pflegeteam informiert — es wird sich bald melden.",
        "diagnosis_or_prognosis" => "[MACHINE_DRAFT] Das bespricht Ihr Pflegeteam am besten mit Ihnen. Ich habe dies weitergeleitet.",
        "care_plan_conflict" => "[MACHINE_DRAFT] Das betrifft den Pflegeplan, daher habe ich es direkt an Ihr Pflegeteam weitergegeben.",
        "out_of_scope" => "[MACHINE_DRAFT] Ich kann nur bei Fragen zum heutigen Check-in und allgemeinen Pflegehinweisen aus dem freigegebenen Leitfaden helfen."
      }.freeze

      BY_LANGUAGE = { "en" => EN, "de" => DE }.freeze

      def self.for(category, language)
        BY_LANGUAGE.fetch(language.to_s, EN).fetch(category, EN.fetch(category))
      end
    end
  end
end
