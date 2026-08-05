module Domain
  module Ai
    # R5: patients are referenced by pseudonym in every LLM context —
    # "PATIENT_{uuid8}" (playbook Section 6 #2), never name/initials/DOB.
    # `patient.pseudonym_code` (Section 5) is a separate, human-facing
    # pseudonym used in the cockpit UI — this is a distinct, AI-context-only
    # form so the two can't be confused/cross-referenced from a prompt log.
    class Pseudonymizer
      def self.for_patient(patient)
        "PATIENT_#{patient.id.to_s.delete('-')[0, 8]}"
      end
    end
  end
end
