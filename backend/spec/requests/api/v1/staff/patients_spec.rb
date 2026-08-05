require "rails_helper"

RSpec.describe "Api::V1::Staff::Patients", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let!(:episode) { create(:episode, patient: patient) }
  let(:nurse) { create(:user, role: "nurse", site: site) }

  describe "GET /api/v1/staff/patients" do
    it "scopes to the staff member's own site" do
      other_patient = create(:patient, site: create(:site))

      get "/api/v1/staff/patients", headers: staff_auth_header(nurse)

      ids = response.parsed_body.map { |p| p["id"] }
      expect(ids).to include(patient.id)
      expect(ids).not_to include(other_patient.id)
    end

    # UC-25 — shadow mode holds here too: no risk_trend at all pre-promotion.
    it "never includes a risk_trend pre-promotion" do
      4.times { |i| create(:risk_score, episode: episode, check_in: create(:check_in, episode: episode, effective_date: Date.current - i), score: 0.6) }

      get "/api/v1/staff/patients", headers: staff_auth_header(nurse)

      row = response.parsed_body.find { |p| p["id"] == patient.id }
      expect(row["risk_trend"]).to be_nil
    end

    it "includes a direction-only risk_trend once the site is promoted" do
      create(:risk_model_promotion, site: site, promoted: true)
      score_at = ->(value, days_ago) do
        ci = create(:check_in, episode: episode, effective_date: Date.current - days_ago)
        create(:risk_score, episode: episode, check_in: ci, score: value, created_at: days_ago.days.ago)
      end
      score_at.call(0.1, 5)
      score_at.call(0.7, 1)

      get "/api/v1/staff/patients", headers: staff_auth_header(nurse)

      row = response.parsed_body.find { |p| p["id"] == patient.id }
      expect(row["risk_trend"]).to eq("rising")
    end
  end

  describe "GET /api/v1/staff/patients/:id" do
    it "returns patient detail including episodes and active care plan" do
      care_plan = create(:care_plan, episode: episode, active: true, diet_rules: "low salt")
      create(:medication, care_plan: care_plan, name: "Ramipril")

      get "/api/v1/staff/patients/#{patient.id}", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["episodes"].first["care_plan"]["diet_rules"]).to eq("low salt")
      expect(body["episodes"].first["care_plan"]["medications"].first["name"]).to eq("Ramipril")
    end

    it "falls back to the latest draft care plan when none is active yet, so a freshly enrolled patient always has one to edit" do
      draft = create(:care_plan, episode: episode, active: false, version: 1, diet_rules: "draft plan")
      create(:medication, care_plan: draft, name: "Ramipril")

      get "/api/v1/staff/patients/#{patient.id}", headers: staff_auth_header(nurse)

      body = response.parsed_body["episodes"].first["care_plan"]
      expect(body["active"]).to be false
      expect(body["diet_rules"]).to eq("draft plan")
      expect(body["medications"].first["name"]).to eq("Ramipril")
    end

    it "prefers the active plan over a newer inactive draft" do
      create(:care_plan, episode: episode, active: true, version: 1, diet_rules: "active plan")
      create(:care_plan, episode: episode, active: false, version: 2, diet_rules: "abandoned draft")

      get "/api/v1/staff/patients/#{patient.id}", headers: staff_auth_header(nurse)

      body = response.parsed_body["episodes"].first["care_plan"]
      expect(body["active"]).to be true
      expect(body["diet_rules"]).to eq("active plan")
    end

    it "records an audit 'who viewed' event" do
      expect { get "/api/v1/staff/patients/#{patient.id}", headers: staff_auth_header(nurse) }
        .to change(AuditEvent, :count).by(1)

      event = AuditEvent.last
      expect(event.action).to eq("patient.viewed")
      expect(event.actor_ref).to eq(nurse.id.to_s)
      expect(event.entity_ref).to eq(patient.id.to_s)
    end

    it "forbids staff at another site" do
      other = create(:user, role: "nurse", site: create(:site))
      get "/api/v1/staff/patients/#{patient.id}", headers: staff_auth_header(other)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
