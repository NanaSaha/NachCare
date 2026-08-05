require "rails_helper"

# R5: "No PHI in ... notification payloads." This spec is the explicit M4
# gate check that every notification body we can ever dispatch — for every
# kind, including a RED escalation — is generic and carries no clinical
# vocabulary, symptom names, thresholds, or severity words.
RSpec.describe "Notification payload minimization (R5)" do
  FORBIDDEN_TERMS = %w[
    weight kg symptom symptoms blood pressure heart failure breath
    breathless swelling oedema edema fluid dose dosage medication drug
    red yellow green severity urgent flag alert diagnosis prognosis
    escalation cardiac
  ].freeze

  it "contains no health- or severity-related terms in any template body, in any language" do
    Domain::Notifications::Templates::BODIES.each do |kind, variants|
      variants.each do |language, body|
        downcased = body.downcase
        offending = FORBIDDEN_TERMS.select { |term| downcased.include?(term) }
        expect(offending).to be_empty, "kind=#{kind} language=#{language} body=#{body.inspect} contains forbidden terms: #{offending}"
      end
    end
  end

  it "covers every supported caregiver language for every kind" do
    Domain::Notifications::Templates::BODIES.each do |kind, variants|
      expect(variants.keys.sort).to eq(%w[ar de en ru tr]), "kind=#{kind} is missing a language variant"
    end
  end

  it "covers every notification kind the domain can dispatch" do
    expect(Domain::Notifications::Templates::BODIES.keys.sort).to eq(
      %w[daily_reminder missed_day red_escalation dose_reminder].sort
    )
  end
end
