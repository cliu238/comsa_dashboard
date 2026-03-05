import { test, expect } from '@playwright/test';
import path from 'path';

const BACKEND_URL = 'http://localhost:8000';

test.beforeAll(async () => {
  try {
    const res = await fetch(`${BACKEND_URL}/health`);
    if (!res.ok) throw new Error(`Backend returned ${res.status}`);
  } catch {
    test.skip(true, 'Backend not running — skipping E2E tests');
  }
});

test('File upload: submit CSV and verify calibrated results', async ({ page }) => {
  // 1. Navigate — default tab is Calibrate (JobForm)
  await page.goto('/');
  await expect(page.locator('h1')).toHaveText('VA Calibration Platform');

  // 2. Verify form elements visible (defaults: vacalibration, InterVA, neonate, Mozambique)
  await expect(page.locator('input[type="file"]')).toBeVisible();
  const submitBtn = page.locator('button[type="submit"]');
  await expect(submitBtn).toBeVisible();

  // 3. Upload sample CSV file
  const sampleFile = path.join(import.meta.dirname, '..', 'public', 'sample_interva_neonate.csv');
  await page.locator('input[type="file"]').setInputFiles(sampleFile);

  // 4. Submit button should be enabled, click it
  await expect(submitBtn).toBeEnabled();
  await expect(submitBtn).toContainText('Calibrate');
  await submitBtn.click();

  // 5. Verify JobDetail appears
  const jobDetail = page.locator('.job-detail');
  await expect(jobDetail).toBeVisible({ timeout: 10_000 });
  await expect(jobDetail.locator('h2')).toContainText('Job:');

  // 6. Wait for job completion (vacalibration ~1-2 min)
  await expect(jobDetail.locator('.job-meta .status')).toHaveText('completed', { timeout: 120_000 });

  // 7. Click Results tab and verify calibrated output
  const detailTabs = jobDetail.locator('.tabs');
  await detailTabs.getByText('Results').click();

  await expect(page.locator('.results-tab .summary')).toBeVisible();
  await expect(page.locator('.results-tab .summary')).toContainText('Records processed');

  // CSMF table renders with data
  const csmfTable = page.locator('.csmf-table');
  await expect(csmfTable).toBeVisible();
  expect(await csmfTable.locator('tbody tr').count()).toBeGreaterThan(0);

  // Misclassification matrix renders (vacalibration job)
  await expect(page.locator('.misclass-section')).toBeVisible();
  await expect(page.locator('.misclass-table')).toBeVisible();
});
