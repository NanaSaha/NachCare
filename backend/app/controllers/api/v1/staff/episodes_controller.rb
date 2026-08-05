module Api
  module V1
    module Staff
      # Day-90 graduation (Section 8/M6, ADR-0008 #4/#5): a staff-initiated
      # lifecycle transition, not an automatic job. Existing nested routes
      # (`care_plan`, `messages`, `assistant_conversation`, `report`) already
      # live under `resources :episodes, only: []`; this adds the top-level
      # controller that owns the resource itself.
      class EpisodesController < ApplicationController
        before_action :authenticate_user!

        def graduate
          episode = Episode.find(params[:id])
          authorize episode, :graduate?

          graduated = Domain::Graduation::Graduator.graduate!(episode: episode, actor: current_user)
          render json: {
            id: graduated.id, status: graduated.status, milestones: graduated.milestones
          }, status: :ok
        rescue Domain::Graduation::Graduator::NotEligible
          render json: { error: "not_eligible", min_days: Domain::Graduation::Eligibility::MIN_DAYS }, status: :unprocessable_content
        rescue Domain::Graduation::Graduator::AlreadyGraduated
          render json: { error: "already_graduated" }, status: :unprocessable_content
        end
      end
    end
  end
end
