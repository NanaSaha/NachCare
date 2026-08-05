require "rails_helper"

RSpec.describe "Api::V1::Caregiver::PushSubscriptions", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let!(:caregiver) { create(:caregiver, episode: episode) }

  let(:device_token) do
    Domain::Enrollment::Activator.activate_caregiver!(
      code: Domain::Enrollment::Activator.generate!(episode: episode, role: "primary").plaintext_code
    ).plaintext_device_token
  end
  let(:auth_header) { { "Authorization" => "Bearer #{device_token}" } }

  describe "PATCH /api/v1/caregiver/push_subscription" do
    it "requires a valid device token" do
      patch "/api/v1/caregiver/push_subscription", params: { subscription: {} }, as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "stores the PushManager subscription on the caregiver" do
      patch "/api/v1/caregiver/push_subscription", params: {
        subscription: {
          endpoint: "https://push.example.eu/xyz",
          keys: { p256dh: "p256dh-key", auth: "auth-key" }
        }
      }, headers: auth_header, as: :json

      expect(response).to have_http_status(:no_content)
      caregiver_record = Caregiver.find(caregiver.id)
      expect(caregiver_record.push_subscription["endpoint"]).to eq("https://push.example.eu/xyz")
      expect(caregiver_record.push_subscription["keys"]["p256dh"]).to eq("p256dh-key")
    end
  end
end
