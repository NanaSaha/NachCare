module Api
  module V1
    module Caregiver
      # FR-C15 (idempotent on client_uuid — the PWA's IndexedDB retry queue
      # can safely re-POST the same payload after a dropped connection);
      # FR-C16 (30-min correction window: #update supersedes the original
      # with a new row rather than mutating it, keeping check_ins
      # append-only in spirit).
      class CheckInsController < ApplicationController
        include CaregiverAuthenticatable

        EDIT_WINDOW = 30.minutes

        def create
          existing = ::CheckIn.find_by(client_uuid: check_in_params[:client_uuid])
          return render_result(existing, existing.evaluations.order(:created_at).last) if existing

          check_in = build_check_in
          if check_in.save
            # Recorded before evaluation, not after: this is the fact of
            # submission, not its outcome — and AT-8's audit-only
            # reconstruction needs `check_in.submitted` to genuinely
            # precede `flag.opened` in the timeline, matching what
            # actually happened, not just insertion order within the
            # same request.
            record_checkin_audit!(check_in)
            result = Domain::Escalation::Processor.process!(episode: current_caregiver.episode, check_in: check_in)
            watch_flag = run_shadow_risk_pipeline!(check_in, result.evaluation)
            Domain::Analytics::Tracker.track!(episode: current_caregiver.episode, name: "checkin.submitted")
            Domain::CareActivity::Broadcaster.check_in!(check_in)
            Domain::NurseAlerts::Broadcaster.check_in!(check_in)
            render_result(check_in, result.evaluation, status: :created, watch_flag: watch_flag)
          else
            render json: { errors: check_in.errors.full_messages }, status: :unprocessable_content
          end
        end

        def update
          original = current_caregiver.episode.check_ins.find(params[:id])

          if Time.current - original.submitted_at > EDIT_WINDOW
            return render json: { error: "edit_window_expired" }, status: :unprocessable_content
          end

          new_check_in = build_check_in
          if new_check_in.save
            original.update!(superseded_by: new_check_in.id)
            record_checkin_audit!(new_check_in)
            result = Domain::Escalation::Processor.process!(episode: current_caregiver.episode, check_in: new_check_in)
            watch_flag = run_shadow_risk_pipeline!(new_check_in, result.evaluation)
            Domain::Analytics::Tracker.track!(episode: current_caregiver.episode, name: "checkin.submitted")
            Domain::CareActivity::Broadcaster.check_in!(new_check_in)
            Domain::NurseAlerts::Broadcaster.check_in!(new_check_in)
            render_result(new_check_in, result.evaluation, status: :ok, watch_flag: watch_flag)
          else
            render json: { errors: new_check_in.errors.full_messages }, status: :unprocessable_content
          end
        end

        private

        def build_check_in
          current_caregiver.episode.check_ins.new(
            check_in_params.merge(caregiver: current_caregiver, submitted_at: Time.current)
          )
        end

        def check_in_params
          params.permit(:client_uuid, :effective_date, :weight_kg, :note, med_status: {}, symptoms: {})
        end

        # R6 / AT-8 (audit reconstruction of a day purely from
        # `audit_events`): check-in submission is clinically relevant —
        # without this, a day's story (submitted -> evaluated -> flag
        # opened) had a gap the audit spine couldn't fill by itself.
        def record_checkin_audit!(check_in)
          Domain::Audit::Recorder.record!(
            actor: current_caregiver, action: "check_in.submitted", entity: check_in,
            payload: { effective_date: check_in.effective_date.iso8601 }
          )
        end

        # UC-05: an additional, independent step alongside (never inside)
        # Domain::Escalation::Processor.process! — see
        # Domain::Risk::Scorer's header comment and R2. Returns the newly
        # opened AI WATCH flag, if any (only possible post-promotion, see
        # Domain::Risk::WatchFlagger), so the result screen can show the
        # calm UC-23 card immediately.
        def run_shadow_risk_pipeline!(check_in, evaluation)
          risk_score = Domain::Risk::ShadowPipeline.process!(episode: current_caregiver.episode, check_in: check_in, evaluation: evaluation)
          return nil unless risk_score

          Domain::Risk::WatchFlagger.call!(risk_score: risk_score)
        end

        def render_result(check_in, evaluation, status: :ok, watch_flag: nil)
          render json: {
            check_in: CheckInBlueprint.render_as_hash(check_in),
            evaluation: evaluation ? { severity: evaluation.severity, fired_rule_count: evaluation.fired_rules.size } : nil,
            # M2 gap (per task brief): the green-path result screen showed
            # only a static i18n template before this. `brief: nil` means
            # either non-green (frontend already shows severity-specific
            # copy) or AI unavailable — Tasks::Brief's own template
            # fallback (ADR-0007) already covers the latter, so `nil` here
            # only ever means "not a green evaluation."
            brief: green_brief(check_in, evaluation),
            # UC-23 step 4: signal only — all caregiver-facing copy for the
            # calm AI WATCH card lives in frontend i18n (deliberately
            # non-AI-generated for this highest-empathy-required surface).
            ai_watch: watch_flag ? { opened: true } : nil
          }, status: status
        end

        def green_brief(check_in, evaluation)
          return nil unless evaluation&.severity == "green"

          result = Domain::Ai::Gateway.daily_brief(evaluation: evaluation, episode: check_in.episode, language: current_caregiver.language)
          { text: result.text, source: result.source }
        end
      end
    end
  end
end
