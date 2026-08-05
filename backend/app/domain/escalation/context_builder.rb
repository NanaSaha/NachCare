module Domain
  module Escalation
    # The only layer that touches the DB/clock for an evaluation — resolves
    # everything time-dependent into a plain Hash so Engine#evaluate stays
    # pure (R2). Pass `check_in: nil` for the R-8 nightly missed-check-in
    # scan, where there is no check-in to evaluate, just an episode's
    # silence.
    class ContextBuilder
      WINDOW_DAYS = 14
      RECENT_SEVERITIES_LIMIT = 10
      MISSED_CHECKIN_SAFETY_BOUND_DAYS = 30

      def self.build(episode:, check_in: nil, as_of: Time.current)
        new(episode:, check_in:, as_of:).build
      end

      def initialize(episode:, check_in:, as_of:)
        @episode = episode
        @check_in = check_in
        @as_of = as_of
      end

      def build
        {
          effective_date: effective_date.iso8601,
          weight_kg: check_in&.weight_kg&.to_f,
          weights_by_date: weights_by_date,
          symptoms: check_in&.symptoms || {},
          medications_missed_critical: medications_missed_critical?,
          consecutive_missed_checkin_days: consecutive_missed_checkin_days,
          consecutive_missing_weight_checkins: consecutive_missing_weight_checkins,
          note_text: check_in&.note,
          language: primary_caregiver_language,
          recent_severities: recent_severities
        }
      end

      private

      attr_reader :episode, :check_in, :as_of

      def effective_date
        check_in&.effective_date || as_of.to_date
      end

      def window_start
        effective_date - WINDOW_DAYS
      end

      def recent_check_ins
        @recent_check_ins ||= episode.check_ins
          .where(effective_date: window_start..effective_date)
          .order(effective_date: :desc)
          .to_a
      end

      def weights_by_date
        recent_check_ins.each_with_object({}) do |ci, h|
          h[ci.effective_date.iso8601] = ci.weight_kg.to_f if ci.weight_kg
        end
      end

      def medications_missed_critical?
        return false if check_in.nil?

        active_plan = episode.care_plans.find_by(active: true)
        return false unless active_plan

        critical_ids = active_plan.medications.where(critical: true).pluck(:id).map(&:to_s)
        return false if critical_ids.empty?

        med_status = check_in.med_status || {}
        critical_ids.any? { |id| med_status[id] == "missed" }
      end

      def consecutive_missed_checkin_days
        return 0 if check_in.present?

        count = 0
        date = as_of.to_date
        while count <= MISSED_CHECKIN_SAFETY_BOUND_DAYS
          break if episode.check_ins.exists?(effective_date: date)

          count += 1
          date -= 1
        end
        count
      end

      def consecutive_missing_weight_checkins
        ordered = if check_in&.persisted?
          [ check_in ] + recent_check_ins.reject { |ci| ci.id == check_in.id }
        elsif check_in
          [ check_in ] + recent_check_ins
        else
          recent_check_ins
        end

        ordered.take_while { |ci| ci.weight_kg.nil? }.size
      end

      def primary_caregiver_language
        episode.caregivers.first&.language || "en"
      end

      def recent_severities
        episode.evaluations.order(created_at: :desc).limit(RECENT_SEVERITIES_LIMIT).pluck(:severity)
      end
    end
  end
end
