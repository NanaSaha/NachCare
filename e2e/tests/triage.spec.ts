import { test, expect } from '@playwright/test';
import { COCKPIT_URL } from '../playwright.config';
import { seedFlagWithHistory } from './support/seed-flag';

async function signInNurse(page: import('@playwright/test').Page) {
  await page.goto(`${COCKPIT_URL}/login`);
  await page.getByLabel('Email').fill('e2e-nurse@example.eu');
  await page.getByLabel('Password').fill('correct horse battery staple');
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page).toHaveURL(`${COCKPIT_URL}/triage`, { timeout: 10_000 });
}

// M3 gate (Section 8): triage queue with KPI header + SLA, flag detail with
// trend/evaluations, and the open -> in_progress -> resolved lifecycle with
// intervention logging — all against the real backend.
test('nurse triages a flag from the queue through to resolution', async ({ page }) => {
  const { flagId, patientCode } = seedFlagWithHistory();

  await signInNurse(page);

  await expect(page.getByTestId('kpi-header')).toBeVisible({ timeout: 10_000 });
  const row = page.getByTestId(`flag-row-${flagId}`);
  await expect(row).toBeVisible();
  await expect(row).toContainText(patientCode);

  await row.click();
  await expect(page).toHaveURL(`${COCKPIT_URL}/triage/${flagId}`);
  await expect(page.getByTestId('trend-chart')).toBeVisible();

  // open -> in_progress, with an intervention logged
  await page.getByTestId('outcome-input').fill('acknowledged');
  await page.getByTestId('note-input').fill('Called caregiver, advised monitoring.');
  await page.getByTestId('mark-in-progress').click();
  await expect(page.getByTestId('interventions')).toContainText('acknowledged');

  // in_progress -> resolved
  await page.getByTestId('outcome-input').fill('resolved');
  await page.getByTestId('mark-resolved').click();
  await expect(page.getByTestId('mark-resolved')).toHaveCount(0); // action form hides once resolved
});

test('care plan thresholds are physician-gated (FR-N8)', async ({ page }) => {
  const { patientId } = seedFlagWithHistory();

  await signInNurse(page);

  await page.goto(`${COCKPIT_URL}/patients/${patientId}`);
  await expect(page.getByTestId('diet-rules-input')).toBeVisible({ timeout: 10_000 });
  await expect(page.getByTestId('thresholds-input')).toHaveCount(0);
});
