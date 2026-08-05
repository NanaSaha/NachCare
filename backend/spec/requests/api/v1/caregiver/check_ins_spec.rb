require "rails_helper"

RSpec.describe "Api::V1::Caregiver::CheckIns", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let!(:caregiver) { create(:caregiver, episode: episode) }
  let!(:ruleset) do
    create(:ruleset, version: "test-active", status: "active", body: {
      "version" => "test-active",
      "rules" => [
        { "id" => "R-1", "key" => "breathless", "severity" => "red",
          "condition" => { "type" => "symptom_toggle", "symptom_key" => "breathless_at_rest" } }
      ]
    })
  end

  let(:device_token) do
    Domain::Enrollment::Activator.activate_caregiver!(
      code: Domain::Enrollment::Activator.generate!(episode: episode, role: "primary").plaintext_code
    ).plaintext_device_token
  end
  let(:auth_header) { { "Authorization" => "Bearer #{device_token}" } }

  describe "POST /api/v1/caregiver/check_ins" do
    it "requires a valid device token" do
      post "/api/v1/caregiver/check_ins", params: { client_uuid: SecureRandom.uuid }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a check-in, evaluates it, and reports the severity" do
      post "/api/v1/caregiver/check_ins", params: {
        client_uuid: SecureRandom.uuid, effective_date: Date.current, weight_kg: 70.5,
        symptoms: { breathless_at_rest: true }, med_status: {}
      }, headers: auth_header, as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["check_in"]["weight_kg"]).to eq("70.5")
      expect(body["evaluation"]["severity"]).to eq("red")

      expect(CheckIn.count).to eq(1)
      expect(Flag.count).to eq(1)
    end

    it "broadcasts a nurse alert (product-owner feedback item #4, ADR-0011)" do
      expect(ActionCable.server).to receive(:broadcast).with("nurse_alerts_site_#{site.id}", hash_including(type: "check_in"))
      allow(ActionCable.server).to receive(:broadcast).with(a_string_matching(/\Acare_activity_episode_/), anything)

      post "/api/v1/caregiver/check_ins", params: {
        client_uuid: SecureRandom.uuid, effective_date: Date.current, weight_kg: 70.5, symptoms: {}, med_status: {}
      }, headers: auth_header, as: :json
    end

    it "is idempotent on client_uuid — a repeat POST does not create a second check-in" do
      client_uuid = SecureRandom.uuid
      params = { client_uuid: client_uuid, effective_date: Date.current, weight_kg: 70.0, symptoms: {}, med_status: {} }

      post "/api/v1/caregiver/check_ins", params: params, headers: auth_header, as: :json
      expect(response).to have_http_status(:created)

      post "/api/v1/caregiver/check_ins", params: params, headers: auth_header, as: :json
      expect(response).to have_http_status(:ok)

      expect(CheckIn.count).to eq(1)
    end

    it "computes a shadow risk score for every check-in, invisibly (UC-05)" do
      post "/api/v1/caregiver/check_ins", params: {
        client_uuid: SecureRandom.uuid, effective_date: Date.current, weight_kg: 70.5, symptoms: {}, med_status: {}
      }, headers: auth_header, as: :json

      body = response.parsed_body
      expect(RiskScore.count).to eq(1)
      expect(RiskScore.last.rules_severity).to eq("green")
      # Never surfaced: no risk-score field anywhere in the response, and
      # no ai_watch card pre-promotion.
      expect(body).not_to have_key("risk_score")
      expect(body["ai_watch"]).to be_nil
    end

    it "returns an AI-generated (or gracefully-degraded template) daily brief on a green result" do
      post "/api/v1/caregiver/check_ins", params: {
        client_uuid: SecureRandom.uuid, effective_date: Date.current, weight_kg: 70.5, symptoms: {}, med_status: {}
      }, headers: auth_header, as: :json

      body = response.parsed_body
      expect(body["evaluation"]["severity"]).to eq("green")
      expect(body["brief"]["text"]).to be_present
      expect(body["brief"]["source"]).to eq("ai") # StubProvider is configured in test env
    end

    it "does not return a brief on a non-green result" do
      post "/api/v1/caregiver/check_ins", params: {
        client_uuid: SecureRandom.uuid, effective_date: Date.current, weight_kg: 70.5,
        symptoms: { breathless_at_rest: true }, med_status: {}
      }, headers: auth_header, as: :json

      expect(response.parsed_body["evaluation"]["severity"]).to eq("red")
      expect(response.parsed_body["brief"]).to be_nil
    end

    it "opens a real AI WATCH flag on a green check-in with a risk-worthy trajectory, once the site is promoted" do
      create(:risk_model_promotion, site: site, promoted: true)
      care_plan = create(:care_plan, episode: episode, active: true)
      med = create(:medication, care_plan: care_plan, critical: true)
      6.downto(1) do |n|
        create(:check_in, episode: episode, caregiver: caregiver, effective_date: Date.current - n, weight_kg: 68.0,
          med_status: { med.id.to_s => "missed" })
      end

      post "/api/v1/caregiver/check_ins", params: {
        client_uuid: SecureRandom.uuid, effective_date: Date.current, weight_kg: 70.0, symptoms: {}, med_status: {}
      }, headers: auth_header, as: :json

      expect(response.parsed_body["evaluation"]["severity"]).to eq("green")
      expect(response.parsed_body["ai_watch"]).to eq({ "opened" => true })
      expect(Flag.where(subtype: "ai_watch").count).to eq(1)
    end

    it "scopes the check-in to the authenticated caregiver's own episode" do
      post "/api/v1/caregiver/check_ins", params: {
        client_uuid: SecureRandom.uuid, effective_date: Date.current, weight_kg: 70.0
      }, headers: auth_header, as: :json

      expect(CheckIn.last.episode_ref).to eq(episode.id)
      expect(CheckIn.last.caregiver_ref).to eq(caregiver.id)
    end
  end

  describe "PATCH /api/v1/caregiver/check_ins/:id (FR-C16 correction window)" do
    it "supersedes the original with a new check-in inside the 30-min window" do
      post "/api/v1/caregiver/check_ins", params: {
        client_uuid: SecureRandom.uuid, effective_date: Date.current, weight_kg: 70.0, symptoms: {}
      }, headers: auth_header, as: :json
      original_id = response.parsed_body["check_in"]["id"]

      patch "/api/v1/caregiver/check_ins/#{original_id}", params: {
        client_uuid: SecureRandom.uuid, effective_date: Date.current, weight_kg: 71.0,
        symptoms: { breathless_at_rest: true }
      }, headers: auth_header, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["evaluation"]["severity"]).to eq("red")

      original = CheckIn.find(original_id)
      expect(original.superseded_by).to eq(response.parsed_body["check_in"]["id"])
      expect(CheckIn.count).to eq(2)
    end

    it "rejects a correction after the 30-min window" do
      check_in = create(:check_in, episode: episode, caregiver: caregiver, submitted_at: 31.minutes.ago)

      patch "/api/v1/caregiver/check_ins/#{check_in.id}", params: {
        client_uuid: SecureRandom.uuid, effective_date: Date.current, weight_kg: 71.0
      }, headers: auth_header, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(check_in.reload.superseded_by).to be_nil
    end

    it "cannot correct another episode's check-in" do
      other_episode = create(:episode)
      other_caregiver = create(:caregiver, episode: other_episode)
      other_check_in = create(:check_in, episode: other_episode, caregiver: other_caregiver)

      patch "/api/v1/caregiver/check_ins/#{other_check_in.id}", params: {
        client_uuid: SecureRandom.uuid, weight_kg: 71.0
      }, headers: auth_header, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
