import { execSync } from 'node:child_process';
import path from 'node:path';

export interface SeededFlag {
  flagId: number;
  patientCode: string;
  patientId: string;
}

/**
 * Creates an episode with a few days of check-in history and a fired
 * red evaluation feeding a real flag through Domain::Flags::Lifecycle —
 * everything triage.spec needs to exercise the queue, SLA display, and
 * flag detail (trend + evaluations) against real data.
 */
export function seedFlagWithHistory(): SeededFlag {
  const repoRoot = path.resolve(__dirname, '../..', '..');
  const composeFile = path.join(repoRoot, 'ops/docker-compose.yml');

  const script = `
    site = Site.find_or_create_by!(name: "E2E Demo Site") { |s| s.timezone = "Europe/Berlin" }
    code = "PT-E2ET-\#{SecureRandom.hex(3)}"
    patient = Patient.create!(site: site, pseudonym_code: code, initials: "I.G.", birth_year: 1949, nyha_class: "III")
    episode = Episode.create!(patient: patient, start_date: Date.current, status: "active")
    caregiver = Caregiver.create!(episode: episode, display_name: "Sabine", relationship: "daughter", language: "en")
    care_plan = CarePlan.create!(episode: episode, version: 1, active: true, thresholds: {}, cadence: {})
    Medication.create!(care_plan: care_plan, name: "Ramipril", critical: true)
    (0..2).each do |i|
      CheckIn.create!(episode: episode, caregiver: caregiver, client_uuid: SecureRandom.uuid,
        submitted_at: i.days.ago, effective_date: i.days.ago.to_date, weight_kg: 70.0 + i * 0.3, symptoms: {})
    end
    evaluation = Evaluation.create!(episode: episode, ruleset_version: Ruleset.active.version,
      inputs_sha256: SecureRandom.hex(16), severity: "red", fired_rules: [{ "id" => "R-4" }], created_at: Time.current)
    flag = Domain::Flags::Lifecycle.record_evaluation!(evaluation: evaluation)
    puts "FLAG_ID=#{flag.id}"
    puts "PATIENT_CODE=#{code}"
    puts "PATIENT_ID=#{patient.id}"
  `.trim();

  const output = execSync(
    `docker compose -f "${composeFile}" run --rm backend bin/rails runner '${script}'`,
    { encoding: 'utf-8' }
  );

  const flagMatch = output.match(/FLAG_ID=(\d+)/);
  const codeMatch = output.match(/PATIENT_CODE=(\S+)/);
  const idMatch = output.match(/PATIENT_ID=(\S+)/);
  if (!flagMatch || !codeMatch || !idMatch) throw new Error(`could not parse seed output:\n${output}`);

  return { flagId: Number(flagMatch[1]), patientCode: codeMatch[1], patientId: idMatch[1] };
}
