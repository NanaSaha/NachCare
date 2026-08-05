module Api
  module V1
    module Staff
      # T-REPORT (Section 8/M5): day-90/GP episode summary. Returns
      # structured text (JSON) rather than a rendered PDF for this build —
      # scoped down given time; Domain::Enrollment::CodeSheetPdf (ADR-0004)
      # already establishes the Prawn pattern this would reuse whenever
      # PDF rendering is prioritized. Returns `report: nil` on graceful
      # degradation (Section 6 #1).
      class ReportsController < ApplicationController
        before_action :authenticate_user!

        def show
          episode = Episode.find(params[:episode_id])
          authorize episode, :show?

          language = episode.caregivers.first&.language || "en"
          text = Domain::Ai::Gateway.episode_report(episode: episode, language: language)
          render json: { report: text }, status: :ok
        end
      end
    end
  end
end
