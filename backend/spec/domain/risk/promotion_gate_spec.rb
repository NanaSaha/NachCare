require "rails_helper"

RSpec.describe Domain::Risk::PromotionGate do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }

  describe "with no data" do
    it "reports insufficient_data and does not meet the gates" do
      result = described_class.evaluate(site: site)

      expect(result.insufficient_data).to be true
      expect(result.overall_met).to be false
      expect(result.detection_lead_time_sample_size).to eq(0)
      expect(result.alert_rate_sample_checkins).to eq(0)
      expect(result.missed_reds_total_reds).to eq(0)
      expect(result.missed_reds_met).to be true # vacuously met
    end

    it "never fabricates a favorable number" do
      result = described_class.evaluate(site: site)

      expect(result.detection_lead_time_median_days).to be_nil
      expect(result.alert_rate_per_patient_day).to be_nil
    end
  end

  describe "gate 1: earlier median detection than the rules" do
    it "is met when enough alert-eligible scores were linked to a later rules flag, with positive lead time" do
      5.times do |i|
        ci = create(:check_in, episode: episode, effective_date: Date.current - 10 + i)
        create(:risk_score, episode: episode, check_in: ci, alert_eligible: true, outcome: "flag_yellow",
          outcome_evaluated_at: ci.effective_date + 2.days)
      end

      result = described_class.evaluate(site: site)

      expect(result.detection_lead_time_sample_size).to eq(5)
      expect(result.detection_lead_time_median_days).to eq(2.0)
      expect(result.detection_lead_time_met).to be true
    end

    it "is not met below the minimum sample size" do
      4.times do |i|
        ci = create(:check_in, episode: episode, effective_date: Date.current - 10 + i)
        create(:risk_score, episode: episode, check_in: ci, alert_eligible: true, outcome: "flag_yellow",
          outcome_evaluated_at: ci.effective_date + 2.days)
      end

      result = described_class.evaluate(site: site)

      expect(result.detection_lead_time_met).to be false
      expect(result.insufficient_data).to be true
    end

    it "is not met when the rules actually beat the model (non-positive median lead time)" do
      5.times do |i|
        ci = create(:check_in, episode: episode, effective_date: Date.current - 10 + i)
        create(:risk_score, episode: episode, check_in: ci, alert_eligible: true, outcome: "flag_yellow",
          outcome_evaluated_at: ci.effective_date) # same day, zero lead
      end

      result = described_class.evaluate(site: site)

      expect(result.detection_lead_time_met).to be false
    end
  end

  describe "gate 2: alert rate" do
    it "is met when the alert-eligible proportion is below the ceiling with enough samples" do
      25.times { |i| create(:check_in, episode: episode, effective_date: Date.current - i) }
      RiskScore.delete_all
      2.times do |i|
        ci = episode.check_ins.order(:effective_date).to_a[i]
        create(:risk_score, episode: episode, check_in: ci, alert_eligible: true)
      end

      result = described_class.evaluate(site: site)

      expect(result.alert_rate_sample_checkins).to eq(25)
      expect(result.alert_rate_per_patient_day).to be_within(0.001).of(2.0 / 25)
      expect(result.alert_rate_met).to be true
    end

    it "is not met when the alert-eligible proportion exceeds the ceiling" do
      20.times do |i|
        ci = create(:check_in, episode: episode, effective_date: Date.current - i)
        create(:risk_score, episode: episode, check_in: ci, alert_eligible: i.even?)
      end

      result = described_class.evaluate(site: site)

      expect(result.alert_rate_met).to be false
    end
  end

  describe "gate 3: no missed reds" do
    it "is met when every paired red evaluation shows an elevated score" do
      ci = create(:check_in, episode: episode)
      create(:evaluation, episode: episode, check_in: ci, severity: "red")
      create(:risk_score, episode: episode, check_in: ci, score: 0.9)

      result = described_class.evaluate(site: site)

      expect(result.missed_reds_total_reds).to eq(1)
      expect(result.missed_reds_count).to eq(0)
      expect(result.missed_reds_met).to be true
    end

    it "is not met when a red fired with a low paired score (the model missed it)" do
      ci = create(:check_in, episode: episode)
      create(:evaluation, episode: episode, check_in: ci, severity: "red")
      create(:risk_score, episode: episode, check_in: ci, score: 0.05)

      result = described_class.evaluate(site: site)

      expect(result.missed_reds_count).to eq(1)
      expect(result.missed_reds_met).to be false
    end

    it "excludes reds with no paired shadow score rather than counting them as missed" do
      ci = create(:check_in, episode: episode)
      create(:evaluation, episode: episode, check_in: ci, severity: "red")

      result = described_class.evaluate(site: site)

      expect(result.missed_reds_total_reds).to eq(0)
      expect(result.missed_reds_met).to be true
    end
  end

  it "scopes evaluation to the given site only" do
    other_site = create(:site)
    other_patient = create(:patient, site: other_site)
    other_episode = create(:episode, patient: other_patient)
    5.times do |i|
      ci = create(:check_in, episode: other_episode, effective_date: Date.current - 10 + i)
      create(:risk_score, episode: other_episode, check_in: ci, alert_eligible: true, outcome: "flag_yellow",
        outcome_evaluated_at: ci.effective_date + 5.days)
    end

    result = described_class.evaluate(site: site)

    expect(result.detection_lead_time_sample_size).to eq(0)
  end
end
