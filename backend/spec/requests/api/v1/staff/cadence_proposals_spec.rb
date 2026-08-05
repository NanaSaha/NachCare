require "rails_helper"

RSpec.describe "Api::V1::Staff::CadenceProposals", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let(:nurse) { create(:user, role: "nurse", site: site) }

  describe "GET /api/v1/staff/episodes/:episode_id/cadence_proposals" do
    it "returns no proposal pre-promotion" do
      get "/api/v1/staff/episodes/#{episode.id}/cadence_proposals", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body).to eq([])
    end

    it "computes and returns a fresh taper proposal for a stable low-risk episode once promoted" do
      create(:risk_model_promotion, site: site, promoted: true)
      4.times { |i| create(:risk_score, episode: episode, check_in: create(:check_in, episode: episode, effective_date: Date.current - i), score: 0.05) }

      get "/api/v1/staff/episodes/#{episode.id}/cadence_proposals", headers: staff_auth_header(nurse)

      body = response.parsed_body
      expect(body.size).to eq(1)
      expect(body.first["direction"]).to eq("taper")
      expect(body.first["status"]).to eq("pending")
    end

    it "is forbidden for staff at a different site" do
      other = create(:user, role: "nurse", site: create(:site))
      get "/api/v1/staff/episodes/#{episode.id}/cadence_proposals", headers: staff_auth_header(other)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST .../approve" do
    it "creates a new care-plan version with the proposed cadence" do
      create(:care_plan, episode: episode, active: true, version: 1)
      proposal = create(:cadence_proposal, episode: episode, proposed_cadence: { "times_per_week" => 3 })

      post "/api/v1/staff/episodes/#{episode.id}/cadence_proposals/#{proposal.id}/approve", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["care_plan_version"]).to eq(2)
      expect(proposal.reload.status).to eq("approved")
      expect(episode.care_plans.find_by(active: true).cadence).to eq({ "times_per_week" => 3 })
    end
  end

  describe "POST .../dismiss" do
    it "marks the proposal dismissed" do
      proposal = create(:cadence_proposal, episode: episode)

      post "/api/v1/staff/episodes/#{episode.id}/cadence_proposals/#{proposal.id}/dismiss", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      expect(proposal.reload.status).to eq("dismissed")
    end
  end
end
