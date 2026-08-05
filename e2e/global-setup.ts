import { execSync } from 'node:child_process';
import path from 'node:path';

// Seeds the dev DB with exactly what enrollment.spec needs: a nurse who can
// sign in, and the drug type-ahead table. Idempotent (find_or_create_by!/
// db:seed), safe to run every time e2e runs locally or in CI.
export default async function globalSetup(): Promise<void> {
  const repoRoot = path.resolve(__dirname, '..');
  const composeFile = path.join(repoRoot, 'ops/docker-compose.yml');

  const script = `
    site = Site.find_or_create_by!(name: "E2E Demo Site") { |s| s.timezone = "Europe/Berlin" }
    user = User.find_or_initialize_by(email: "e2e-nurse@example.eu")
    user.role = "nurse"
    user.site = site
    user.password = "correct horse battery staple"
    user.password_confirmation = "correct horse battery staple"
    user.save!
    puts "seeded nurse: #{user.email}"
  `.trim();

  execSync(
    `docker compose -f "${composeFile}" run --rm backend bin/rails runner '${script}'`,
    { stdio: 'inherit' }
  );
  execSync(
    `docker compose -f "${composeFile}" run --rm backend bin/rails db:seed`,
    { stdio: 'inherit' }
  );
}
