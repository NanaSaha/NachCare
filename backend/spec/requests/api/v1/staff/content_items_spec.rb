require "rails_helper"

RSpec.describe "Api::V1::Staff::ContentItems", type: :request do
  let(:site) { create(:site) }
  let(:nurse) { create(:user, role: "nurse", site: site) }
  let(:physician) { create(:user, role: "physician", site: site) }
  let(:ward_nurse) { create(:user, role: "ward_nurse", site: site) }

  describe "POST /api/v1/staff/content_items" do
    it "creates a draft item" do
      post "/api/v1/staff/content_items",
        params: { kind: "article", week_no: 2, language_variants: { en: { title: "Week 2", body: "text" } } },
        headers: staff_auth_header(nurse), as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["status"]).to eq("draft")
      expect(response.parsed_body["week_no"]).to eq(2)
    end
  end

  describe "POST /api/v1/staff/content_items/:id/approve" do
    it "requires a second distinct approver to reach approved (mirrors FR-N15)" do
      item = create(:content_item, status: "draft")

      post "/api/v1/staff/content_items/#{item.id}/approve", headers: staff_auth_header(nurse)
      expect(response.parsed_body["status"]).to eq("in_review")

      post "/api/v1/staff/content_items/#{item.id}/approve", headers: staff_auth_header(physician)
      expect(response.parsed_body["status"]).to eq("approved")
    end

    it "forbids ward_nurse from approving (ADR-0003: discharge-side only)" do
      item = create(:content_item, status: "draft")
      post "/api/v1/staff/content_items/#{item.id}/approve", headers: staff_auth_header(ward_nurse)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "GET /api/v1/staff/content_items" do
    it "lists items regardless of status (staff-side CMS view)" do
      create(:content_item, kind: "article", week_no: 1, status: "draft")
      create(:content_item, kind: "tip", week_no: 2, status: "approved")

      get "/api/v1/staff/content_items", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.size).to eq(2)
    end
  end
end
