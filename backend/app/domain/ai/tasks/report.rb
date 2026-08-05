module Domain
  module Ai
    module Tasks
      # T-REPORT (day-90 / GP report), Section 6 #1: no explicit
      # degradation is called out beyond the shared "drafts/report 20s"
      # timeout group, so it follows the same "nil -> UI hides" contract
      # as the other drafts. ctx: {episode:, language:}
      class Report
        def initialize(gateway:)
          @gateway = gateway
        end

        def call(ctx)
          episode = ctx.fetch(:episode)
          language = ctx.fetch(:language, "en")

          system = PromptAssembler.assemble(template: "report", vars: {
            "PATIENT_PSEUDONYM" => Pseudonymizer.for_patient(episode.patient),
            "USER_LANGUAGE" => language,
            "EPISODE_SUMMARY" => "start_date: #{episode.start_date}, status: #{episode.status}",
            "FLAG_HISTORY" => flag_history(episode),
            "ADHERENCE_SUMMARY" => adherence_summary(episode)
          })

          result = gateway.call!(task: :report, system: system, messages: [ { role: "user", content: "Generate the report." } ],
            episode: episode)
          result.text
        rescue Gateway::AllProvidersFailed
          nil
        end

        private

        attr_reader :gateway

        def flag_history(episode)
          episode.flags.order(:opened_at).map { |f| "#{f.severity}/#{f.state}" }.join(", ").presence || "none"
        end

        def adherence_summary(episode)
          total_days = (Date.current - episode.start_date).to_i.clamp(1, Float::INFINITY)
          "#{episode.check_ins.count} check-ins over #{total_days} days"
        end
      end
    end
  end
end
