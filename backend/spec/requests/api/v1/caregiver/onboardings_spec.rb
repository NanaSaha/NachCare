require "rails_helper"

RSpec.describe "Api::V1::Caregiver::Onboardings", type: :request do
  let(:episode) { create(:episode) }
  let!(:caregiver) { create(:caregiver, episode: episode) }
  let(:device_token) do
    Domain::Enrollment::Activator.activate_caregiver!(
      code: Domain::Enrollment::Activator.generate!(episode: episode, role: "primary").plaintext_code
    ).plaintext_device_token
  end
  let(:auth_header) { { "Authorization" => "Bearer #{device_token}" } }

  it "requires a valid device token" do
    patch "/api/v1/caregiver/onboarding", params: { language: "de" }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects a garbage token" do
    patch "/api/v1/caregiver/onboarding", params: { language: "de" },
      headers: { "Authorization" => "Bearer not-a-real-token" }, as: :json
    expect(response).to have_http_status(:unauthorized)
  end

  it "updates language and notification_time" do
    patch "/api/v1/caregiver/onboarding",
      params: { language: "de", notification_time: "08:30" }, headers: auth_header, as: :json

    expect(response).to have_http_status(:ok)
    caregiver.reload
    expect(caregiver.language).to eq("de")
    expect(caregiver.notification_time.strftime("%H:%M")).to eq("08:30")
  end

  it "sets a PIN as a digest, never storing the plaintext" do
    patch "/api/v1/caregiver/onboarding", params: { pin: "4821" }, headers: auth_header, as: :json

    caregiver.reload
    expect(caregiver.pin_digest).to be_present
    expect(caregiver.pin_digest).not_to eq("4821")
    expect(response.parsed_body["pin_set"]).to be true
  end

  it "records granular consents a-d" do
    patch "/api/v1/caregiver/onboarding",
      params: { consents: { a: "true", b: "true", c: "false", d: "true" } }, headers: auth_header, as: :json

    expect(response).to have_http_status(:ok)
    consents = caregiver.consents.order(:kind)
    expect(consents.pluck(:kind, :granted)).to eq([ %w[a true], %w[b true], %w[c false], %w[d true] ].map { |k, g| [ k, g == "true" ] })
  end

  it "ignores unknown consent kinds rather than erroring" do
    patch "/api/v1/caregiver/onboarding", params: { consents: { z: "true" } }, headers: auth_header, as: :json

    expect(response).to have_http_status(:ok)
    expect(caregiver.consents.count).to eq(0)
  end

  it "resubmitting the same consent step does not 500 (idempotent PATCH, e.g. wizard back/retry)" do
    patch "/api/v1/caregiver/onboarding", params: { consents: { a: "true" } }, headers: auth_header, as: :json
    expect(response).to have_http_status(:ok)

    patch "/api/v1/caregiver/onboarding", params: { consents: { a: "false" } }, headers: auth_header, as: :json
    expect(response).to have_http_status(:ok)

    expect(caregiver.consents.where(kind: "a").count).to eq(1)
    expect(caregiver.consents.find_by(kind: "a").granted).to be false
  end
end
