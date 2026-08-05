module Domain
  module Notifications
    # AT-3 / Section 8 M4: "RED chain: push -> unconfirmed 5 min -> SMS +
    # cockpit escalation task." The 5-minute wait is enforced by
    # PushConfirmWatchJob (scheduled), not by this class — FallbackChain
    # only knows how to start the chain and how to escalate once told the
    # window elapsed unconfirmed.
    class FallbackChain
      RED_CONFIRM_WINDOW = 5.minutes

      def self.start_red_chain!(flag:)
        caregiver = flag.episode.caregivers.first
        return unless caregiver

        Dispatcher.send!(caregiver: caregiver, channel: "webpush", kind: "red_escalation", flag: flag)
      end

      # Called by PushConfirmWatchJob once RED_CONFIRM_WINDOW has passed
      # with no push-received confirmation beacon.
      def self.escalate_unconfirmed_red!(flag:)
        caregiver = flag.episode.caregivers.first
        return unless caregiver

        Dispatcher.send!(caregiver: caregiver, channel: "sms", kind: "red_escalation", flag: flag)
        Domain::Audit::Recorder.record!(actor: :system, action: "flag.escalation_sms_sent", entity: flag, payload: {})
      end

      # Missed-day chain (Section 8 M4): day 1 missed -> push, day 2+ -> SMS.
      def self.missed_day!(episode:, consecutive_missed_days:)
        caregiver = episode.caregivers.first
        return unless caregiver

        channel = consecutive_missed_days >= 2 ? "sms" : "webpush"
        Dispatcher.send!(caregiver: caregiver, channel: channel, kind: "missed_day")
      end
    end
  end
end
