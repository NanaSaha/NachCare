require "rails_helper"

RSpec.describe "Api::V1::Staff::Flags", type: :request do
  let(:site) { create(:site) }
  let(:patient) { create(:patient, site: site) }
  let(:episode) { create(:episode, patient: patient) }
  let(:nurse) { create(:user, role: "nurse", site: site) }
  let(:ward_nurse) { create(:user, role: "ward_nurse", site: site) }
  let(:analyst) { create(:user, role: "analyst", site: site) }

  describe "GET /api/v1/staff/flags" do
    it "returns flags for the staff member's site, sorted red before yellow, then by SLA deadline" do
      create(:flag, episode: episode, severity: "yellow", sla_deadline_at: 2.hours.from_now)
      red = create(:flag, episode: episode, severity: "red", sla_deadline_at: 20.minutes.from_now)
      other_site_flag = create(:flag, episode: create(:episode, patient: create(:patient, site: create(:site))))

      get "/api/v1/staff/flags", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      ids = response.parsed_body.map { |f| f["id"] }
      expect(ids.first).to eq(red.id)
      expect(ids).not_to include(other_site_flag.id)
    end

    it "filters by state" do
      create(:flag, episode: episode, state: "open")
      resolved = create(:flag, episode: episode, state: "resolved")

      get "/api/v1/staff/flags", params: { state: "resolved" }, headers: staff_auth_header(nurse)

      ids = response.parsed_body.map { |f| f["id"] }
      expect(ids).to eq([ resolved.id ])
    end
  end

  describe "GET /api/v1/staff/flags/summary" do
    it "returns KPI counts scoped to the staff member's site" do
      create(:flag, episode: episode, state: "open", severity: "red")
      create(:flag, episode: episode, state: "open", severity: "yellow")
      create(:flag, episode: episode, state: "resolved", severity: "yellow")

      get "/api/v1/staff/flags/summary", headers: staff_auth_header(nurse)

      body = response.parsed_body
      expect(body["open"]).to eq(2)
      expect(body["red"]).to eq(1)
      expect(body["yellow"]).to eq(1)
    end
  end

  describe "GET /api/v1/staff/flags/:id" do
    it "returns flag detail with evaluations, interventions, and check-in history" do
      evaluation = create(:evaluation, episode: episode, severity: "red", fired_rules: [ { "id" => "R-4" } ])
      flag = create(:flag, episode: episode, evaluation_refs: [ evaluation.id ])
      create(:check_in, episode: episode, caregiver: create(:caregiver, episode: episode), effective_date: Date.current, weight_kg: 70.0)

      get "/api/v1/staff/flags/#{flag.id}", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      body = response.parsed_body
      expect(body["evaluations"].size).to eq(1)
      expect(body["check_in_history"].size).to eq(1)
    end

    # Product-owner feedback item #2 (ADR-0011): the M3 traceability note's
    # "photos not yet implemented" gap, plus the caregiver's free-text
    # "how is she feeling today" answer (check_ins.note).
    it "includes the caregiver's note and any attached photo urls in check-in history" do
      evaluation = create(:evaluation, episode: episode, severity: "red")
      flag = create(:flag, episode: episode, evaluation_refs: [ evaluation.id ])
      check_in = create(:check_in, episode: episode, caregiver: create(:caregiver, episode: episode),
        effective_date: Date.current, note: "she seems tired but ate well")
      photo = check_in.check_in_photos.new
      photo.image.attach(io: StringIO.new("x" * 10), filename: "test.jpg", content_type: "image/jpeg")
      photo.save!

      get "/api/v1/staff/flags/#{flag.id}", headers: staff_auth_header(nurse)

      entry = response.parsed_body["check_in_history"].first
      expect(entry["note"]).to eq("she seems tired but ate well")
      expect(entry["photo_urls"].size).to eq(1)
      expect(entry["photo_urls"].first).to include("rails/active_storage")
    end

    it "records an audit event for viewing the flag ('who viewed')" do
      flag = create(:flag, episode: episode)

      expect { get "/api/v1/staff/flags/#{flag.id}", headers: staff_auth_header(nurse) }
        .to change(AuditEvent, :count).by(1)

      expect(AuditEvent.last.action).to eq("flag.viewed")
    end

    it "forbids staff at another site" do
      flag = create(:flag, episode: episode)
      other = create(:user, role: "nurse", site: create(:site))

      get "/api/v1/staff/flags/#{flag.id}", headers: staff_auth_header(other)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/staff/flags (manual flags, FR-N9)" do
    it "creates a manual flag with an SLA deadline" do
      post "/api/v1/staff/flags", params: { episode_ref: episode.id, severity: "yellow" }, headers: staff_auth_header(nurse), as: :json

      expect(response).to have_http_status(:created)
      flag = Flag.last
      expect(flag.subtype).to eq("manual")
      expect(flag.sla_deadline_at).to be_present
    end

    it "forbids analyst from creating a manual flag" do
      post "/api/v1/staff/flags", params: { episode_ref: episode.id, severity: "yellow" }, headers: staff_auth_header(analyst), as: :json
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/staff/flags/:id (state transitions + intervention logging)" do
    it "transitions state, sets first_action_at, and logs an intervention" do
      flag = create(:flag, episode: episode, state: "open")

      patch "/api/v1/staff/flags/#{flag.id}",
        params: { state: "in_progress", outcome: "acknowledged", note: "Called caregiver." },
        headers: staff_auth_header(nurse), as: :json

      expect(response).to have_http_status(:ok)
      flag.reload
      expect(flag.state).to eq("in_progress")
      expect(flag.first_action_at).to be_present
      expect(flag.interventions.count).to eq(1)
      expect(flag.interventions.first.actor_ref).to eq(nurse.id)
    end

    it "sets resolved_at when transitioning to resolved" do
      flag = create(:flag, episode: episode, state: "in_progress")

      patch "/api/v1/staff/flags/#{flag.id}", params: { state: "resolved", outcome: "resolved" },
        headers: staff_auth_header(nurse), as: :json

      expect(flag.reload.resolved_at).to be_present
    end

    it "forbids ward_nurse from transitioning flag state" do
      flag = create(:flag, episode: episode, state: "open")

      patch "/api/v1/staff/flags/#{flag.id}", params: { state: "in_progress" }, headers: staff_auth_header(ward_nurse), as: :json
      expect(response).to have_http_status(:forbidden)
    end

    # UC-23 step 6
    it "applies dismiss_false_positive: resolves the flag and labels the triggering risk_score" do
      risk_score = create(:risk_score, episode: episode, outcome: nil)
      flag = create(:flag, episode: episode, subtype: "ai_watch", state: "open", watch_expires_at: 5.days.from_now,
        ai_watch_meta: { "risk_score_id" => risk_score.id })

      patch "/api/v1/staff/flags/#{flag.id}", params: { state: "resolved", outcome: "dismiss_false_positive" },
        headers: staff_auth_header(nurse), as: :json

      expect(response).to have_http_status(:ok)
      expect(flag.reload.state).to eq("resolved")
      expect(flag.watch_expires_at).to be_nil
      expect(risk_score.reload.outcome).to eq("resolved_uneventful")
    end

    it "applies accept_and_watch: tightens the expiry window without changing state" do
      flag = create(:flag, episode: episode, subtype: "ai_watch", state: "open", watch_expires_at: 5.days.from_now)

      patch "/api/v1/staff/flags/#{flag.id}", params: { state: "in_progress", outcome: "accept_and_watch" },
        headers: staff_auth_header(nurse), as: :json

      expect(flag.reload.watch_expires_at).to be_within(1.minute).of(2.days.from_now)
    end
  end

  describe "GET /api/v1/staff/flags/:id/ai_watch_rationale" do
    it "returns a plain-language rationale, never a bare score" do
      flag = create(:flag, episode: episode, subtype: "ai_watch",
        ai_watch_meta: { "components" => { "weight_velocity" => 0.8 } })

      get "/api/v1/staff/flags/#{flag.id}/ai_watch_rationale", headers: staff_auth_header(nurse)

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body["rationale"]).to be_present
    end
  end

  describe "GET /api/v1/staff/flags/summary — ai_watch counted separately from yellow" do
    it "does not fold ai_watch into the yellow KPI count" do
      create(:flag, episode: episode, state: "open", severity: "yellow", subtype: "clinical")
      create(:flag, episode: episode, state: "open", severity: "yellow", subtype: "ai_watch")

      get "/api/v1/staff/flags/summary", headers: staff_auth_header(nurse)

      body = response.parsed_body
      expect(body["yellow"]).to eq(1)
      expect(body["ai_watch"]).to eq(1)
    end
  end
end
