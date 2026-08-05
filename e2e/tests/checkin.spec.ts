import { test, expect } from '@playwright/test';
import { CAREGIVER_URL } from '../playwright.config';
import { seedCheckInEpisode } from './support/seed-episode';

// M2 gate (Section 8): the 4-step check-in flow, ending in a result screen
// reflecting the escalation engine's real severity — here, breathless-at-
// rest (R-4) firing red end to end through the real backend.
test('caregiver completes a check-in and sees the escalation result', async ({ page }) => {
  const { activationCode } = seedCheckInEpisode();

  await page.setViewportSize({ width: 390, height: 844 });

  // --- Activate ---
  await page.goto(`${CAREGIVER_URL}/activate`);
  await page.getByTestId('activation-code-input').fill(activationCode);
  await page.getByTestId('activate-button').click();

  // --- Onboarding (language -> consents -> notification time -> pin -> orientation) ---
  await expect(page.getByTestId('lang-en')).toBeVisible({ timeout: 10_000 });
  await page.getByTestId('lang-en').click();

  for (const kind of [ 'a', 'b', 'c', 'd' ]) {
    await page.getByTestId(`consent-${kind}`).check();
  }
  await page.getByTestId('consents-next').click();
  await page.getByTestId('notification-time-next').click();
  await page.getByTestId('pin-input').fill('4821');
  await page.getByTestId('pin-next').click();
  await page.getByTestId('finish-onboarding').click();

  await expect(page).toHaveURL(`${CAREGIVER_URL}/home`, { timeout: 10_000 });

  // --- Step 1: weight (progress header + keypad) ---
  await expect(page.getByTestId('weight-input')).toBeVisible({ timeout: 10_000 });
  await page.getByTestId('weight-input').fill('68.5');
  await page.getByTestId('weight-next').click();

  // --- Step 2: medications (per-item toggle) ---
  const firstMedToggle = page.locator('[data-testid^="med-"]').first();
  await expect(firstMedToggle).toBeVisible();
  await page.getByTestId('medications-next').click();

  // --- Step 3: symptoms (dedicated breathless-at-rest toggle, R-4) ---
  await expect(page.getByTestId('symptom-breathless-at-rest')).toBeVisible();
  await page.getByTestId('symptom-breathless-at-rest').check();
  await page.getByTestId('symptoms-next').click();

  // --- Step 4: note ---
  await page.getByTestId('note-textarea').fill('Feeling a bit off today.');
  await page.getByTestId('submit-checkin').click();

  // --- Result screen ---
  await expect(page.getByTestId('checkin-result')).toBeVisible({ timeout: 10_000 });
  await expect(page.locator('.severity--red')).toBeVisible();
});
