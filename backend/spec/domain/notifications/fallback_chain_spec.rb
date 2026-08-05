require "rails_helper"

RSpec.describe Domain::Notifications::FallbackChain do
  describe ".start_red_chain!" do
    it "sends a webpush red_escalation notification to the episode's caregiver" do
      caregiver = create(:caregiver)
      flag = create(:flag, episode: caregiver.episode)

      # This caregiver has no push_subscription (never completed the
      # onboarding push-permission step), so WebPushAdapter#send! returns
      # false and, since M7 (ADR-0009 #8 / AT-3 "SMS fallback on simulated
      # push failure"), Dispatcher immediately cascades to an SMS
      # fallback attempt rather than waiting for PushConfirmWatchJob's
      # 5-minute unconfirmed window — see fallback_chain_spec's dedicated
      # "push down" coverage below and spec/hardening/failure_drills_spec.rb.
      expect do
        described_class.start_red_chain!(flag: flag)
      end.to change(NotificationAttempt, :count).by(2)

      webpush_attempt = NotificationAttempt.where(channel: "webpush").last
      expect(webpush_attempt.kind).to eq("red_escalation")
      expect(webpush_attempt.flag).to eq(flag)
      expect(webpush_attempt.state).to eq("failed")

      sms_attempt = NotificationAttempt.where(channel: "sms").last
      expect(sms_attempt.kind).to eq("red_escalation")
      expect(sms_attempt.flag).to eq(flag)
    end

    it "does nothing when the episode has no caregiver" do
      episode = create(:episode)
      flag = create(:flag, episode: episode)

      expect do
        described_class.start_red_chain!(flag: flag)
      end.not_to change(NotificationAttempt, :count)
    end
  end

  describe ".escalate_unconfirmed_red!" do
    it "sends an SMS red_escalation and records an audit event" do
      caregiver = create(:caregiver)
      caregiver.update!(contact_data: { "phone" => "+491234567" })
      flag = create(:flag, episode: caregiver.episode)

      expect do
        described_class.escalate_unconfirmed_red!(flag: flag)
      end.to change(NotificationAttempt, :count).by(1)
        .and change(AuditEvent, :count).by(1)

      attempt = NotificationAttempt.last
      expect(attempt.channel).to eq("sms")
      expect(attempt.kind).to eq("red_escalation")

      audit_event = AuditEvent.last
      expect(audit_event.action).to eq("flag.escalation_sms_sent")
    end
  end

  describe ".missed_day!" do
    it "sends a webpush notification on the first missed day" do
      caregiver = create(:caregiver)
      episode = caregiver.episode

      described_class.missed_day!(episode: episode, consecutive_missed_days: 1)

      expect(NotificationAttempt.last.channel).to eq("webpush")
      expect(NotificationAttempt.last.kind).to eq("missed_day")
    end

    it "escalates to SMS from the second consecutive missed day onward" do
      caregiver = create(:caregiver)
      caregiver.update!(contact_data: { "phone" => "+491234567" })
      episode = caregiver.episode

      described_class.missed_day!(episode: episode, consecutive_missed_days: 2)

      expect(NotificationAttempt.last.channel).to eq("sms")
      expect(NotificationAttempt.last.kind).to eq("missed_day")
    end

    it "does nothing when the episode has no caregiver" do
      episode = create(:episode)

      expect do
        described_class.missed_day!(episode: episode, consecutive_missed_days: 1)
      end.not_to change(NotificationAttempt, :count)
    end
  end
end
