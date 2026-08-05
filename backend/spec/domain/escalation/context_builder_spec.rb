require "rails_helper"

RSpec.describe Domain::Escalation::ContextBuilder do
  let(:episode) { create(:episode) }
  let!(:caregiver) { create(:caregiver, episode: episode, language: "de") }

  def check_in_on(date, weight: 70.0, symptoms: {}, note: nil, med_status: {})
    create(:check_in, episode: episode, caregiver: caregiver, effective_date: date, weight_kg: weight,
      symptoms: symptoms, note: note, med_status: med_status)
  end

  describe "#build" do
    it "passes today's weight and symptoms straight through" do
      check_in = build(:check_in, episode: episode, caregiver: caregiver, effective_date: Date.current,
        weight_kg: 72.3, symptoms: { "breathless_at_rest" => true })

      context = described_class.build(episode: episode, check_in: check_in)

      expect(context[:weight_kg]).to eq(72.3)
      expect(context[:symptoms]).to eq({ "breathless_at_rest" => true })
    end

    it "builds a 14-day weights_by_date window from prior check-ins" do
      check_in_on(13.days.ago.to_date, weight: 65.0)
      check_in_on(20.days.ago.to_date, weight: 999.0) # outside the window — must be excluded
      today = build(:check_in, episode: episode, caregiver: caregiver, effective_date: Date.current, weight_kg: 70.0)

      context = described_class.build(episode: episode, check_in: today)

      expect(context[:weights_by_date][13.days.ago.to_date.iso8601]).to eq(65.0)
      expect(context[:weights_by_date].values).not_to include(999.0)
    end

    it "uses the primary caregiver's language" do
      today = build(:check_in, episode: episode, caregiver: caregiver, effective_date: Date.current)
      context = described_class.build(episode: episode, check_in: today)
      expect(context[:language]).to eq("de")
    end

    it "pulls the most recent evaluation severities, newest first" do
      create(:evaluation, episode: episode, severity: "green", created_at: 3.days.ago)
      create(:evaluation, episode: episode, severity: "yellow", created_at: 1.day.ago)

      context = described_class.build(episode: episode, check_in: nil)

      expect(context[:recent_severities]).to eq(%w[yellow green])
    end

    describe "consecutive_missed_checkin_days (R-8 scan, check_in: nil)" do
      it "is 0 when a check-in exists for today" do
        check_in_on(Date.current)
        context = described_class.build(episode: episode, check_in: nil, as_of: Time.current)
        expect(context[:consecutive_missed_checkin_days]).to eq(0)
      end

      it "counts backward from as_of until it finds a check-in" do
        check_in_on(3.days.ago.to_date)
        context = described_class.build(episode: episode, check_in: nil, as_of: Time.current)
        # today, yesterday, 2 days ago are missing; 3 days ago has one
        expect(context[:consecutive_missed_checkin_days]).to eq(3)
      end

      it "is always 0 when a check_in is being evaluated (they just checked in)" do
        today = build(:check_in, episode: episode, caregiver: caregiver, effective_date: Date.current)
        context = described_class.build(episode: episode, check_in: today)
        expect(context[:consecutive_missed_checkin_days]).to eq(0)
      end
    end

    describe "consecutive_missing_weight_checkins" do
      it "counts the current + prior consecutive check-ins with no weight" do
        check_in_on(1.day.ago.to_date, weight: nil)
        check_in_on(2.days.ago.to_date, weight: nil)
        check_in_on(3.days.ago.to_date, weight: 70.0) # breaks the streak

        today = build(:check_in, episode: episode, caregiver: caregiver, effective_date: Date.current, weight_kg: nil)
        context = described_class.build(episode: episode, check_in: today)

        expect(context[:consecutive_missing_weight_checkins]).to eq(3)
      end
    end

    describe "medications_missed_critical" do
      it "is true when a critical medication's status is 'missed'" do
        care_plan = create(:care_plan, episode: episode, active: true)
        critical_med = create(:medication, care_plan: care_plan, critical: true)
        create(:medication, care_plan: care_plan, critical: false)

        check_in = build(:check_in, episode: episode, caregiver: caregiver, effective_date: Date.current,
          med_status: { critical_med.id.to_s => "missed" })

        context = described_class.build(episode: episode, check_in: check_in)
        expect(context[:medications_missed_critical]).to be true
      end

      it "is false when only a non-critical medication was missed" do
        care_plan = create(:care_plan, episode: episode, active: true)
        create(:medication, care_plan: care_plan, critical: true)
        noncritical = create(:medication, care_plan: care_plan, critical: false)

        check_in = build(:check_in, episode: episode, caregiver: caregiver, effective_date: Date.current,
          med_status: { noncritical.id.to_s => "missed" })

        context = described_class.build(episode: episode, check_in: check_in)
        expect(context[:medications_missed_critical]).to be false
      end

      it "is false when there is no check-in to evaluate" do
        context = described_class.build(episode: episode, check_in: nil)
        expect(context[:medications_missed_critical]).to be false
      end
    end
  end
end
