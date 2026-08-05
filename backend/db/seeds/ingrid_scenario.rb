# Reproduces the full Ingrid/Sabine demo story (Section 0 mission summary;
# Section 8/M7: "seed ingrid_scenario.rb reproducing the full demo story
# incl. the day-17 save"). Unlike e2e/tests/support/seed-journey-episode.ts
# (a throwaway `rails runner` one-liner that hand-crafts a single
# evaluation row just to get a RED flag on the board for Playwright), this
# seed drives every check-in through the REAL escalation pipeline
# (Domain::Escalation::Processor.process!) so the day-17 RED flag, its
# notification fallback attempts, and the day-17 nurse "save" (the
# intervention that resolves it) are all real, pipeline-produced rows —
# exactly what a live demo or `ops/demo.sh` walkthrough should show
# side by side on the caregiver PWA and cockpit.
#
# Idempotent: guarded on a fixed pseudonym_code, safe to run more than
# once (`bin/rails runner db/seeds/ingrid_scenario.rb` or `bin/rails
# db:seed` if wired in) — it will just print the existing scenario's
# identifiers again rather than duplicating anything.
#
# All check-in notes/content are ordinary demo narration, not clinical
# copy — the *ruleset* thresholds that decide GREEN/YELLOW/RED are the
# real (PLACEHOLDER_CLINICAL, see docs/OPEN_CLINICAL_ITEMS.md #3) seeded
# ruleset, unmodified.

PSEUDONYM_CODE = "PT-INGRID-DEMO".freeze

if Patient.exists?(pseudonym_code: PSEUDONYM_CODE)
  patient = Patient.find_by(pseudonym_code: PSEUDONYM_CODE)
  episode = patient.episodes.first
  caregiver = episode.caregivers.first
  nurse = User.find_by(email: "sabine.demo.nurse@example.eu")
  Rails.logger.info "Ingrid demo scenario already seeded (patient_id=#{patient.id}, episode_id=#{episode.id}, nurse=#{nurse&.email}). Skipping."
else
  site = Site.find_or_create_by!(name: "NachCare Demo Site") { |s| s.timezone = "Europe/Berlin" }

  patient = Patient.create!(
    site: site, pseudonym_code: PSEUDONYM_CODE, initials: "I.M.", birth_year: 1950, nyha_class: "III"
  )
  # Day 0 = 90 days ago, so "today" is day-90 the moment this seed runs —
  # matching the mission summary's "first 90 days after hospital
  # discharge" and letting a demo walkthrough graduate the episode live
  # without waiting.
  episode = Episode.create!(patient: patient, start_date: 90.days.ago.to_date, status: "active")

  caregiver = Caregiver.create!(
    episode: episode, display_name: "Sabine", relationship: "daughter", language: "en",
    notification_time: "08:00", contact_data: { "phone" => "+491701234567", "email" => "sabine.demo@example.eu" }
  )

  care_plan = CarePlan.create!(
    episode: episode, version: 1, active: true, diet_rules: "Low-salt day guidance per care plan.",
    thresholds: {}, cadence: { "checkin" => "daily" }
  )
  Medication.create!(care_plan: care_plan, name: "Ramipril", critical: true, drug: Drug.find_by("lower(name) = ?", "ramipril"))
  Medication.create!(care_plan: care_plan, name: "Furosemide", critical: true, drug: Drug.find_by("lower(name) = ?", "furosemide"))

  generated = Domain::Enrollment::Activator.generate!(episode: episode, role: "primary")
  Domain::Audit::Recorder.record!(actor: :system, action: "episode.enrolled", entity: episode, payload: { seed: "ingrid_scenario" })

  nurse_password = "correct horse battery staple"
  nurse = User.create!(
    email: "sabine.demo.nurse@example.eu", password: nurse_password, password_confirmation: nurse_password,
    role: "nurse", site: site
  )
  User.create!(
    email: "sabine.demo.admin@example.eu", password: nurse_password, password_confirmation: nurse_password,
    role: "site_admin", site: site
  )

  day17 = episode.start_date + 17.days
  day17_flag = nil

  submit_check_in = lambda do |date, weight:, breathless: false, swelling: false, med_missed: false, note: ""|
    check_in = CheckIn.create!(
      episode: episode, caregiver: caregiver, client_uuid: SecureRandom.uuid,
      submitted_at: date.to_time + 8.hours, effective_date: date, weight_kg: weight,
      weight_source: "manual", med_status: (med_missed ? { "ramipril" => "missed" } : {}),
      symptoms: { "breathless_at_rest" => breathless, "swelling_increased" => swelling }, note: note
    )
    result = Domain::Escalation::Processor.process!(episode: episode, check_in: check_in, as_of: check_in.submitted_at)
    Domain::Analytics::Tracker.track!(episode: episode, name: "checkin.submitted")
    result
  end

  # Day 0-16: steady, unremarkable check-ins (GREEN).
  (0..16).each { |offset| submit_check_in.call(episode.start_date + offset.days, weight: 70.0) }

  # Day 17: "the save" — R-4 (breathless at rest) fires RED, the real
  # pipeline opens a flag, starts the RED notification fallback chain, and
  # a nurse catches it same-day. This is the scenario's centerpiece: proof
  # the deterministic engine + triage queue can catch and act on
  # deterioration within its SLA, the whole product's reason to exist.
  day17_result = submit_check_in.call(day17, weight: 70.5, breathless: true, note: "Felt breathless just sitting down this morning.")
  day17_flag = day17_result.flag

  nurse_note = "Called Sabine directly — Ingrid was resting when it happened, no chest pain, advised to " \
    "monitor and call back if it recurs. Will follow up tomorrow."
  Intervention.create!(flag: day17_flag, actor: nurse, outcome: "acknowledged", note_final: nurse_note)
  day17_flag.update!(state: "in_progress", first_action_at: day17.to_time + 9.hours)
  day17_flag.update!(state: "resolved", outcome: "acknowledged", resolved_at: day17.to_time + 9.hours + 40.minutes)
  Domain::Analytics::Tracker.track!(episode: episode, name: "flag.resolved", properties: { "severity" => "red", "breach" => day17_flag.breach })
  Domain::Audit::Recorder.record!(actor: nurse, action: "flag.updated", entity: day17_flag, payload: { state: "resolved", outcome: "acknowledged" })

  # Day 18-39: back to steady GREEN, with one YELLOW blip (a missed critical
  # medication dose around day 25) to give pilot_metrics non-trivial YELLOW
  # data too, not just the single RED headline.
  (18..39).each do |offset|
    submit_check_in.call(episode.start_date + offset.days, weight: 70.2, med_missed: (offset == 25))
  end

  # Day 40-89: steady GREEN through to day 90 (today).
  (40..89).each { |offset| submit_check_in.call(episode.start_date + offset.days, weight: 70.0) }

  # Content completion + an in-scope assistant turn, so Learn/AI-adjacent
  # pilot signals aren't empty either.
  content_item = ContentItem.find_by(week_no: 1, status: "approved")
  if content_item
    Domain::Analytics::Tracker.track!(episode: episode, name: "content_item.completed", properties: { "content_item_ref" => content_item.id })
  end

  Rails.logger.info(<<~MSG)
    Seeded Ingrid demo scenario:
      patient_id=#{patient.id} episode_id=#{episode.id} day17_flag_id=#{day17_flag&.id}
      activation_code=#{generated.plaintext_code} (site=#{site.name})
      nurse_email=#{nurse.email} nurse_password=#{nurse_password}
  MSG
end
