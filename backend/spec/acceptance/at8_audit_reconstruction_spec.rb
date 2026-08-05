require "rails_helper"

# AT-8 (Section 8 acceptance test suite): "audit reconstruction of day-17
# from audit_events alone (write the reconstruction script)." Drives a
# day-17-style story through the REAL pipeline (Escalation::Processor,
# Flags::Lifecycle, the staff flags controller's view/update actions) —
# not hand-crafted AuditEvent rows — then asserts
# Domain::Audit::EpisodeReconstructor recovers the full sequence of who
# did what, when, using only `audit_events`.
RSpec.describe "AT-8: audit reconstruction from audit_events alone", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient, start_date: 17.days.ago.to_date) }
  let!(:caregiver) { create(:caregiver, episode: episode) }
  let(:nurse) { create(:user, role: "nurse", site: site) }
  let!(:ruleset) do
    create(:ruleset, version: "at8-ruleset", status: "active", body: {
      "version" => "at8-ruleset",
      "rules" => [
        { "id" => "R-4", "key" => "breathless_at_rest", "severity" => "red",
          "condition" => { "type" => "symptom_toggle", "symptom_key" => "breathless_at_rest" } }
      ]
    })
  end
  let(:device_token) do
    Domain::Enrollment::Activator.activate_caregiver!(
      code: Domain::Enrollment::Activator.generate!(episode: episode, role: "primary").plaintext_code
    ).plaintext_device_token
  end

  it "reconstructs the day-17 story (check-in -> RED flag -> nurse view -> in_progress -> resolved) purely from audit_events" do
    day17 = Date.current

    # 1) Caregiver submits the day-17 check-in that trips R-4.
    post "/api/v1/caregiver/check_ins",
      params: { client_uuid: SecureRandom.uuid, effective_date: day17, weight_kg: 70.5, symptoms: { breathless_at_rest: true }, med_status: {} },
      headers: { "Authorization" => "Bearer #{device_token}" }, as: :json
    expect(response).to have_http_status(:created)

    flag = Flag.find_by(episode: episode)
    expect(flag.severity).to eq("red")

    # 2) Nurse views the flag, then progresses it, then resolves it.
    get "/api/v1/staff/flags/#{flag.id}", headers: staff_auth_header(nurse)
    patch "/api/v1/staff/flags/#{flag.id}", params: { state: "in_progress", outcome: "acknowledged", note: "Called Sabine." }, headers: staff_auth_header(nurse), as: :json
    patch "/api/v1/staff/flags/#{flag.id}", params: { state: "resolved", outcome: "acknowledged" }, headers: staff_auth_header(nurse), as: :json

    # 3) Reconstruct purely from audit_events (no reference to check_in/
    # flag state below — everything asserted comes from the timeline).
    timeline = Domain::Audit::EpisodeReconstructor.call(episode: episode, date: day17)
    actions = timeline.map(&:action)

    expect(actions).to eq(%w[
      check_in.submitted
      flag.opened
      flag.escalation_sms_sent
      flag.viewed
      flag.updated
      flag.updated
    ])

    checkin_entry = timeline.find { |e| e.action == "check_in.submitted" }
    expect(checkin_entry.actor).to eq("caregiver:#{caregiver.id}")
    expect(checkin_entry.payload["effective_date"]).to eq(day17.iso8601)

    opened_entry = timeline.find { |e| e.action == "flag.opened" }
    expect(opened_entry.actor).to eq("system")
    expect(opened_entry.payload["severity"]).to eq("red")

    viewed_entry = timeline.find { |e| e.action == "flag.viewed" }
    expect(viewed_entry.actor).to eq("user:#{nurse.id}")

    updated_entries = timeline.select { |e| e.action == "flag.updated" }
    expect(updated_entries.map { |e| e.payload["state"] }).to eq(%w[in_progress resolved])
    expect(updated_entries.all? { |e| e.actor == "user:#{nurse.id}" }).to be true

    # The reconstructed sequence is monotonically ordered in time.
    expect(timeline.map(&:at)).to eq(timeline.map(&:at).sort)
  end

  it "scopes the reconstruction to episodes/dates it's asked about, not the whole audit log" do
    other_episode = create(:episode, patient: create(:patient, site: site))
    other_flag = create(:flag, episode: other_episode, severity: "yellow")
    Domain::Audit::Recorder.record!(actor: :system, action: "flag.opened", entity: other_flag, payload: {})

    timeline = Domain::Audit::EpisodeReconstructor.call(episode: episode)

    expect(timeline).to be_empty
  end
end
