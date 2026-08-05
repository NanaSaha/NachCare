require "rails_helper"

RSpec.describe "Api::V1::Staff::CarePlans", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let(:nurse) { create(:user, role: "nurse", site: site) }
  let(:physician) { create(:user, role: "physician", site: site) }
  let!(:original_plan) { create(:care_plan, episode: episode, version: 1, active: true, diet_rules: "original", thresholds: { "x" => 1 }) }

  describe "POST /api/v1/staff/episodes/:episode_id/care_plan" do
    it "creates a new version and deactivates the previous one" do
      post "/api/v1/staff/episodes/#{episode.id}/care_plan", params: { diet_rules: "low salt" },
        headers: staff_auth_header(nurse), as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["version"]).to eq(2)
      expect(original_plan.reload.active).to be false
      expect(episode.care_plans.find_by(active: true).diet_rules).to eq("low salt")
    end

    it "carries forward thresholds unchanged when a nurse edits non-threshold fields" do
      post "/api/v1/staff/episodes/#{episode.id}/care_plan", params: { diet_rules: "low salt" },
        headers: staff_auth_header(nurse), as: :json

      new_plan = episode.care_plans.find_by(active: true)
      expect(new_plan.thresholds).to eq({ "x" => 1 })
    end

    it "allows a physician to change thresholds" do
      post "/api/v1/staff/episodes/#{episode.id}/care_plan", params: { thresholds: { "x" => 2 } },
        headers: staff_auth_header(physician), as: :json

      expect(response).to have_http_status(:created)
      expect(episode.care_plans.find_by(active: true).thresholds).to eq({ "x" => 2 })
    end

    it "forbids a nurse from changing thresholds (FR-N8, physician-gated)" do
      post "/api/v1/staff/episodes/#{episode.id}/care_plan", params: { thresholds: { "x" => 999 } },
        headers: staff_auth_header(nurse), as: :json

      expect(response).to have_http_status(:forbidden)
      expect(episode.care_plans.count).to eq(1) # no new version created
    end

    it "creates medications on the new version" do
      post "/api/v1/staff/episodes/#{episode.id}/care_plan",
        params: { medications: [ { name: "Bisoprolol", critical: true } ] },
        headers: staff_auth_header(nurse), as: :json

      new_plan = episode.care_plans.find_by(active: true)
      expect(new_plan.medications.pluck(:name, :critical)).to eq([ [ "Bisoprolol", true ] ])
    end

    it "records an audit event" do
      expect {
        post "/api/v1/staff/episodes/#{episode.id}/care_plan", params: { diet_rules: "x" },
          headers: staff_auth_header(nurse), as: :json
      }.to change(AuditEvent, :count).by(1)

      expect(AuditEvent.last.action).to eq("care_plan.versioned")
    end

    # Product-owner request (post-M7, ADR-0010): nurse-authored home care
    # instructions, same permission level as diet_rules (a nurse, not just
    # a physician, may set it).
    it "lets a nurse set care_instructions" do
      post "/api/v1/staff/episodes/#{episode.id}/care_plan", params: { care_instructions: "Weigh every morning." },
        headers: staff_auth_header(nurse), as: :json

      expect(response).to have_http_status(:created)
      expect(response.parsed_body["care_instructions"]).to eq("Weigh every morning.")
      expect(episode.care_plans.find_by(active: true).care_instructions).to eq("Weigh every morning.")
    end

    it "carries forward care_instructions unchanged when a nurse edits an unrelated field" do
      original_plan.update!(care_instructions: "Original instructions")

      post "/api/v1/staff/episodes/#{episode.id}/care_plan", params: { diet_rules: "low salt" },
        headers: staff_auth_header(nurse), as: :json

      expect(episode.care_plans.find_by(active: true).care_instructions).to eq("Original instructions")
    end

    it "carries forward existing medications (with their schedule) when a nurse edits an unrelated field" do
      create(:medication, care_plan: original_plan, name: "Furosemide", critical: true,
        schedule: { "times" => [ "08:00" ], "instructions" => "with food" })

      post "/api/v1/staff/episodes/#{episode.id}/care_plan", params: { diet_rules: "low salt" },
        headers: staff_auth_header(nurse), as: :json

      new_plan = episode.care_plans.find_by(active: true)
      expect(new_plan.medications.pluck(:name)).to eq([ "Furosemide" ])
      expect(new_plan.medications.first.schedule).to eq({ "times" => [ "08:00" ], "instructions" => "with food" })
    end

    it "persists a medication's schedule when medications are explicitly provided" do
      post "/api/v1/staff/episodes/#{episode.id}/care_plan",
        params: { medications: [ { name: "Furosemide", critical: true, schedule: { times: [ "08:00", "20:00" ], instructions: "1 tablet" } } ] },
        headers: staff_auth_header(nurse), as: :json

      new_plan = episode.care_plans.find_by(active: true)
      expect(new_plan.medications.first.schedule).to eq({ "times" => [ "08:00", "20:00" ], "instructions" => "1 tablet" })
    end
  end
end
