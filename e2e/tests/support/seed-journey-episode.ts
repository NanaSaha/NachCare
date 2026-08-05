import { execSync } from 'node:child_process';
import path from 'node:path';

export interface SeededJourney {
  activationCode: string;
  patientCode: string;
  patientId: string;
  episodeId: number;
  day17FlagId: number;
  nurseEmail: string;
  nursePassword: string;
}

/**
 * Seeds the full Ingrid day-0 -> 17 -> 90 story journey.spec exercises
 * (Section 8/M6 gate). The episode's `start_date` is backdated 90 days so
 * it's graduation-eligible "today" (ADR-0008 #4 — the 90 is a real
 * elapsed-time check, not something a test can time-travel around) and a
 * day-17 flag (effective_date = start_date + 17 days) is pre-seeded with a
 * fired RED evaluation so the Playwright test can drive the cockpit's real
 * open -> in_progress -> resolved triage flow against real history, the
 * same way triage.spec does. The live check-in/Trends/Learn/Care-team
 * steps the test drives afterward happen at real "today", which for this
 * backdated episode *is* day 90 — the graduation step needs no further
 * seeding, just `Domain::Graduation::Eligibility.eligible?`.
 */
export function seedJourneyEpisode(): SeededJourney {
  const repoRoot = path.resolve(__dirname, '../..', '..');
  const composeFile = path.join(repoRoot, 'ops/docker-compose.yml');

  const script = `
    site = Site.find_or_create_by!(name: "E2E Journey Site") { |s| s.timezone = "Europe/Berlin" }
    code = "PT-E2EJ-\#{SecureRandom.hex(3)}"
    patient = Patient.create!(site: site, pseudonym_code: code, initials: "I.G.", birth_year: 1949, nyha_class: "III")
    episode = Episode.create!(patient: patient, start_date: 90.days.ago.to_date, status: "active")
    caregiver = Caregiver.create!(episode: episode, display_name: "Sabine", relationship: "daughter", language: "en")
    care_plan = CarePlan.create!(episode: episode, version: 1, active: true, thresholds: {}, cadence: {})
    Medication.create!(care_plan: care_plan, name: "Ramipril", critical: true)

    day17_date = episode.start_date + 17.days
    ((day17_date - 2.days)..day17_date).each do |d|
      CheckIn.create!(episode: episode, caregiver: caregiver, client_uuid: SecureRandom.uuid,
        submitted_at: d.to_time, effective_date: d, weight_kg: 70.0, symptoms: { "breathless_at_rest" => (d == day17_date) })
    end
    evaluation = Evaluation.create!(episode: episode, ruleset_version: Ruleset.active.version,
      inputs_sha256: SecureRandom.hex(16), severity: "red", fired_rules: [{ "id" => "R-4" }],
      created_at: day17_date.to_time)
    flag = Domain::Flags::Lifecycle.record_evaluation!(evaluation: evaluation)

    generated = Domain::Enrollment::Activator.generate!(episode: episode, role: "primary")

    nurse_email = "e2e-journey-nurse-\#{SecureRandom.hex(3)}@example.eu"
    nurse_password = "correct horse battery staple"
    User.create!(email: nurse_email, password: nurse_password, password_confirmation: nurse_password, role: "nurse", site: site)

    puts "ACTIVATION_CODE=#{generated.plaintext_code}"
    puts "PATIENT_CODE=#{code}"
    puts "PATIENT_ID=#{patient.id}"
    puts "EPISODE_ID=#{episode.id}"
    puts "DAY17_FLAG_ID=#{flag.id}"
    puts "NURSE_EMAIL=#{nurse_email}"
  `.trim();

  const output = execSync(
    `docker compose -f "${composeFile}" run --rm backend bin/rails runner '${script}'`,
    { encoding: 'utf-8' }
  );

  const grab = (re: RegExp) => {
    const m = output.match(re);
    if (!m) throw new Error(`could not parse seed output:\n${output}`);
    return m[1];
  };

  return {
    activationCode: grab(/ACTIVATION_CODE=(\w+)/),
    patientCode: grab(/PATIENT_CODE=(\S+)/),
    patientId: grab(/PATIENT_ID=(\S+)/),
    episodeId: Number(grab(/EPISODE_ID=(\d+)/)),
    day17FlagId: Number(grab(/DAY17_FLAG_ID=(\d+)/)),
    nurseEmail: grab(/NURSE_EMAIL=(\S+)/),
    nursePassword: 'correct horse battery staple',
  };
}
