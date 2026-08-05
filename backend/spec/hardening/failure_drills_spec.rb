require "rails_helper"

# M7 failure drills (Section 8, ADR-0009 #8): "LLM down, push down, redis
# down — assert degradations match spec." Per the ADR, these are RSpec
# specs against stubbed failure conditions, not live container kills — the
# shared docker-compose stack stays up, and this is reproducible in CI the
# same way every prior phase's degradation behavior is already tested
# (M4's fallback_chain_spec.rb, M5's gateway/task specs). `verify_m7.sh`
# runs this file as its own explicit step.
RSpec.describe "M7 failure drills" do
  describe "drill: LLM down (both providers exhausted)" do
    it "degrades the assistant to routed_to_nurse and opens a cockpit task, per Section 6 #1 / AT-9" do
      episode = create(:episode)
      caregiver = create(:caregiver, episode: episode)
      conversation = create(:assistant_conversation, episode: episode, caregiver: caregiver)

      allow(Domain::Ai::Gateway).to receive_messages(
        primary_provider: instance_double(Domain::Ai::Providers::Base, name: "p", configured?: true).tap { |d|
          allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "LLM down")
        },
        fallback_provider: instance_double(Domain::Ai::Providers::Base, name: "f", configured?: true).tap { |d|
          allow(d).to receive(:chat).and_raise(Domain::Ai::Providers::Base::ProviderError, "LLM down")
        }
      )

      result = Domain::Ai::Gateway.assistant_reply(
        episode: episode, caregiver: caregiver, conversation: conversation, language: "en", message: "how am I doing?"
      )

      expect(result.degraded).to be true
      expect(result.routed).to be true
      expect(result.text).to be_present # UI still gets a calm, grounded response beneath — never a raw error
      expect(Flag.find(result.routed_flag_id).state).to eq("open") # cockpit task opened
    end
  end

  describe "drill: push down (simulated push delivery failure)" do
    it "falls back to SMS immediately on a simulated push failure, per AT-3 ('SMS fallback on simulated push failure')" do
      caregiver = create(:caregiver)
      caregiver.update!(contact_data: { "phone" => "+491234567" })
      flag = create(:flag, episode: caregiver.episode, severity: "red")

      allow_any_instance_of(Domain::Notifications::Adapters::WebPushAdapter).to receive(:send!).and_return(false)

      expect { Domain::Notifications::FallbackChain.start_red_chain!(flag: flag) }
        .to change(NotificationAttempt, :count).by(2) # the failed webpush attempt + the SMS fallback
        .and change(AuditEvent, :count).by(1)

      attempts = NotificationAttempt.where(flag: flag).order(:created_at)
      expect(attempts.first).to have_attributes(channel: "webpush", state: "failed")
      expect(attempts.last).to have_attributes(channel: "sms", kind: "red_escalation")
      expect(AuditEvent.last.action).to eq("flag.escalation_sms_sent")
    end

    it "still escalates to SMS if a push is silently unconfirmed for the full 5-minute window (the pre-existing, slower path)" do
      caregiver = create(:caregiver)
      caregiver.update!(contact_data: { "phone" => "+491234567" })
      flag = create(:flag, episode: caregiver.episode, severity: "red")
      attempt = create(:notification_attempt, caregiver: caregiver, flag: flag,
        kind: "red_escalation", channel: "webpush", state: "sent")
      attempt.update_column(:created_at, 6.minutes.ago)

      expect { PushConfirmWatchJob.new.perform }
        .to change(NotificationAttempt, :count).by(1)
        .and change(AuditEvent, :count).by(1)

      expect(NotificationAttempt.last.channel).to eq("sms")
    end
  end

  describe "drill: redis down (Sidekiq enqueue unreachable)" do
    it "still completes and persists a knowledge-doc approval instead of 500ing, per AT-9-style graceful degradation" do
      doc = create(:knowledge_doc, status: "in_review", approvals: [ { "user_ref" => 1, "at" => Time.current.iso8601 } ])
      second_approver = create(:user)

      allow(KnowledgeChunkingJob).to receive(:perform_async).and_raise(StandardError.new("Redis::CannotConnectError: connection refused"))

      result = nil
      expect(Rails.logger).to receive(:error).with(/KnowledgeChunkingJob enqueue failed/)
      expect { result = doc.approve!(second_approver) }.not_to raise_error

      expect(result).to be true
      expect(doc.reload.status).to eq("approved") # the approval itself survives Redis being down
    end
  end
end
