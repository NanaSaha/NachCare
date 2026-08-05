import { test, expect } from '@playwright/test';
import { CAREGIVER_URL } from '../playwright.config';
import { seedCheckInEpisode } from './support/seed-episode';

// M5 gate (Section 8): assistant chat against the real dev backend, whose
// AI gateway defaults to Domain::Ai::Providers::StubProvider in
// development (ADR-0007) — this is "gateway stubbed" by construction, no
// network mocking needed. Exercises the real 4-stage pipeline end to end:
// in-scope answer with a citation, a medication question routed to the
// nurse, and an emergency phrase triggering the static R4 112 block.
test.describe('assistant', () => {
  async function activateAndOnboard(page: import('@playwright/test').Page): Promise<void> {
    const { activationCode } = seedCheckInEpisode();

    await page.setViewportSize({ width: 390, height: 844 });
    await page.goto(`${CAREGIVER_URL}/activate`);
    await page.getByTestId('activation-code-input').fill(activationCode);
    await page.getByTestId('activate-button').click();

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
  }

  test('answers an in-scope question with a source citation', async ({ page }) => {
    await activateAndOnboard(page);

    await page.goto(`${CAREGIVER_URL}/assistant`);
    await page.getByTestId('assistant-input').fill('How do I log a symptom in the app?');
    await page.getByTestId('assistant-send').click();

    await expect(page.getByTestId('turn-citation')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByTestId('turn-routed-chip')).toHaveCount(0);
  });

  test('routes a medication question to the nurse instead of answering it', async ({ page }) => {
    await activateAndOnboard(page);

    await page.goto(`${CAREGIVER_URL}/assistant`);
    await page.getByTestId('assistant-input').fill("Should I skip today's dose?");
    await page.getByTestId('assistant-send').click();

    await expect(page.getByTestId('turn-routed-chip')).toBeVisible({ timeout: 10_000 });
  });

  test('one-tap send-to-nurse escalates an answered turn', async ({ page }) => {
    await activateAndOnboard(page);

    await page.goto(`${CAREGIVER_URL}/assistant`);
    await page.getByTestId('assistant-input').fill('How do I log a symptom in the app?');
    await page.getByTestId('assistant-send').click();

    await expect(page.getByTestId('escalate-button')).toBeVisible({ timeout: 10_000 });
    await page.getByTestId('escalate-button').click();
    await expect(page.getByTestId('turn-escalated-chip')).toBeVisible({ timeout: 10_000 });
  });

  test('shows the static 112 emergency block on an emergency message (R4)', async ({ page }) => {
    await activateAndOnboard(page);

    // The literal string below is the first entry in
    // backend/config/ai_emergency_phrases.yml#en — a PLACEHOLDER_CLINICAL
    // sentinel (not real clinical wording, see docs/OPEN_CLINICAL_ITEMS.md
    // #3), used here exactly the way the escalation-engine e2e specs
    // reference the seeded ruleset's own placeholder phrases.
    await page.goto(`${CAREGIVER_URL}/assistant`);
    await page.getByTestId('assistant-input').fill('PLACEHOLDER_CLINICAL_EMERGENCY_PHRASE_EN_01, please help');
    await page.getByTestId('assistant-send').click();

    await expect(page.getByTestId('emergency-block')).toBeVisible({ timeout: 10_000 });
    await expect(page.getByTestId('emergency-call-link')).toHaveAttribute('href', 'tel:112');
  });
});
