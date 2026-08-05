require "rails_helper"

RSpec.describe "Api::V1::Caregiver::CareTeam", type: :request do
  let(:site) { create(:site, name: "Charité Test Site") }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let!(:caregiver) { create(:caregiver, episode: episode) }
  let(:device_token) do
    Domain::Enrollment::Activator.activate_caregiver!(
      code: Domain::Enrollment::Activator.generate!(episode: episode, role: "primary").plaintext_code
    ).plaintext_device_token
  end
  let(:auth_header) { { "Authorization" => "Bearer #{device_token}" } }

  it "requires authentication" do
    get "/api/v1/caregiver/care_team"
    expect(response).to have_http_status(:unauthorized)
  end

  it "returns the site name (R4: the emergency block itself is static, rendered client-side with no API dependency)" do
    get "/api/v1/caregiver/care_team", headers: auth_header

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["site_name"]).to eq("Charité Test Site")
  end
end
