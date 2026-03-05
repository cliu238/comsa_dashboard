import { test, expect } from '@playwright/test';

const BACKEND_URL = 'http://localhost:8000';

test.beforeAll(async () => {
  // Skip entire suite if backend is not running
  try {
    const res = await fetch(`${BACKEND_URL}/health`);
    if (!res.ok) throw new Error(`Backend returned ${res.status}`);
  } catch {
    test.skip(true, 'Backend not running — skipping E2E tests');
  }
});

test('Demo Gallery: launch demo and verify results', async ({ page }) => {
  // 1. Navigate and verify landing page
  await page.goto('/');
  await expect(page.locator('h1')).toHaveText('VA Calibration Platform');

  // 2. Switch to Demo Gallery tab
  const appTabs = page.locator('.tabs').first();
  await appTabs.getByText('Demo Gallery').click();

  // 3. Verify all 13 demo cards loaded
  const cards = page.locator('.demo-card');
  await expect(cards).toHaveCount(13);
  await expect(page.locator('.demo-filters button').first()).toContainText('All (13)');

  // 4. Test filtering — click Neonate, verify count changes, then reset
  await page.locator('.demo-filters button', { hasText: 'Neonate' }).click();
  const neonateCount = await cards.count();
  expect(neonateCount).toBeLessThan(13);
  expect(neonateCount).toBeGreaterThan(0);
  await page.locator('.demo-filters button', { hasText: /^All/ }).click();
  await expect(cards).toHaveCount(13);

  // 5. Launch the fastest demo: Neonate - InterVA - Mozambique (openVA)
  const targetCard = cards.filter({ hasText: 'Neonate' })
    .filter({ hasText: 'InterVA' })
    .filter({ hasText: 'Mozambique' })
    .filter({ hasText: 'openva' });
  await expect(targetCard).toHaveCount(1);
  await targetCard.locator('.demo-launch-btn').click();

  // 6. Verify we switched to JobDetail view
  const jobDetail = page.locator('.job-detail');
  await expect(jobDetail).toBeVisible({ timeout: 10_000 });
  await expect(jobDetail.locator('h2')).toContainText('Job:');

  // 7. Wait for job to complete (up to 120s)
  const statusBadge = jobDetail.locator('.job-meta .status');
  await expect(statusBadge).toHaveText('completed', { timeout: 120_000 });

  // 8. Click Results tab and verify CSMF table renders
  const detailTabs = jobDetail.locator('.tabs');
  await detailTabs.getByText('Results').click();
  const csmfTable = page.locator('.csmf-table');
  await expect(csmfTable).toBeVisible();
  const dataRows = csmfTable.locator('tbody tr');
  expect(await dataRows.count()).toBeGreaterThan(0);
});
