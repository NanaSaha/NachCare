import { defineConfig } from '@playwright/test';
import path from 'node:path';

const REPO_ROOT = path.resolve(__dirname, '..');

export const CAREGIVER_URL = 'http://localhost:4200';
export const COCKPIT_URL = 'http://localhost:4300';
export const API_URL = 'http://localhost:3001';

export default defineConfig({
  testDir: './tests',
  fullyParallel: false, // enrollment.spec hands a code from one app to another — order matters
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 1 : 0,
  reporter: [ [ 'list' ] ],
  globalSetup: require.resolve('./global-setup'),
  use: {
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  webServer: [
    {
      command: `docker compose -f ${path.join(REPO_ROOT, 'ops/docker-compose.yml')} up`,
      url: `${API_URL}/api/v1/health`,
      reuseExistingServer: true,
      timeout: 120_000,
      stdout: 'pipe',
    },
    {
      command: 'npx ng serve caregiver --port 4200',
      cwd: path.join(REPO_ROOT, 'frontend'),
      url: CAREGIVER_URL,
      reuseExistingServer: true,
      timeout: 120_000,
      stdout: 'pipe',
    },
    {
      command: 'npx ng serve cockpit --port 4300',
      cwd: path.join(REPO_ROOT, 'frontend'),
      url: COCKPIT_URL,
      reuseExistingServer: true,
      timeout: 120_000,
      stdout: 'pipe',
    },
  ],
});
