import { test, expect } from '@playwright/test';
import { CAREGIVER_URL, COCKPIT_URL } from '../playwright.config';

// M1 gate (Section 8): ward nurse enrolls a patient in <=90s of scripted
// interaction; the caregiver activates on a 390px viewport.
test('ward nurse enrolls a patient, and the caregiver activates + onboards on a phone', async ({ browser }) => {
  const nurseContext = await browser.newContext();
  const nursePage = await nurseContext.newPage();

  const enrollmentStart = Date.now();

  await nursePage.goto(`${COCKPIT_URL}/login`);
  await nursePage.getByLabel('Email').fill('e2e-nurse@example.eu');
  await nursePage.getByLabel('Password').fill('correct horse battery staple');
  await nursePage.getByRole('button', { name: 'Sign in' }).click();

  // Sign-in lands on /triage (the nurse's home since M3) — enrollment is a
  // separate nav item now, not the post-login destination.
  await expect(nursePage).toHaveURL(`${COCKPIT_URL}/triage`, { timeout: 10_000 });
  await nursePage.goto(`${COCKPIT_URL}/enroll`);
  await expect(nursePage.getByTestId('initials')).toBeVisible({ timeout: 10_000 });

  await nursePage.getByTestId('initials').fill('I.G.');
  await nursePage.getByTestId('birth-year').fill('1949');
  await nursePage.getByTestId('nyha-class').selectOption('III');
  await nursePage.getByTestId('display-name').fill('Sabine');
  await nursePage.getByTestId('relationship').fill('daughter');
  await nursePage.getByTestId('language').selectOption('en');

  await nursePage.getByTestId('medication-search').fill('Ramipril');
  await nursePage.locator('.matches li button').first().click();

  await nursePage.getByTestId('submit-enrollment').click();
  await expect(nursePage.getByTestId('enrollment-result')).toBeVisible({ timeout: 10_000 });

  const enrollmentSeconds = (Date.now() - enrollmentStart) / 1000;
  expect(enrollmentSeconds, `scripted enrollment took ${enrollmentSeconds}s, want <=90s`).toBeLessThanOrEqual(90);

  const code = (await nursePage.getByTestId('activation-code').textContent())!.trim();
  expect(code).toHaveLength(8);

  await nurseContext.close();

  // --- Caregiver activates on a 390px viewport ---
  const caregiverContext = await browser.newContext({ viewport: { width: 390, height: 844 } });
  const caregiverPage = await caregiverContext.newPage();

  await caregiverPage.goto(`${CAREGIVER_URL}/activate`);
  await caregiverPage.getByTestId('activation-code-input').fill(code);
  await caregiverPage.getByTestId('activate-button').click();

  await expect(caregiverPage.getByTestId('lang-en')).toBeVisible({ timeout: 10_000 });
  await caregiverPage.getByTestId('lang-en').click();

  await expect(caregiverPage.getByTestId('consent-a')).toBeVisible();
  for (const kind of [ 'a', 'b', 'c', 'd' ]) {
    await caregiverPage.getByTestId(`consent-${kind}`).check();
  }
  await caregiverPage.getByTestId('consents-next').click();

  await expect(caregiverPage.getByTestId('notification-time')).toBeVisible();
  await caregiverPage.getByTestId('notification-time-next').click();

  await expect(caregiverPage.getByTestId('pin-input')).toBeVisible();
  await caregiverPage.getByTestId('pin-input').fill('4821');
  await caregiverPage.getByTestId('pin-next').click();

  await expect(caregiverPage.getByTestId('finish-onboarding')).toBeVisible();
  await caregiverPage.getByTestId('finish-onboarding').click();

  await expect(caregiverPage).toHaveURL(`${CAREGIVER_URL}/home`, { timeout: 10_000 });

  await caregiverContext.close();
});
