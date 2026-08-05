require "rails_helper"

RSpec.describe "Api::V1::Caregiver::Activations", type: :request do
  let(:episode) { create(:episode) }
  let!(:caregiver) { create(:caregiver, episode: episode, display_name: "Sabine") }

  it "exchanges a valid code for a device token" do
    generated = Domain::Enrollment::Activator.generate!(episode: episode, role: "primary")

    post "/api/v1/caregiver/activations", params: { code: generated.plaintext_code }, as: :json

    expect(response).to have_http_status(:created)
    body = response.parsed_body
    expect(body["device_token"]).to be_present
    expect(body["caregiver"]["display_name"]).to eq("Sabine")
    expect(body["caregiver"]).not_to have_key("device_token_digest")
  end

  it "records an audit event with the caregiver as actor" do
    generated = Domain::Enrollment::Activator.generate!(episode: episode, role: "primary")

    expect {
      post "/api/v1/caregiver/activations", params: { code: generated.plaintext_code }, as: :json
    }.to change(AuditEvent, :count).by(1)

    event = AuditEvent.last
    expect(event.actor_type).to eq("caregiver")
    expect(event.actor_ref).to eq(caregiver.id.to_s)
  end

  it "returns 422 for an invalid code, not a 500" do
    post "/api/v1/caregiver/activations", params: { code: "ZZZZZZZZ" }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "returns 422 for a reused code" do
    generated = Domain::Enrollment::Activator.generate!(episode: episode, role: "primary")
    post "/api/v1/caregiver/activations", params: { code: generated.plaintext_code }, as: :json

    post "/api/v1/caregiver/activations", params: { code: generated.plaintext_code }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end
end
