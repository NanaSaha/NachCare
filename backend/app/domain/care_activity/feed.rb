module Domain
  module CareActivity
    # Initial (non-live) recent-activity list for the cockpit patient-detail
    # page, so the "recent caregiver activity" section has real content on
    # first load rather than only ever growing after a live broadcast
    # (ADR-0010). Reuses `Broadcaster`'s payload builders so the shape is
    # identical whether an item arrived live or from this fetch.
    class Feed
      def self.recent(episode:, limit: 20)
        check_ins = episode.check_ins.order(submitted_at: :desc).limit(limit).map { |c| Broadcaster.check_in_payload(c) }

        doses = MedicationDose.joins(medication: :care_plan)
          .where(care_plans: { episode_ref: episode.id })
          .order(updated_at: :desc).limit(limit)
          .map { |d| Broadcaster.dose_payload(d) }

        (check_ins + doses).sort_by { |h| h[:occurred_at] }.reverse.first(limit)
      end
    end
  end
end
