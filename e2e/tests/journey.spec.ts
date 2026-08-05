import { test, expect } from '@playwright/test';
import { CAREGIVER_URL, COCKPIT_URL } from '../playwright.config';
import { seedJourneyEpisode } from './support/seed-journey-episode';

// M6 gate (Section 8): "full Ingrid day-0 -> 17 -> 90 scenario" — the
// episode is seeded starting 90 days ago (day 0) with a fired RED
// evaluation at day 17 already in its history (Domain::Flags::Lifecycle),
// so "today" for this backdated episode *is* day 90: a caregiver check-in,
// Trends/Learn/Care-team screens, a nurse triaging the day-17 flag, and
// finally day-90 graduation, all against the real backend end to end.
test('Ingrid: day-0 enrollment history, day-17 triage, day-90 check-in, Learn, Trends, Care-team, and graduation', async ({ page }) => {
  test.setTimeout(90_000);
  const journey = seedJourneyEpisode();

  // ---------------------------------------------------------------
  // Caregiver: activate + onboard, then a "today" (= day 90) check-in
  // ---------------------------------------------------------------
  await page.setViewportSize({ width: 390, height: 844 });

  await page.goto(`${CAREGIVER_URL}/activate`);
  await page.getByTestId('activation-code-input').fill(journey.activationCode);
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

  await expect(page.getByTestId('weight-input')).toBeVisible({ timeout: 10_000 });
  await page.getByTestId('weight-input').fill('70.0'); // matches the seeded day-17 weight — no 5kg confirm dialog
  await page.getByTestId('weight-next').click();

  await expect(page.locator('[data-testid^="med-"]').first()).toBeVisible();
  await page.getByTestId('medications-next').click();

  await expect(page.getByTestId('symptom-breathless-at-rest')).toBeVisible();
  await page.getByTestId('symptoms-next').click(); // day 90: no symptoms today

  await page.getByTestId('note-textarea').fill('Feeling steady, ready for the day-90 review.');
  await page.getByTestId('submit-checkin').click();

  await expect(page.getByTestId('checkin-result')).toBeVisible({ timeout: 10_000 });

  // ---------------------------------------------------------------
  // Caregiver: Trends (weight/symptom/adherence history spanning the
  // day-17 seed data through today)
  // ---------------------------------------------------------------
  await page.getByTestId('nav-trends').click();
  await expect(page.getByTestId('trends-page')).toBeVisible({ timeout: 10_000 });
  await expect(page.getByTestId('weight-trend-chart')).toBeVisible();

  // ---------------------------------------------------------------
  // Caregiver: Learn (unlock weeks — by day 90, every seeded item is
  // unlocked) + a completion event
  // ---------------------------------------------------------------
  await page.goto(`${CAREGIVER_URL}/learn`);
  await expect(page.getByTestId('learn-page')).toBeVisible({ timeout: 10_000 });
  await expect(page.getByText('Getting started')).toBeVisible();

  await page.getByText('Getting started').click();
  await page.getByText('Mark as read').click();
  await expect(page.getByTestId('learn-item-completed-badge').first()).toBeVisible({ timeout: 10_000 });

  // ---------------------------------------------------------------
  // Caregiver: Care-team — static emergency block (R4) + runtime language
  // switch (AR RTL mechanism verified separately via manual/unit checks;
  // this exercises the switch + persistence path with German)
  // ---------------------------------------------------------------
  await page.goto(`${CAREGIVER_URL}/care-team`);
  await expect(page.getByTestId('care-team-page')).toBeVisible({ timeout: 10_000 });
  await expect(page.getByTestId('emergency-block')).toBeVisible();
  await expect(page.getByTestId('emergency-call-link')).toHaveAttribute('href', 'tel:112');

  await page.getByTestId('lang-switch-de').click();
  await expect(page.locator('.back-link')).toHaveText('Zurück', { timeout: 10_000 });

  // ---------------------------------------------------------------
  // Cockpit: nurse triages the day-17 flag (open -> in_progress -> resolved)
  // ---------------------------------------------------------------
  await page.goto(`${COCKPIT_URL}/login`);
  await page.getByLabel('Email').fill(journey.nurseEmail);
  await page.getByLabel('Password').fill(journey.nursePassword);
  await page.getByRole('button', { name: 'Sign in' }).click();
  await expect(page).toHaveURL(`${COCKPIT_URL}/triage`, { timeout: 10_000 });

  const flagRow = page.getByTestId(`flag-row-${journey.day17FlagId}`);
  await expect(flagRow).toBeVisible({ timeout: 10_000 });
  await flagRow.click();
  await expect(page).toHaveURL(`${COCKPIT_URL}/triage/${journey.day17FlagId}`);

  await page.getByTestId('outcome-input').fill('acknowledged');
  await page.getByTestId('note-input').fill('Reviewed the day-17 episode — advised monitoring.');
  await page.getByTestId('mark-in-progress').click();
  await expect(page.getByTestId('interventions')).toContainText('acknowledged');

  await page.getByTestId('outcome-input').fill('resolved');
  await page.getByTestId('mark-resolved').click();
  await expect(page.getByTestId('mark-resolved')).toHaveCount(0);

  // ---------------------------------------------------------------
  // Cockpit: day-90 graduation (episode backdated 90 days at seed time —
  // eligible the moment the test runs)
  // ---------------------------------------------------------------
  await page.goto(`${COCKPIT_URL}/patients/${journey.patientId}`);
  await expect(page.getByTestId('graduation-section')).toBeVisible({ timeout: 10_000 });
  await expect(page.getByTestId('graduate-button')).toBeVisible();

  await page.getByTestId('graduate-button').click();
  await expect(page.getByTestId('graduated-note')).toBeVisible({ timeout: 15_000 });
  await expect(page.getByTestId('episode-status')).toContainText('graduated');
});
