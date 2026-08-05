module Domain
  module Learn
    # Learn curriculum unlock-by-week (Section 8/M6: "unlock weeks").
    # Unlock state is derived from `episode.start_date`, never stored per
    # caregiver (ADR-0008 #2) — same "derive, don't cache" approach as the
    # escalation engine's context builder.
    class Unlocker
      def self.unlocked?(item:, episode:)
        new.unlocked?(item: item, episode: episode)
      end

      def unlocked?(item:, episode:)
        program_week(episode) >= item.week_no
      end

      # 1-based: week 1 covers days 0-6 of the episode, week 2 days 7-13, etc.
      def program_week(episode)
        ((Date.current - episode.start_date).to_i / 7) + 1
      end
    end
  end
end
