require "prawn"

Prawn::Fonts::AFM.hide_m17n_warning = true # English-only content today, same as CodeSheetPdf (ADR-0004)

module Domain
  module Analytics
    # FR-N12 PDF export (ADR-0009 #3) — same Prawn pattern as
    # Domain::Enrollment::CodeSheetPdf (ADR-0004): server-side rendering,
    # no headless-browser dependency. Aggregate counts/rates only, never a
    # patient/caregiver identifier (R5) — the metrics hash it's given is
    # already pseudonym-safe by construction (PilotMetrics::Result).
    class PilotMetricsPdf
      LABELS = {
        "checkin_adherence_rate" => "Check-in adherence rate",
        "red_flag_sla_compliance_rate" => "RED-flag SLA compliance rate",
        "red_flag_median_time_to_first_action_minutes" => "RED-flag median time-to-first-action (min)",
        "program_completion_rate" => "Program completion rate (day-90 graduation)",
        "assistant_safety_routing_rate" => "Assistant safety-routing rate"
      }.freeze

      def self.render(site:, metrics:)
        new(site:, metrics:).render
      end

      def initialize(site:, metrics:)
        @site = site
        @metrics = metrics
      end

      def render
        Prawn::Document.new(page_size: "A4", margin: 48) do |pdf|
          pdf.text "NachCare AI — Pilot metrics report", size: 20, style: :bold
          pdf.move_down 4
          pdf.text site.name, size: 13, color: "555555"
          pdf.text "Period: #{metrics['from']} to #{metrics['to']}", size: 11, color: "777777"
          pdf.move_down 20

          LABELS.each do |key, label|
            pdf.text "#{label}: #{format_value(metrics[key])}", size: 12
            pdf.move_down 6
          end

          pdf.move_down 14
          pdf.text "Aggregate, site-level counts only — no patient or caregiver identifiers.", size: 9, color: "777777"
        end.render
      end

      private

      attr_reader :site, :metrics

      def format_value(value)
        return "no data yet" if value.nil?
        return value.round(3) if value.is_a?(Numeric)

        value
      end
    end
  end
end
