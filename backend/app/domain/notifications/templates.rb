module Domain
  module Notifications
    # R5: "Web-push/SMS payloads contain no health data" — every body here
    # is deliberately generic, including for a RED escalation. Urgency is
    # conveyed inside the app after the caregiver opens it, never in the
    # notification payload itself (which can sit on a visible lock screen).
    #
    # Per-language (ADR-0008 #7, M6 "pending-notification language follows
    # switch"): EN/DE are agent-authored (DE MACHINE_DRAFT, same convention
    # as UI copy, docs/OPEN_DECISIONS.md #2); TR/RU/AR ship as EN-fallback,
    # same convention as the caregiver i18n JSON files. `Dispatcher` reads
    # `caregiver.language` fresh at send time, so a language switch takes
    # effect on the very next dispatch — no separate "pending" state.
    module Templates
      BODIES = {
        "daily_reminder" => {
          "en" => "Time for today's check-in.",
          "de" => "Zeit für die heutige Eingabe.",
          "tr" => "Time for today's check-in.",
          "ru" => "Time for today's check-in.",
          "ar" => "Time for today's check-in."
        },
        "missed_day" => {
          "en" => "Please open the app when you can.",
          "de" => "Bitte öffnen Sie die App, wenn Sie können.",
          "tr" => "Please open the app when you can.",
          "ru" => "Please open the app when you can.",
          "ar" => "Please open the app when you can."
        },
        "red_escalation" => {
          "en" => "Please open the app now.",
          "de" => "Bitte öffnen Sie die App jetzt.",
          "tr" => "Please open the app now.",
          "ru" => "Please open the app now.",
          "ar" => "Please open the app now."
        },
        # ADR-0010, caregiver requirement #4 (per-medication-schedule
        # reminders). As generic as every other body here — no drug name,
        # no dose amount, no "medication" health term (R5 payload
        # minimization; see the deliberately generic wording, not
        # "Time to take your medication").
        "dose_reminder" => {
          "en" => "Time for a scheduled task in the app.",
          "de" => "Zeit für eine geplante Aufgabe in der App.",
          "tr" => "Time for a scheduled task in the app.",
          "ru" => "Time for a scheduled task in the app.",
          "ar" => "Time for a scheduled task in the app."
        }
      }.freeze

      def self.body_for(kind:, language:)
        variants = BODIES.fetch(kind)
        variants[language.to_s] || variants.fetch("en")
      end
    end
  end
end
