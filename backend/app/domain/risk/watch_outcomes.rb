module Domain
  module Risk
    # UC-23 step 6: the three nurse actions on an open AI WATCH flag. Not
    # a parallel action system — these are `Intervention#outcome` values
    # exactly like every other flag's outcomes, applied as a follow-up
    # step after Api::V1::Staff::FlagsController#update's normal
    # state/outcome/note transition (which already handles state changes,
    # `Intervention` creation, audit, and broadcast). This class only
    # applies the AI-WATCH-specific side effects: expiry-timer adjustment
    # and tagging the triggering risk_score with the nurse's decision as
    # a training label (UC-23 step 7).
    class WatchOutcomes
      TIGHTENED_WINDOW_DAYS = 2

      ACCEPT_AND_WATCH = "accept_and_watch"
      ACCEPT_AND_INTERVENE = "accept_and_intervene"
      DISMISS_FALSE_POSITIVE = "dismiss_false_positive"
      OUTCOMES = [ ACCEPT_AND_WATCH, ACCEPT_AND_INTERVENE, DISMISS_FALSE_POSITIVE ].freeze

      def self.apply!(flag:, outcome:)
        new(flag, outcome).apply!
      end

      def initialize(flag, outcome)
        @flag = flag
        @outcome = outcome
      end

      def apply!
        return unless flag.subtype == "ai_watch" && OUTCOMES.include?(outcome)

        case outcome
        when ACCEPT_AND_WATCH
          # "Tightened observation window" (UC-23 6a): pull the auto-
          # expiry timer in, never push it out.
          tightened = Time.current + TIGHTENED_WINDOW_DAYS.days
          flag.update!(watch_expires_at: [ flag.watch_expires_at, tightened ].compact.min)
        when ACCEPT_AND_INTERVENE
          # Actively intervening now -- no auto-expiry; this resolves
          # through the normal flag lifecycle from here.
          flag.update!(watch_expires_at: nil)
        when DISMISS_FALSE_POSITIVE
          flag.update!(watch_expires_at: nil)
          OutcomeLinker.link_for_watch_resolution!(flag, outcome: "resolved_uneventful")
        end
      end

      private

      attr_reader :flag, :outcome
    end
  end
end
