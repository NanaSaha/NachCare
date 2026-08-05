require "prawn"

Prawn::Fonts::AFM.hide_m17n_warning = true # English-only content today; revisit if this ever renders non-Latin text

module Domain
  module Enrollment
    # Printable A5 activation code sheet (Section 8, M1). Renders
    # server-side with Prawn (ADR-0004) — no headless browser dependency.
    # English-only for M1; the SRS doesn't specify per-language code
    # sheets, and this is a one-time printed artifact handed over at
    # discharge, not an in-app surface, so it isn't covered by R7's
    # component-level i18n requirement.
    class CodeSheetPdf
      A5_PORTRAIT = [ 419.53, 595.28 ].freeze

      def self.render(episode:, plaintext_code:, role:, expires_at:)
        new(episode:, plaintext_code:, role:, expires_at:).render
      end

      def initialize(episode:, plaintext_code:, role:, expires_at:)
        @episode = episode
        @plaintext_code = plaintext_code
        @role = role
        @expires_at = expires_at
      end

      def render
        Prawn::Document.new(page_size: A5_PORTRAIT, margin: 36) do |pdf|
          pdf.text "NachCare AI", size: 20, style: :bold
          pdf.move_down 4
          pdf.text "Caregiver activation code", size: 13, color: "555555"
          pdf.move_down 20

          pdf.text formatted_code, size: 30, style: :bold, align: :center
          pdf.move_down 20

          pdf.text "Patient: #{patient.pseudonym_code}"
          pdf.text "Role: #{role.capitalize} caregiver"
          pdf.text "Expires: #{expires_at.strftime('%d %b %Y')}"
          pdf.move_down 20

          pdf.text "How to activate", style: :bold
          pdf.move_down 4
          [
            "Open the NachCare AI caregiver app.",
            "Enter this code when prompted.",
            "Follow the on-screen setup: language, consent, notification time, PIN."
          ].each_with_index do |step, i|
            pdf.text "#{i + 1}. #{step}"
          end

          pdf.move_down 20
          pdf.text "Keep this sheet private — anyone with this code can activate as this " \
                    "patient's caregiver until it is used or expires.",
            size: 9, color: "777777"
        end.render
      end

      private

      attr_reader :episode, :plaintext_code, :role, :expires_at

      def patient
        episode.patient
      end

      def formatted_code
        plaintext_code.chars.each_slice(4).map(&:join).join(" ")
      end
    end
  end
end
