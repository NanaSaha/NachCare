module Domain
  module Flags
    # Turns a (non-green) evaluation into a flag. If the episode already has
    # an open/in_progress flag, the evaluation is appended to it rather than
    # opening a second one — one flag per episode at a time, escalating in
    # place. Severity can only escalate here (yellow -> red); a later green
    # evaluation doesn't downgrade or auto-resolve an open flag — resolution
    # is a human action (M3 triage).
    class Lifecycle
      def self.record_evaluation!(evaluation:)
        new(evaluation:).record!
      end

      def initialize(evaluation:)
        @evaluation = evaluation
      end

      def record!
        return nil if evaluation.severity == "green"

        existing = ::Flag.where(episode_ref: evaluation.episode_ref, state: %w[open in_progress]).first
        existing ? upgrade(existing) : create_flag
      end

      private

      attr_reader :evaluation

      def upgrade(flag)
        attrs = { evaluation_refs: (flag.evaluation_refs || []) + [ evaluation.id ] }
        became_red = false
        # UC-23 Alternate A1: rules fired for real while an AI WATCH flag
        # was open on this episode -- it escalates in place into a
        # standard rules-driven flag rather than the rules opening a
        # second, competing flag. Always applies (regardless of rank),
        # since an ai_watch flag's severity is "yellow" by construction
        # and a same-rank rules yellow still needs to convert it into a
        # real, SLA-pressured flag.
        ai_watch_escalating = flag.subtype == "ai_watch"

        if ai_watch_escalating || rank(evaluation.severity) > rank(flag.severity)
          attrs[:severity] = evaluation.severity
          attrs[:sla_deadline_at] = Sla.deadline_for(episode: evaluation.episode, severity: evaluation.severity, from: evaluation.created_at)
          became_red = evaluation.severity == "red"
        end

        if ai_watch_escalating
          # Design decision #5: preserve the watch's history/context on
          # the resulting real flag rather than discarding it.
          attrs[:subtype] = "clinical"
          attrs[:watch_expires_at] = nil
          attrs[:ai_watch_meta] = (flag.ai_watch_meta || {}).merge(
            "escalated_at" => evaluation.created_at.iso8601, "escalated_to_subtype" => "clinical"
          )
        end

        flag.update!(attrs)

        if ai_watch_escalating
          Domain::Risk::OutcomeLinker.link_for_watch_resolution!(flag, outcome: evaluation.severity == "red" ? "flag_red" : "flag_yellow")
        end
        Domain::Risk::OutcomeLinker.link_for_flag!(flag)

        Broadcaster.call(flag)
        # M4: RED chain starts the moment a flag *becomes* red, not on
        # every subsequent evaluation while it stays red.
        Domain::Notifications::FallbackChain.start_red_chain!(flag: flag) if became_red
        flag
      end

      def create_flag
        flag = ::Flag.create!(
          episode_ref: evaluation.episode_ref,
          evaluation_refs: [ evaluation.id ],
          severity: evaluation.severity,
          subtype: "clinical",
          state: "open",
          opened_at: evaluation.created_at,
          sla_deadline_at: Sla.deadline_for(episode: evaluation.episode, severity: evaluation.severity, from: evaluation.created_at)
        )
        Domain::Risk::OutcomeLinker.link_for_flag!(flag)
        Broadcaster.call(flag)
        Domain::Analytics::Tracker.track!(episode: evaluation.episode, name: "flag.opened", properties: { "severity" => flag.severity })
        # R6 / AT-8: the flag lifecycle is system-triggered (no staff
        # actor), same convention as FallbackChain's `flag.escalation_sms_
        # sent` — without this, an automatically-opened flag was invisible
        # to audit-only reconstruction even though a human viewing/
        # resolving it later was already recorded.
        Domain::Audit::Recorder.record!(
          actor: :system, action: "flag.opened", entity: flag,
          payload: { severity: flag.severity, evaluation_ref: evaluation.id }
        )
        Domain::Notifications::FallbackChain.start_red_chain!(flag: flag) if flag.severity == "red"
        flag
      end

      def rank(severity)
        Domain::Escalation::Engine::SEVERITY_RANK.fetch(severity, 0)
      end
    end
  end
end
