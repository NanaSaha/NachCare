module Api
  module V1
    module Staff
      # UC-24: post-promotion cadence-adaptation proposals. `index`
      # refreshes (computes a new pending proposal if warranted, no-op
      # otherwise — Domain::Risk::CadenceAdvisor#refresh! is idempotent)
      # before listing, so the nurse always sees the current state without
      # a separate "check for updates" step.
      class CadenceProposalsController < ApplicationController
        before_action :authenticate_user!
        before_action :set_episode

        def index
          authorize CadenceProposal.new(episode: @episode), :index?
          Domain::Risk::CadenceAdvisor.refresh!(@episode)
          proposals = @episode.cadence_proposals.order(created_at: :desc)
          render json: proposals.map { |p| proposal_json(p) }, status: :ok
        end

        def approve
          proposal = @episode.cadence_proposals.find(params[:id])
          authorize proposal, :decide?
          care_plan = Domain::Risk::CadenceAdvisor.new(@episode).approve!(proposal, decided_by: current_user)
          render json: { proposal: proposal_json(proposal), care_plan_version: care_plan.version }, status: :ok
        end

        def dismiss
          proposal = @episode.cadence_proposals.find(params[:id])
          authorize proposal, :decide?
          Domain::Risk::CadenceAdvisor.new(@episode).dismiss!(proposal, decided_by: current_user)
          render json: proposal_json(proposal), status: :ok
        end

        private

        def set_episode
          @episode = ::Episode.find(params[:episode_id])
        end

        def proposal_json(p)
          { id: p.id, direction: p.direction, proposed_cadence: p.proposed_cadence, rationale: p.rationale,
            status: p.status, created_at: p.created_at }
        end
      end
    end
  end
end
