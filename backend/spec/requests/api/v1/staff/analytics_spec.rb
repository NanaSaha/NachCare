require "rails_helper"

RSpec.describe "Api::V1::Staff::Analytics", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:nurse) { create(:user, role: "nurse", site: site) }
  let(:analyst) { create(:user, role: "analyst", site: site) }

  describe "GET /api/v1/staff/analytics/pilot_metrics" do
    it "returns the five pilot metrics scoped to the staff member's own site" do
      episode = create(:episode, patient: patient)
      create(:flag, episode: episode, severity: "red", state: "resolved", breach: false)

      get "/api/v1/staff/analytics/pilot_metrics", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["site_id"]).to eq(site.id)
      expect(body.keys).to include(
        "site_id", "from", "to", "checkin_adherence_rate", "red_flag_sla_compliance_rate",
        "red_flag_median_time_to_first_action_minutes", "program_completion_rate",
        "assistant_safety_routing_rate"
      )
      expect(body["red_flag_sla_compliance_rate"]).to eq(1.0)
    end

    it "allows the read-only analyst role" do
      get "/api/v1/staff/analytics/pilot_metrics", headers: staff_auth_header(analyst)
      expect(response).to have_http_status(:ok)
    end

    it "forbids staff from another site requesting this site explicitly" do
      other = create(:user, role: "nurse", site: create(:site))
      get "/api/v1/staff/analytics/pilot_metrics", params: { site_id: site.id }, headers: staff_auth_header(other)
      expect(response).to have_http_status(:forbidden)
    end

    it "accepts a from/to date range" do
      get "/api/v1/staff/analytics/pilot_metrics", params: { from: 30.days.ago.to_date.iso8601, to: Date.current.iso8601 },
        headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["from"]).to eq(30.days.ago.to_date.iso8601)
    end

    it "defaults to the trailing 30 days when no range is given" do
      get "/api/v1/staff/analytics/pilot_metrics", headers: staff_auth_header(nurse)
      expect(response.parsed_body["from"]).to eq(30.days.ago.to_date.iso8601)
      expect(response.parsed_body["to"]).to eq(Date.current.iso8601)
    end
  end

  describe "GET /api/v1/staff/analytics/pilot_metrics.csv" do
    it "renders a CSV export" do
      get "/api/v1/staff/analytics/pilot_metrics.csv", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("text/csv")
      expect(response.body).to include("metric,value")
      expect(response.body).to include("checkin_adherence_rate")
    end
  end

  describe "GET /api/v1/staff/analytics/pilot_metrics.pdf" do
    it "renders a PDF export" do
      get "/api/v1/staff/analytics/pilot_metrics.pdf", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to eq("application/pdf")
      expect(response.body).to start_with("%PDF")
    end
  end
end
