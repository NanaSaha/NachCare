require "rails_helper"

RSpec.describe "Api::V1::Caregiver::Messages", type: :request do
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

  describe "GET /api/v1/caregiver/messages" do
    it "requires a valid device token" do
      get "/api/v1/caregiver/messages", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "lists the caregiver's own episode messages in order" do
      first = create(:message, episode: episode, body_source: "first", created_at: 2.hours.ago)
      second = create(:message, episode: episode, body_source: "second", created_at: 1.hour.ago)
      create(:message, episode: create(:episode, patient: create(:patient, site: site)), body_source: "other episode")

      get "/api/v1/caregiver/messages", headers: auth_header, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.map { |m| m["id"] }).to eq([ first.id, second.id ])
    end
  end

  # Product-owner feedback item #3 (ADR-0011): caregiver-authored status
  # update, optional media attachment.
  describe "POST /api/v1/caregiver/messages" do
    it "requires a valid device token" do
      post "/api/v1/caregiver/messages", params: { body_source: "she's doing well today" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a caregiver-sent message" do
      post "/api/v1/caregiver/messages", params: { body_source: "she's doing well today" }, headers: auth_header

      expect(response).to have_http_status(:created)
      expect(Message.last.sender).to eq("caregiver")
      expect(Message.last.body_source).to eq("she's doing well today")
      expect(Message.last.episode_ref).to eq(episode.id)
    end

    it "accepts a media-only status update with an attachment and no text" do
      photo = fixture_file_upload("test_photo.jpg", "image/jpeg")

      post "/api/v1/caregiver/messages", params: { media: photo }, headers: auth_header

      expect(response).to have_http_status(:created)
      expect(Message.last.media).to be_attached
      expect(response.parsed_body["media_url"]).to be_present
    end

    it "rejects an empty message with neither text nor media" do
      post "/api/v1/caregiver/messages", params: { body_source: "" }, headers: auth_header

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "records an audit event" do
      expect {
        post "/api/v1/caregiver/messages", params: { body_source: "update" }, headers: auth_header
      }.to change(AuditEvent, :count).by(1)
    end
  end
end
