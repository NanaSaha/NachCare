require "rails_helper"

RSpec.describe "Api::V1::Staff::Enrollments", type: :request do
  let(:site) { create(:site) }
  let(:nurse) { create(:user, role: "nurse", site: site) }
  let(:analyst) { create(:user, role: "analyst", site: site) }

  let(:valid_params) do
    {
      patient: { initials: "I.M.", birth_year: 1950, nyha_class: "II" },
      caregiver: { display_name: "Sabine", relationship: "daughter", language: "en" },
      medications: [ "Ramipril", "Bisoprolol", "SomeUnlistedDrug" ]
    }
  end

  before do
    Drug.find_or_create_by!(name: "Ramipril") { |d| d.category = "ACE inhibitor" }
    Drug.find_or_create_by!(name: "Bisoprolol") { |d| d.category = "Beta blocker" }
  end

  describe "POST /api/v1/staff/enrollments" do
    it "creates patient, episode, caregiver, care plan, medications, and an activation code" do
      expect {
        post "/api/v1/staff/enrollments", params: valid_params, headers: staff_auth_header(nurse), as: :json
      }.to change(Patient, :count).by(1)
        .and change(Episode, :count).by(1)
        .and change(Caregiver, :count).by(1)
        .and change(CarePlan, :count).by(1)
        .and change(Medication, :count).by(3)
        .and change(ActivationCode, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body

      expect(body["patient"]["initials"]).to eq("I.M.")
      expect(body["caregiver"]["display_name"]).to eq("Sabine")
      expect(body["caregiver"]).not_to have_key("device_token_digest")
      expect(body["activation_code"]["code"].length).to eq(8)
      expect(body["activation_code"]["role"]).to eq("primary")
    end

    it "links medications to the local drug table when the name matches" do
      post "/api/v1/staff/enrollments", params: valid_params, headers: staff_auth_header(nurse), as: :json

      care_plan = CarePlan.last
      ramipril = care_plan.medications.find_by(name: "Ramipril")
      unlisted = care_plan.medications.find_by(name: "SomeUnlistedDrug")

      expect(ramipril.drug).to eq(Drug.find_by(name: "Ramipril"))
      expect(unlisted.drug).to be_nil # free-text fallback, not in the local list
    end

    it "records an audit event" do
      expect {
        post "/api/v1/staff/enrollments", params: valid_params, headers: staff_auth_header(nurse), as: :json
      }.to change(AuditEvent, :count).by(1)

      expect(AuditEvent.last.action).to eq("episode.enrolled")
    end

    it "scopes the new patient to the enrolling nurse's site" do
      post "/api/v1/staff/enrollments", params: valid_params, headers: staff_auth_header(nurse), as: :json
      expect(Patient.last.site_ref).to eq(site.id)
    end

    it "forbids roles that cannot enroll (analyst)" do
      post "/api/v1/staff/enrollments", params: valid_params, headers: staff_auth_header(analyst), as: :json
      expect(response).to have_http_status(:forbidden)
    end

    it "requires authentication" do
      post "/api/v1/staff/enrollments", params: valid_params, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 422 for an invalid nyha_class rather than a 500" do
      bad_params = valid_params.deep_merge(patient: { nyha_class: "V" })
      post "/api/v1/staff/enrollments", params: bad_params, headers: staff_auth_header(nurse), as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "GET /api/v1/staff/enrollments/:episode_id/code_sheet" do
    it "renders a PDF using the code the client already has" do
      post "/api/v1/staff/enrollments", params: valid_params, headers: staff_auth_header(nurse), as: :json
      episode_id = response.parsed_body["episode"]["id"]
      code = response.parsed_body["activation_code"]["code"]
      expires_at = response.parsed_body["activation_code"]["expires_at"]

      get "/api/v1/staff/enrollments/#{episode_id}/code_sheet",
        params: { code: code, role: "primary", expires_at: expires_at },
        headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/pdf")
      expect(response.body).to start_with("%PDF")
    end

    it "forbids staff from another site" do
      post "/api/v1/staff/enrollments", params: valid_params, headers: staff_auth_header(nurse), as: :json
      episode_id = response.parsed_body["episode"]["id"]

      other_site_nurse = create(:user, role: "nurse", site: create(:site))
      get "/api/v1/staff/enrollments/#{episode_id}/code_sheet",
        params: { code: "AAAAAAAA" }, headers: staff_auth_header(other_site_nurse)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
