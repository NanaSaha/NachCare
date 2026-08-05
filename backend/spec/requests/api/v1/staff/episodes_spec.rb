require "rails_helper"

RSpec.describe "Api::V1::Staff::Episodes", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:nurse) { create(:user, role: "nurse", site: site) }
  let(:ward_nurse) { create(:user, role: "ward_nurse", site: site) }
  let(:other_site_nurse) { create(:user, role: "nurse", site: create(:site)) }

  describe "POST /api/v1/staff/episodes/:id/graduate" do
    it "graduates an eligible episode and returns the milestones snapshot" do
      episode = create(:episode, patient: patient, start_date: 90.days.ago.to_date)
      create(:caregiver, episode: episode)

      post "/api/v1/staff/episodes/#{episode.id}/graduate", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["status"]).to eq("graduated")
      expect(body["milestones"]).to have_key("graduated_at")
      expect(episode.reload.status).to eq("graduated")
    end

    it "rejects graduation before day 90" do
      episode = create(:episode, patient: patient, start_date: 10.days.ago.to_date)

      post "/api/v1/staff/episodes/#{episode.id}/graduate", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body["error"]).to eq("not_eligible")
      expect(episode.reload.status).to eq("active")
    end

    it "forbids ward_nurse (ADR-0003: discharge-side only)" do
      episode = create(:episode, patient: patient, start_date: 90.days.ago.to_date)

      post "/api/v1/staff/episodes/#{episode.id}/graduate", headers: staff_auth_header(ward_nurse)

      expect(response).to have_http_status(:forbidden)
    end

    it "forbids staff at another site" do
      episode = create(:episode, patient: patient, start_date: 90.days.ago.to_date)

      post "/api/v1/staff/episodes/#{episode.id}/graduate", headers: staff_auth_header(other_site_nurse)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
