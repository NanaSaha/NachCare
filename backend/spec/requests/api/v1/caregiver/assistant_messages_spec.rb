require "rails_helper"

RSpec.describe "Api::V1::Caregiver::AssistantMessages", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let!(:caregiver) { create(:caregiver, episode: episode) }
  let(:device_token) do
    Domain::Enrollment::Activator.activate_caregiver!(
      code: Domain::Enrollment::Activator.generate!(episode: episode, role: "primary").plaintext_code
    ).plaintext_device_token
  end
  let(:auth_header) { { "Authorization" => "Bearer #{device_token}" } }

  before do
    caregiver.consents.create!(kind: "c", version: "1", granted: true, timestamp: Time.current)
  end

  describe "POST /api/v1/caregiver/assistant_messages" do
    it "requires a device token" do
      post "/api/v1/caregiver/assistant_messages", params: { message: "hi" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "is forbidden when consent (c) has not been granted" do
      caregiver.consents.destroy_all
      post "/api/v1/caregiver/assistant_messages", params: { message: "hi" }, headers: auth_header, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "is forbidden when the AI_ASSISTANT_ENABLED kill switch is off" do
      allow(ENV).to receive(:fetch).and_call_original
      allow(ENV).to receive(:fetch).with("AI_ASSISTANT_ENABLED", "true").and_return("false")

      post "/api/v1/caregiver/assistant_messages", params: { message: "hi" }, headers: auth_header, as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "creates a conversation and both turns, returning the assistant's reply" do
      post "/api/v1/caregiver/assistant_messages", params: { message: "how do I log a symptom?" }, headers: auth_header, as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["caregiver_turn"]["role"]).to eq("caregiver")
      expect(body["assistant_turn"]["role"]).to eq("assistant")
      expect(AssistantConversation.count).to eq(1)
      expect(AssistantTurn.count).to eq(2)
    end

    it "opens a flag and marks the turn routed for a medication question" do
      post "/api/v1/caregiver/assistant_messages", params: { message: "should I skip today's dose?" }, headers: auth_header, as: :json

      body = response.parsed_body
      expect(body["assistant_turn"]["routed"]).to be true
      expect(Flag.count).to eq(1)
    end
  end

  describe "POST /api/v1/caregiver/assistant_messages/:id/escalate (one-tap send-to-nurse)" do
    it "opens a manual flag and tags the turn" do
      post "/api/v1/caregiver/assistant_messages", params: { message: "how do I log a symptom?" }, headers: auth_header, as: :json
      turn_id = response.parsed_body["assistant_turn"]["id"]

      expect {
        post "/api/v1/caregiver/assistant_messages/#{turn_id}/escalate", headers: auth_header
      }.to change(Flag, :count).by(1)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["flag_id"]).to be_present
      expect(AssistantTurn.find(turn_id).guardrail_verdicts["manually_escalated_flag_id"]).to eq(response.parsed_body["flag_id"])
    end

    it "does not allow escalating another caregiver's turn" do
      other_episode = create(:episode, patient: create(:patient, site: site))
      other_caregiver = create(:caregiver, episode: other_episode)
      other_conversation = create(:assistant_conversation, episode: other_episode, caregiver: other_caregiver)
      other_turn = create(:assistant_turn, assistant_conversation: other_conversation, role: "assistant")

      post "/api/v1/caregiver/assistant_messages/#{other_turn.id}/escalate", headers: auth_header
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "GET /api/v1/caregiver/assistant_messages" do
    it "lists the conversation's turns in order" do
      post "/api/v1/caregiver/assistant_messages", params: { message: "hi" }, headers: auth_header, as: :json

      get "/api/v1/caregiver/assistant_messages", headers: auth_header

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["turns"].size).to eq(2)
    end
  end
end
