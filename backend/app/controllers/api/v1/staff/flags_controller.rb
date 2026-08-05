module Api
  module V1
    module Staff
      class FlagsController < ApplicationController
        before_action :authenticate_user!
        before_action :set_flag, only: [ :show, :update, :triage_draft, :callnote_draft, :ai_watch_rationale ]

        SEVERITY_ORDER = "CASE severity WHEN 'red' THEN 0 WHEN 'yellow' THEN 1 ELSE 2 END".freeze

        def index
          flags = policy_scope(Flag).includes(episode: :patient)
          flags = flags.where(state: params[:state]) if params[:state].present?
          flags = flags.order(Arel.sql("#{SEVERITY_ORDER}, sla_deadline_at ASC NULLS LAST"))

          render json: FlagBlueprint.render(flags), status: :ok
        end

        # KPI header (Section 8/M3): counts by state/severity for the
        # nurse's own site. `yellow` deliberately excludes ai_watch flags
        # (UC-23: AI WATCH is its own dedicated queue section, not folded
        # into the rules-driven yellow count) — `ai_watch` is its own key.
        def summary
          flags = policy_scope(Flag).where(state: %w[open in_progress])
          render json: {
            open: flags.where(state: "open").count,
            in_progress: flags.where(state: "in_progress").count,
            red: flags.where(severity: "red").count,
            yellow: flags.where(severity: "yellow").where.not(subtype: "ai_watch").count,
            ai_watch: flags.where(subtype: "ai_watch").count,
            breached: flags.where(breach: true).count
          }, status: :ok
        end

        def show
          authorize @flag
          Domain::Audit::Recorder.record!(actor: current_user, action: "flag.viewed", entity: @flag, payload: {})
          render json: FlagDetailBlueprint.render_as_hash(@flag), status: :ok
        end

        # Manual flags (FR-N9).
        def create
          episode = Episode.find(params[:episode_ref])
          severity = params[:severity].presence || "yellow"
          flag = Flag.new(episode: episode, severity: severity, subtype: "manual", state: "open", opened_at: Time.current)
          flag.sla_deadline_at = Domain::Flags::Sla.deadline_for(episode: episode, severity: severity, from: flag.opened_at)
          authorize flag

          if flag.save
            Domain::Audit::Recorder.record!(actor: current_user, action: "flag.created_manual", entity: flag, payload: { severity: severity })
            Domain::Flags::Broadcaster.call(flag)
            render json: FlagBlueprint.render_as_hash(flag), status: :created
          else
            render json: { errors: flag.errors.full_messages }, status: :unprocessable_content
          end
        end

        # State transitions + intervention logging, in one call: the
        # cockpit's "resolve this flag" form submits both together.
        def update
          authorize @flag

          ActiveRecord::Base.transaction do
            @flag.first_action_at ||= Time.current if params[:state].present? && params[:state] != "open"
            @flag.state = params[:state] if params[:state].present?
            @flag.outcome = params[:outcome] if params[:outcome].present?
            @flag.resolved_at = Time.current if params[:state] == "resolved"
            @flag.save!

            if params[:outcome].present? || params[:note].present?
              # T-TRIAGE edit-tracking (Section 8/M5): when the nurse's
              # saved note started from an AI draft (note_ai present),
              # record how much they kept vs. rewrote.
              Intervention.create!(
                flag: @flag, actor: current_user, outcome: params[:outcome],
                note_ai: params[:note_ai].presence, note_final: params[:note],
                ai_accept_ratio: Domain::Ai::AcceptRatio.compute(params[:note_ai], params[:note])
              )
            end

            # UC-23 step 6: accept-and-watch / accept-and-intervene /
            # dismiss-as-false-positive side effects (expiry-timer
            # adjustment, risk_score training-label tagging) — not a new
            # action system, a follow-up to the state/outcome transition
            # already applied above.
            if @flag.subtype == "ai_watch" && params[:outcome].present?
              Domain::Risk::WatchOutcomes.apply!(flag: @flag, outcome: params[:outcome])
            end
          end

          Domain::Audit::Recorder.record!(
            actor: current_user, action: "flag.updated", entity: @flag, payload: { state: @flag.state, outcome: @flag.outcome }
          )
          Domain::Flags::Broadcaster.call(@flag)
          if @flag.state == "resolved"
            Domain::Analytics::Tracker.track!(episode: @flag.episode, name: "flag.resolved", properties: { "severity" => @flag.severity, "breach" => @flag.breach })
          end

          render json: FlagDetailBlueprint.render_as_hash(@flag), status: :ok
        end

        # T-TRIAGE copilot draft (Section 8/M5): AI-purple ✦ suggestion the
        # nurse edits/approves before it becomes an Intervention. Returns
        # `draft: nil` on graceful degradation (Section 6 #1) — the UI
        # hides the draft panel rather than showing an error.
        def triage_draft
          authorize @flag, :show?
          render json: { draft: Domain::Ai::Gateway.triage_draft(flag: @flag, language: draft_language) }, status: :ok
        end

        def callnote_draft
          authorize @flag, :show?
          render json: { draft: Domain::Ai::Gateway.callnote_draft(flag: @flag, language: draft_language) }, status: :ok
        end

        # UC-23 step 5: the AI WATCH queue's COPILOT rationale panel —
        # never a bare score (Domain::Ai::Tasks::AiWatchRationale always
        # returns *something*, AI-generated or a deterministic
        # plain-language fallback).
        def ai_watch_rationale
          authorize @flag, :show?
          render json: { rationale: Domain::Ai::Gateway.ai_watch_rationale(flag: @flag, language: draft_language) }, status: :ok
        end

        private

        def set_flag
          @flag = Flag.find(params[:id])
        end

        def draft_language
          @flag.episode.caregivers.first&.language || "en"
        end
      end
    end
  end
end
