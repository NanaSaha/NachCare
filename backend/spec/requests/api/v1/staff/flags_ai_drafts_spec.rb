require "rails_helper"

RSpec.describe "Api::V1::Staff::Flags AI drafts (T-TRIAGE / T-CALLNOTE)", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let(:nurse) { create(:user, role: "nurse", site: site) }
  let(:flag) { create(:flag, episode: episode, severity: "yellow") }

  describe "GET /api/v1/staff/flags/:id/triage_draft" do
    it "returns an AI-drafted note" do
      get "/api/v1/staff/flags/#{flag.id}/triage_draft", headers: staff_auth_header(nurse)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["draft"]).to be_present
    end
  end

  describe "GET /api/v1/staff/flags/:id/callnote_draft" do
    it "returns an AI-drafted call note prefill" do
      get "/api/v1/staff/flags/#{flag.id}/callnote_draft", headers: staff_auth_header(nurse)
      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["draft"]).to be_present
    end
  end

  describe "PATCH /api/v1/staff/flags/:id with note_ai + note (ai_accept_ratio tracking)" do
    it "records the intervention's ai_accept_ratio from note_ai vs the nurse's final note" do
      patch "/api/v1/staff/flags/#{flag.id}", params: { note_ai: "call about fluids", note: "call about fluids" },
        headers: staff_auth_header(nurse), as: :json

      expect(response).to have_http_status(:ok)
      intervention = Intervention.last
      expect(intervention.note_ai).to eq("call about fluids")
      expect(intervention.ai_accept_ratio.to_f).to eq(1.0)
    end
  end
end
