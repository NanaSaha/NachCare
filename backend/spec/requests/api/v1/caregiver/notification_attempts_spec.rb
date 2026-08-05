require "rails_helper"

RSpec.describe "Api::V1::Caregiver::NotificationAttempts", type: :request do
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

  describe "POST /api/v1/caregiver/notification_attempts/:id/confirm" do
    it "requires a valid device token" do
      attempt = create(:notification_attempt, caregiver: caregiver)
      post "/api/v1/caregiver/notification_attempts/#{attempt.id}/confirm", as: :json
      expect(response).to have_http_status(:unauthorized)
    end

    it "marks a sent attempt as confirmed" do
      attempt = create(:notification_attempt, caregiver: caregiver, state: "sent")

      post "/api/v1/caregiver/notification_attempts/#{attempt.id}/confirm", headers: auth_header, as: :json

      expect(response).to have_http_status(:no_content)
      expect(attempt.reload.state).to eq("confirmed")
    end

    it "does not let a caregiver confirm another caregiver's notification" do
      other_caregiver = create(:caregiver)
      attempt = create(:notification_attempt, caregiver: other_caregiver, state: "sent")

      post "/api/v1/caregiver/notification_attempts/#{attempt.id}/confirm", headers: auth_header, as: :json

      expect(response).to have_http_status(:not_found)
      expect(attempt.reload.state).to eq("sent")
    end
  end
end
