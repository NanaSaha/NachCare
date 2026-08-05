require "rails_helper"

RSpec.describe "Api::V1::Staff::RiskModel", type: :request do
  let(:site) { create(:site) }
  let(:physician) { create(:user, role: "physician", site: site) }
  let(:nurse) { create(:user, role: "nurse", site: site) }

  describe "GET /api/v1/staff/sites/:site_id/risk_model" do
    it "returns honest, live-computed gate numbers — insufficient data in a fresh dev/demo checkout" do
      get "/api/v1/staff/sites/#{site.id}/risk_model", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["promoted"]).to be false
      expect(body["gate_evaluation"]["insufficient_data"]).to be true
      expect(body["gate_evaluation"]["overall_met"]).to be false
    end

    it "is viewable by any staff member at the site (not just MD/ADM)" do
      get "/api/v1/staff/sites/#{site.id}/risk_model", headers: staff_auth_header(nurse)
      expect(response).to have_http_status(:ok)
    end

    it "is forbidden for staff at a different site" do
      other = create(:user, role: "physician", site: create(:site))
      get "/api/v1/staff/sites/#{site.id}/risk_model", headers: staff_auth_header(other)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/staff/sites/:site_id/risk_model/promote" do
    it "is forbidden for a nurse (not an MD/ADM role)" do
      post "/api/v1/staff/sites/#{site.id}/risk_model/promote", headers: staff_auth_header(nurse)
      expect(response).to have_http_status(:forbidden)
    end

    it "does not promote without an override when gates aren't met" do
      post "/api/v1/staff/sites/#{site.id}/risk_model/promote", headers: staff_auth_header(physician)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["promoted"]).to be false
      expect(body["gates_met"]).to be false
    end

    it "promotes via the explicit dev/demo override, audited" do
      expect {
        post "/api/v1/staff/sites/#{site.id}/risk_model/promote", params: { override: true }, headers: staff_auth_header(physician)
      }.to change(AuditEvent, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["promoted"]).to be true
      expect(body["override"]).to be true
      expect(site.reload.ai_watch_promoted?).to be true
    end

    it "allows a site_admin to promote too" do
      admin = create(:user, role: "site_admin", site: site)
      post "/api/v1/staff/sites/#{site.id}/risk_model/promote", params: { override: true }, headers: staff_auth_header(admin)
      expect(response).to have_http_status(:created)
    end
  end
end
