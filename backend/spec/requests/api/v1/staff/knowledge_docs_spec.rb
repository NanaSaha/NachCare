require "rails_helper"

RSpec.describe "Api::V1::Staff::KnowledgeDocs", type: :request do
  let(:site) { create(:site) }
  let(:nurse) { create(:user, role: "nurse", site: site) }
  let(:physician) { create(:user, role: "physician", site: site) }
  let(:ward_nurse) { create(:user, role: "ward_nurse", site: site) }

  describe "POST /api/v1/staff/knowledge_docs" do
    it "creates a draft doc" do
      post "/api/v1/staff/knowledge_docs", params: { title: "Fluid Guide", language: "en", version: 1, body: "text" },
        headers: staff_auth_header(nurse), as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["status"]).to eq("draft")
    end
  end

  describe "POST /api/v1/staff/knowledge_docs/:id/approve" do
    it "requires a second distinct approver to reach approved, then enqueues chunking" do
      doc = create(:knowledge_doc, status: "draft", body: "Some approved text about fluids.")

      post "/api/v1/staff/knowledge_docs/#{doc.id}/approve", headers: staff_auth_header(nurse)
      expect(response.parsed_body["status"]).to eq("in_review")

      post "/api/v1/staff/knowledge_docs/#{doc.id}/approve", headers: staff_auth_header(physician)
      expect(response.parsed_body["status"]).to eq("approved")
    end

    it "does not advance past in_review when the same user approves twice" do
      doc = create(:knowledge_doc, status: "draft")

      post "/api/v1/staff/knowledge_docs/#{doc.id}/approve", headers: staff_auth_header(nurse)
      post "/api/v1/staff/knowledge_docs/#{doc.id}/approve", headers: staff_auth_header(nurse)

      expect(response.parsed_body["status"]).to eq("in_review")
    end

    it "forbids ward_nurse from approving (ADR-0003: discharge-side only)" do
      doc = create(:knowledge_doc, status: "draft")
      post "/api/v1/staff/knowledge_docs/#{doc.id}/approve", headers: staff_auth_header(ward_nurse)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
