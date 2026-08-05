require "rails_helper"

RSpec.describe "Api::V1::Staff::Reports (T-REPORT)", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let(:nurse) { create(:user, role: "nurse", site: site) }

  it "returns a generated episode report" do
    get "/api/v1/staff/episodes/#{episode.id}/report", headers: staff_auth_header(nurse)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["report"]).to be_present
  end
end
