module Domain
  module Audit
    # AT-8 (Section 8's acceptance test suite): "audit reconstruction of
    # day-17 from audit_events alone (write the reconstruction script)."
    #
    # `audit_events` has no `episode_ref` column (Section 5's schema —
    # entities are referenced generically via `entity_type`/`entity_ref`),
    # so this class uses the episode's `check_ins`/`flags` associations
    # ONCE, up front, purely as an *index* of which entity ids belong to
    # this episode. Every fact in the reconstructed timeline itself — who
    # did what, when, with what payload — comes exclusively from
    # `audit_events` rows, never from re-reading `check_ins`/`flags`'
    # current (mutable-in-place) field values. That distinction is the
    # actual point of AT-8: `flags.state` only ever shows the CURRENT
    # state ("resolved"); it cannot show the sequence the flag passed
    # through (`open` -> `in_progress` -> `resolved`), who acted at each
    # step, or when. Only the append-only audit spine can.
    class EpisodeReconstructor
      TimelineEntry = Struct.new(:at, :actor, :action, :entity_type, :entity_ref, :payload, keyword_init: true)

      def self.call(episode:, date: nil)
        new(episode:, date:).call
      end

      def initialize(episode:, date: nil)
        @episode = episode
        @date = date
      end

      def call
        entries = AuditEvent
          .where(entity_type: "check_in", entity_ref: check_in_ids)
          .or(AuditEvent.where(entity_type: "flag", entity_ref: flag_ids))
          .or(AuditEvent.where(entity_type: "intervention", entity_ref: intervention_ids))
          .order(:created_at)
          .map { |e| to_entry(e) }

        date ? entries.select { |e| e.at.to_date == date } : entries
      end

      private

      attr_reader :episode, :date

      def check_in_ids
        @check_in_ids ||= episode.check_ins.pluck(:id).map(&:to_s)
      end

      def flag_ids
        @flag_ids ||= episode.flags.pluck(:id).map(&:to_s)
      end

      def intervention_ids
        @intervention_ids ||= Intervention.where(flag_ref: episode.flags.select(:id)).pluck(:id).map(&:to_s)
      end

      def to_entry(event)
        TimelineEntry.new(
          at: event.created_at,
          actor: event.actor_ref ? "#{event.actor_type}:#{event.actor_ref}" : event.actor_type,
          action: event.action,
          entity_type: event.entity_type,
          entity_ref: event.entity_ref,
          payload: event.payload
        )
      end
    end
  end
end
