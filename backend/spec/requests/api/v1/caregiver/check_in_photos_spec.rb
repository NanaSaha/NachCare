require "rails_helper"

RSpec.describe "Api::V1::Caregiver::CheckInPhotos", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let!(:caregiver) { create(:caregiver, episode: episode) }
  let!(:check_in) { create(:check_in, episode: episode, caregiver: caregiver) }

  let(:device_token) do
    Domain::Enrollment::Activator.activate_caregiver!(
      code: Domain::Enrollment::Activator.generate!(episode: episode, role: "primary").plaintext_code
    ).plaintext_device_token
  end
  let(:auth_header) { { "Authorization" => "Bearer #{device_token}" } }
  let(:photo_file) { fixture_file_upload("test_photo.jpg", "image/jpeg") }

  describe "POST /api/v1/caregiver/check_ins/:check_in_id/photos" do
    it "requires a valid device token" do
      post "/api/v1/caregiver/check_ins/#{check_in.id}/photos", params: { image: photo_file }
      expect(response).to have_http_status(:unauthorized)
    end

    it "attaches a photo to the check-in and returns a url" do
      post "/api/v1/caregiver/check_ins/#{check_in.id}/photos", params: { image: photo_file }, headers: auth_header

      expect(response).to have_http_status(:created)
      expect(check_in.check_in_photos.count).to eq(1)
      expect(response.parsed_body["url"]).to be_present
    end

    it "does not allow attaching a photo to another episode's check-in" do
      other_check_in = create(:check_in, episode: create(:episode, patient: create(:patient, site: site)))

      post "/api/v1/caregiver/check_ins/#{other_check_in.id}/photos", params: { image: photo_file }, headers: auth_header

      expect(response).to have_http_status(:not_found)
    end

    it "rejects a request with no file" do
      post "/api/v1/caregiver/check_ins/#{check_in.id}/photos", headers: auth_header

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "records an audit event" do
      expect {
        post "/api/v1/caregiver/check_ins/#{check_in.id}/photos", params: { image: photo_file }, headers: auth_header
      }.to change(AuditEvent, :count).by(1)
    end
  end
end
