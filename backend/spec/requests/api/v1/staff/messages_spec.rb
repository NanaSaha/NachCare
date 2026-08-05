require "rails_helper"

RSpec.describe "Api::V1::Staff::Messages", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let(:nurse) { create(:user, role: "nurse", site: site) }
  let(:other_site_nurse) { create(:user, role: "nurse", site: create(:site)) }

  describe "GET /api/v1/staff/episodes/:episode_id/messages" do
    it "lists messages for the episode" do
      message = create(:message, episode: episode)

      get "/api/v1/staff/episodes/#{episode.id}/messages", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |m| m["id"] }).to eq([ message.id ])
    end

    it "returns nothing for a nurse at a different site" do
      create(:message, episode: episode)

      get "/api/v1/staff/episodes/#{episode.id}/messages", headers: staff_auth_header(other_site_nurse)

      expect(response.parsed_body).to eq([])
    end
  end

  describe "POST /api/v1/staff/episodes/:episode_id/messages/preview" do
    it "returns a pass-through translation when the target language is English" do
      post "/api/v1/staff/episodes/#{episode.id}/messages/preview",
        params: { body_source: "Hello", language: "en" }, headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["body_source"]).to eq("Hello")
      expect(body["body_translated"]).to eq("Hello")
    end

    it "resolves body_source from a template_key" do
      post "/api/v1/staff/episodes/#{episode.id}/messages/preview",
        params: { template_key: "thank_you", language: "en" }, headers: staff_auth_header(nurse)

      expect(response.parsed_body["body_source"]).to eq(Domain::Messages::Templates::BANK["thank_you"])
    end

    it "returns a real translation for a non-English target via T-TRANSLATE (M5, still show-before-send)" do
      post "/api/v1/staff/episodes/#{episode.id}/messages/preview",
        params: { body_source: "Hello", language: "de" }, headers: staff_auth_header(nurse)

      expect(response.parsed_body["body_translated"]).to be_present
    end

    it "does not persist anything" do
      expect do
        post "/api/v1/staff/episodes/#{episode.id}/messages/preview",
          params: { body_source: "Hello", language: "en" }, headers: staff_auth_header(nurse)
      end.not_to change(Message, :count)
    end
  end

  describe "POST /api/v1/staff/episodes/:episode_id/messages" do
    it "sends the message as reviewed (body_translated exactly as given, not recomputed)" do
      post "/api/v1/staff/episodes/#{episode.id}/messages",
        params: { body_source: "Hello", body_translated: "Edited by nurse", language: "de" },
        headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:created)
      message = Message.last
      expect(message.sender).to eq("nurse")
      expect(message.body_translated).to eq("Edited by nurse")
    end

    it "records an audit event without the message body" do
      expect do
        post "/api/v1/staff/episodes/#{episode.id}/messages",
          params: { body_source: "Hello", language: "en" }, headers: staff_auth_header(nurse)
      end.to change(AuditEvent, :count).by(1)

      expect(AuditEvent.last.action).to eq("message.sent")
      expect(AuditEvent.last.payload).to eq({})
    end

    it "forbids a nurse from a different site" do
      post "/api/v1/staff/episodes/#{episode.id}/messages",
        params: { body_source: "Hello" }, headers: staff_auth_header(other_site_nurse)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
