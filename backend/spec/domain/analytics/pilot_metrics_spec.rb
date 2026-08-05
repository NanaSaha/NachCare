require "rails_helper"

RSpec.describe Domain::Analytics::PilotMetrics do
  let(:site) { create(:site, sla_red_minutes: 30, sla_yellow_minutes: 240) }
  let(:patient) { create(:patient, site: site) }
  let(:from) { 10.days.ago.to_date }
  let(:to) { Date.current }

  describe ".compute" do
    it "computes check-in adherence rate as completed / expected days" do
      episode = create(:episode, patient: patient, start_date: 4.days.ago.to_date)
      caregiver = create(:caregiver, episode: episode)
      # Episode is 4 (elapsed) days old -> expected = 5 (day 0..4 inclusive-ish per elapsed+1),
      # only submit 2 of them.
      create(:check_in, episode: episode, caregiver: caregiver, effective_date: 4.days.ago.to_date)
      create(:check_in, episode: episode, caregiver: caregiver, effective_date: 3.days.ago.to_date)

      metrics = described_class.compute(site: site, from: from, to: to)

      expect(metrics[:checkin_adherence_rate]).to be_within(0.01).of(2.0 / 5.0)
    end

    it "computes RED-flag SLA compliance rate from breach flags" do
      episode = create(:episode, patient: patient)
      create(:flag, episode: episode, severity: "red", state: "resolved", breach: false, opened_at: 2.days.ago)
      create(:flag, episode: episode, severity: "red", state: "resolved", breach: true, opened_at: 2.days.ago)
      create(:flag, episode: episode, severity: "yellow", state: "resolved", breach: true, opened_at: 2.days.ago)

      metrics = described_class.compute(site: site, from: from, to: to)

      expect(metrics[:red_flag_sla_compliance_rate]).to be_within(0.01).of(0.5)
    end

    it "computes RED-flag median time-to-first-action in minutes" do
      episode = create(:episode, patient: patient)
      opened = 2.days.ago
      create(:flag, episode: episode, severity: "red", opened_at: opened, first_action_at: opened + 10.minutes)
      create(:flag, episode: episode, severity: "red", opened_at: opened, first_action_at: opened + 30.minutes)

      metrics = described_class.compute(site: site, from: from, to: to)

      expect(metrics[:red_flag_median_time_to_first_action_minutes]).to be_within(0.5).of(20.0)
    end

    it "excludes RED flags with no first_action_at from the median" do
      episode = create(:episode, patient: patient)
      create(:flag, episode: episode, severity: "red", opened_at: 2.days.ago, first_action_at: nil)

      metrics = described_class.compute(site: site, from: from, to: to)

      expect(metrics[:red_flag_median_time_to_first_action_minutes]).to be_nil
    end

    it "computes program completion rate among eligible (>=90 day) episodes" do
      create(:episode, patient: patient, start_date: 120.days.ago.to_date, status: "graduated")
      create(:episode, patient: patient, start_date: 100.days.ago.to_date, status: "withdrawn")
      # Not eligible yet (< 90 days) -> excluded from the denominator.
      create(:episode, patient: patient, start_date: 10.days.ago.to_date, status: "active")

      metrics = described_class.compute(site: site, from: from, to: to)

      expect(metrics[:program_completion_rate]).to be_within(0.01).of(0.5)
    end

    it "computes assistant safety-routing rate" do
      episode = create(:episode, patient: patient)
      caregiver = create(:caregiver, episode: episode)
      conversation = create(:assistant_conversation, episode: episode, caregiver: caregiver)
      create(:assistant_turn, assistant_conversation: conversation, role: "assistant", routed: true)
      create(:assistant_turn, assistant_conversation: conversation, role: "assistant", routed: false)
      create(:assistant_turn, assistant_conversation: conversation, role: "caregiver", routed: false)

      metrics = described_class.compute(site: site, from: from, to: to)

      expect(metrics[:assistant_safety_routing_rate]).to be_within(0.01).of(0.5)
    end

    it "scopes everything to the given site only" do
      other_site = create(:site)
      other_patient = create(:patient, site: other_site)
      create(:episode, patient: other_patient, start_date: 120.days.ago.to_date, status: "graduated")

      metrics = described_class.compute(site: site, from: from, to: to)

      expect(metrics[:program_completion_rate]).to be_nil
    end

    it "returns nil rates (not zero, not an error) when there is no data" do
      metrics = described_class.compute(site: site, from: from, to: to)

      expect(metrics[:checkin_adherence_rate]).to be_nil
      expect(metrics[:red_flag_sla_compliance_rate]).to be_nil
      expect(metrics[:assistant_safety_routing_rate]).to be_nil
    end

    it "includes only pseudonym-safe fields (R5 — no patient/caregiver identifiers)" do
      episode = create(:episode, patient: patient)
      create(:flag, episode: episode, severity: "red", state: "resolved", breach: false)

      metrics = described_class.compute(site: site, from: from, to: to)

      expect(metrics.to_s).not_to include(patient.initials)
      expect(metrics[:site_id]).to eq(site.id)
    end
  end
end
