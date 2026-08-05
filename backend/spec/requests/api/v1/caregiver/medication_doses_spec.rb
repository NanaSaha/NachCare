require "rails_helper"

# Caregiver requirement #3/#5 (post-M7, ADR-0010): per-scheduled-dose
# recording, independent of the once-daily check-in wizard.
RSpec.describe "Api::V1::Caregiver::MedicationDoses", type: :request do
  let(:episode) { create(:episode) }
  let!(:caregiver) { create(:caregiver, episode: episode) }
  let(:care_plan) { create(:care_plan, episode: episode, active: true) }
  let!(:medication) do
    create(:medication, care_plan: care_plan, name: "Furosemide", critical: true,
      schedule: { "times" => [ "08:00", "20:00" ], "instructions" => "1 tablet with food" })
  end
  let(:device_token) do
    Domain::Enrollment::Activator.activate_caregiver!(
      code: Domain::Enrollment::Activator.generate!(episode: episode, role: "primary").plaintext_code
    ).plaintext_device_token
  end
  let(:auth_header) { { "Authorization" => "Bearer #{device_token}" } }

  describe "GET /api/v1/caregiver/medication_doses" do
    it "requires authentication" do
      get "/api/v1/caregiver/medication_doses"
      expect(response).to have_http_status(:unauthorized)
    end

    it "computes today's tasks from the active plan's schedule, defaulting every slot to pending" do
      get "/api/v1/caregiver/medication_doses", headers: auth_header

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["date"]).to eq(Date.current.to_s)
      expect(body["tasks"].size).to eq(2)
      expect(body["tasks"].map { |t| t["scheduled_time"] }).to eq([ "08:00", "20:00" ])
      expect(body["tasks"].map { |t| t["status"] }).to eq([ "pending", "pending" ])
      expect(body["tasks"].first["medication_name"]).to eq("Furosemide")
      expect(body["tasks"].first["instructions"]).to eq("1 tablet with food")
    end

    it "overlays existing dose rows for the requested date" do
      create(:medication_dose, medication: medication, caregiver: caregiver,
        scheduled_date: Date.current, scheduled_time: "08:00", status: "taken", taken_at: Time.current)

      get "/api/v1/caregiver/medication_doses", headers: auth_header

      body = response.parsed_body
      taken = body["tasks"].find { |t| t["scheduled_time"] == "08:00" }
      expect(taken["status"]).to eq("taken")
      pending = body["tasks"].find { |t| t["scheduled_time"] == "20:00" }
      expect(pending["status"]).to eq("pending")
    end

    it "accepts an explicit date param" do
      yesterday = 1.day.ago.to_date
      create(:medication_dose, medication: medication, caregiver: caregiver,
        scheduled_date: yesterday, scheduled_time: "08:00", status: "missed")

      get "/api/v1/caregiver/medication_doses", params: { date: yesterday.to_s }, headers: auth_header

      body = response.parsed_body
      expect(body["date"]).to eq(yesterday.to_s)
      expect(body["tasks"].find { |t| t["scheduled_time"] == "08:00" }["status"]).to eq("missed")
    end
  end

  describe "POST /api/v1/caregiver/medication_doses" do
    it "requires authentication" do
      post "/api/v1/caregiver/medication_doses", params: { medication_id: medication.id, scheduled_date: Date.current, scheduled_time: "08:00", status: "taken" }
      expect(response).to have_http_status(:unauthorized)
    end

    it "creates a dose row marked taken and stamps taken_at" do
      expect {
        post "/api/v1/caregiver/medication_doses",
          params: { medication_id: medication.id, scheduled_date: Date.current, scheduled_time: "08:00", status: "taken" },
          headers: auth_header, as: :json
      }.to change(MedicationDose, :count).by(1)

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["status"]).to eq("taken")
      expect(body["taken_at"]).to be_present
    end

    it "broadcasts a nurse alert (product-owner feedback item #4, ADR-0011)" do
      site_ref = episode.patient.site_ref
      expect(ActionCable.server).to receive(:broadcast).with("nurse_alerts_site_#{site_ref}", hash_including(type: "medication_dose"))
      # Also still broadcasts the existing per-episode care-activity feed (ADR-0010) — unrelated but on the same request.
      allow(ActionCable.server).to receive(:broadcast).with("care_activity_episode_#{episode.id}", anything)

      post "/api/v1/caregiver/medication_doses",
        params: { medication_id: medication.id, scheduled_date: Date.current, scheduled_time: "08:00", status: "taken" },
        headers: auth_header, as: :json
    end

    it "creates a dose row marked missed with no taken_at" do
      post "/api/v1/caregiver/medication_doses",
        params: { medication_id: medication.id, scheduled_date: Date.current, scheduled_time: "20:00", status: "missed" },
        headers: auth_header, as: :json

      expect(response).to have_http_status(:created)
      body = response.parsed_body
      expect(body["status"]).to eq("missed")
      expect(body["taken_at"]).to be_nil
    end

    it "is idempotent: re-posting the same slot updates the existing row rather than duplicating" do
      post "/api/v1/caregiver/medication_doses",
        params: { medication_id: medication.id, scheduled_date: Date.current, scheduled_time: "08:00", status: "missed" },
        headers: auth_header, as: :json

      expect {
        post "/api/v1/caregiver/medication_doses",
          params: { medication_id: medication.id, scheduled_date: Date.current, scheduled_time: "08:00", status: "taken" },
          headers: auth_header, as: :json
      }.not_to change(MedicationDose, :count)

      expect(MedicationDose.last.status).to eq("taken")
    end

    it "rejects a medication not on the caregiver's active plan" do
      other_med = create(:medication)
      post "/api/v1/caregiver/medication_doses",
        params: { medication_id: other_med.id, scheduled_date: Date.current, scheduled_time: "08:00", status: "taken" },
        headers: auth_header, as: :json

      expect(response).to have_http_status(:not_found)
    end

    it "rejects an invalid status" do
      post "/api/v1/caregiver/medication_doses",
        params: { medication_id: medication.id, scheduled_date: Date.current, scheduled_time: "08:00", status: "snoozed" },
        headers: auth_header, as: :json

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "records an audit event and an analytics event" do
      expect {
        post "/api/v1/caregiver/medication_doses",
          params: { medication_id: medication.id, scheduled_date: Date.current, scheduled_time: "08:00", status: "taken" },
          headers: auth_header, as: :json
      }.to change(AuditEvent, :count).by(1).and change(AnalyticsEvent, :count).by(1)

      expect(AuditEvent.last.action).to eq("medication_dose.recorded")
      expect(AnalyticsEvent.last.name).to eq("medication_dose.recorded")
    end
  end
end
