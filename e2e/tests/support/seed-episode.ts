import { execSync } from 'node:child_process';
import path from 'node:path';

export interface SeededEpisode {
  activationCode: string;
}

/**
 * Creates a fresh episode + primary caregiver + a care plan with one
 * critical medication, and returns a primary activation code — everything
 * checkin.spec needs to activate a caregiver and drive the check-in wizard
 * against real data. Runs via `rails runner` in the same backend container
 * the app itself talks to (ops/docker-compose.yml), not a separate DB.
 */
export function seedCheckInEpisode(): SeededEpisode {
  const repoRoot = path.resolve(__dirname, '../..', '..');
  const composeFile = path.join(repoRoot, 'ops/docker-compose.yml');

  const script = `
    site = Site.find_or_create_by!(name: "E2E Demo Site") { |s| s.timezone = "Europe/Berlin" }
    patient = Patient.create!(site: site, pseudonym_code: "PT-E2E-\#{SecureRandom.hex(4)}", initials: "I.G.", birth_year: 1949, nyha_class: "III")
    episode = Episode.create!(patient: patient, start_date: Date.current, status: "active")
    Caregiver.create!(episode: episode, display_name: "Sabine", relationship: "daughter", language: "en")
    care_plan = CarePlan.create!(episode: episode, version: 1, active: true, thresholds: {}, cadence: {})
    Medication.create!(care_plan: care_plan, name: "Ramipril", critical: true)
    generated = Domain::Enrollment::Activator.generate!(episode: episode, role: "primary")
    puts "ACTIVATION_CODE=#{generated.plaintext_code}"
  `.trim();

  const output = execSync(
    `docker compose -f "${composeFile}" run --rm backend bin/rails runner '${script}'`,
    { encoding: 'utf-8' }
  );

  const match = output.match(/ACTIVATION_CODE=(\w+)/);
  if (!match) throw new Error(`could not find activation code in seed output:\n${output}`);

  return { activationCode: match[1] };
}
