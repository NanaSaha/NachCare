require "rails_helper"

RSpec.describe "Api::V1::Caregiver::CarePlanExplanations", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let!(:caregiver) { create(:caregiver, episode: episode) }
  let!(:care_plan) { create(:care_plan, episode: episode, active: true, care_instructions: "Keep her legs elevated.", diet_rules: "Low salt.") }
  let!(:medication) { create(:medication, care_plan: care_plan, name: "Furosemide", schedule: { "times" => [ "08:00" ], "instructions" => "with breakfast" }) }

  let(:device_token) do
    Domain::Enrollment::Activator.activate_caregiver!(
      code: Domain::Enrollment::Activator.generate!(episode: episode, role: "primary").plaintext_code
    ).plaintext_device_token
  end
  let(:auth_header) { { "Authorization" => "Bearer #{device_token}" } }

  describe "POST /api/v1/caregiver/care_plan/explain" do
    it "requires a valid device token" do
      post "/api/v1/caregiver/care_plan/explain", params: { item_type: "diet_rules" }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "explains a medication by id, scoped to the caregiver's own active care plan" do
      post "/api/v1/caregiver/care_plan/explain",
        params: { item_type: "medication", item_id: medication.id }, headers: auth_header, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["text"]).to be_present
      expect(response.parsed_body["source"]).to eq("ai")
    end

    it "explains the free-text care_instructions" do
      post "/api/v1/caregiver/care_plan/explain",
        params: { item_type: "care_instructions" }, headers: auth_header, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["text"]).to be_present
    end

    it "explains the free-text diet_rules" do
      post "/api/v1/caregiver/care_plan/explain",
        params: { item_type: "diet_rules" }, headers: auth_header, as: :json

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["text"]).to be_present
    end

    it "rejects an invalid item_type" do
      post "/api/v1/caregiver/care_plan/explain",
        params: { item_type: "diagnosis" }, headers: auth_header, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "404s for a medication id belonging to another episode's care plan" do
      other_plan = create(:care_plan, episode: create(:episode, patient: create(:patient, site: site)), active: true)
      other_med = create(:medication, care_plan: other_plan, name: "Other Drug")

      post "/api/v1/caregiver/care_plan/explain",
        params: { item_type: "medication", item_id: other_med.id }, headers: auth_header, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "404s when the requested free-text item is blank" do
      care_plan.update!(diet_rules: nil)

      post "/api/v1/caregiver/care_plan/explain",
        params: { item_type: "diet_rules" }, headers: auth_header, as: :json

      expect(response).to have_http_status(:not_found)
    end
  end
end
