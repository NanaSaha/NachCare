module Domain
  module Graduation
    # Staff-initiated day-90 lifecycle transition (ADR-0008 #4/#5). Not a
    # scheduled job — a managing-role staff member must call this
    # explicitly (`EpisodePolicy#graduate?`), unlike R-8's missed-check-in
    # scan which only ever *flags*, never changes episode/flag state
    # automatically.
    class Graduator
      class NotEligible < StandardError; end
      class AlreadyGraduated < StandardError; end

      def self.graduate!(episode:, actor:)
        new.graduate!(episode: episode, actor: actor)
      end

      def graduate!(episode:, actor:)
        raise AlreadyGraduated if episode.status == "graduated"
        raise NotEligible unless Eligibility.eligible?(episode: episode)

        language = episode.caregivers.first&.language || "en"
        report_text = Domain::Ai::Gateway.episode_report(episode: episode, language: language)

        episode.status = "graduated"
        episode.milestones = (episode.milestones || {}).merge(
          "graduated_at" => Time.current.iso8601,
          "graduated_by" => actor.id.to_s,
          "graduation_report" => report_text
        )
        episode.save!

        Domain::Audit::Recorder.record!(
          actor: actor, action: "episode.graduated", entity: episode,
          payload: { report_generated: report_text.present? }
        )
        Domain::Analytics::Tracker.track!(episode: episode, name: "episode.graduated")

        episode
      end
    end
  end
end
