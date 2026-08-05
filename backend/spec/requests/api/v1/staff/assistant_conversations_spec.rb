require "rails_helper"

RSpec.describe "Api::V1::Staff::AssistantConversations", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let(:nurse) { create(:user, role: "nurse", site: site) }

  it "returns the episode's conversation turns and records an audit view" do
    conversation = create(:assistant_conversation, episode: episode)
    create(:assistant_turn, assistant_conversation: conversation, role: "caregiver", content: "hi")

    expect {
      get "/api/v1/staff/episodes/#{episode.id}/assistant_conversation", headers: staff_auth_header(nurse)
    }.to change(AuditEvent, :count).by(1)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["turns"].size).to eq(1)
  end

  it "returns an empty turn list when the episode has no conversation yet" do
    get "/api/v1/staff/episodes/#{episode.id}/assistant_conversation", headers: staff_auth_header(nurse)

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body["turns"]).to eq([])
  end
end
