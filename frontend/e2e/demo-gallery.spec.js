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

  // Verify full CSMF name is displayed (issue #28)
  await expect(page.locator('h3', { hasText: 'Cause-Specific Mortality Fractions (CSMF)' })).toBeVisible();

  const csmfTable = page.locator('.csmf-table');
  await expect(csmfTable).toBeVisible();
  const dataRows = csmfTable.locator('tbody tr');
  expect(await dataRows.count()).toBeGreaterThan(0);
});

test('Demo Gallery: vacalibration demo with calibrated results', async ({ page }) => {
  // 1. Navigate and switch to Demo Gallery
  await page.goto('/');
  const appTabs = page.locator('.tabs').first();
  await appTabs.getByText('Demo Gallery').click();

  // 2. Filter to Calibration demos, find Sierra Leone InterVA
  await page.locator('.demo-filters button', { hasText: 'Calibration' }).click();
  const cards = page.locator('.demo-card');
  const targetCard = cards.filter({ hasText: 'Sierra Leone' })
    .filter({ hasText: 'InterVA' })
    .filter({ hasText: 'vacalibration' });
  await expect(targetCard).toHaveCount(1);
  await targetCard.locator('.demo-launch-btn').click();

  // 3. Wait for job completion (vacalibration ~1 min)
  const jobDetail = page.locator('.job-detail');
  await expect(jobDetail).toBeVisible({ timeout: 10_000 });
  await expect(jobDetail.locator('.job-meta .status')).toHaveText('completed', { timeout: 120_000 });

  // 4. Click Results tab and verify calibrated output
  const detailTabs = jobDetail.locator('.tabs');
  await detailTabs.getByText('Results').click();

  // Summary section
  await expect(page.locator('.results-tab .summary')).toBeVisible();
  await expect(page.locator('.results-tab .summary')).toContainText('Records processed');

  // Verify full CSMF name in chart heading (issue #28)
  await expect(page.locator('h3', { hasText: 'Cause-Specific Mortality Fractions (CSMF)' })).toBeVisible();

  // CSMF table with calibrated columns
  const csmfTable = page.locator('.csmf-table');
  await expect(csmfTable).toBeVisible();
  await expect(csmfTable.locator('th', { hasText: /^Uncalibrated$/ })).toBeVisible();
  await expect(csmfTable.locator('th', { hasText: /^Calibrated$/ })).toBeVisible();
  await expect(csmfTable.locator('th', { hasText: '95% CI' })).toBeVisible();
  expect(await csmfTable.locator('tbody tr').count()).toBeGreaterThan(0);

  // Misclassification matrix
  await expect(page.locator('.misclass-section')).toBeVisible();
  await expect(page.locator('.misclass-table')).toBeVisible();
  expect(await page.locator('.matrix-cell').count()).toBeGreaterThan(0);

  // CSMF bar chart
  await expect(page.locator('.csmf-chart')).toBeVisible();
  expect(await page.locator('.bar.uncalibrated').count()).toBeGreaterThan(0);
  expect(await page.locator('.bar.calibrated').count()).toBeGreaterThan(0);

  // Issue #39: CSMF chart legend must be visible within the chart (no floating blue block)
  const chartLegend = page.locator('.csmf-chart .chart-legend');
  await expect(chartLegend).toBeVisible();
  // All 3 legend items must be visible: Uncalibrated, Calibrated, 95% CI
  await expect(chartLegend.getByText('Uncalibrated')).toBeVisible();
  await expect(chartLegend.getByText('Calibrated', { exact: true })).toBeVisible();
  await expect(chartLegend.getByText('95% CI')).toBeVisible();

  // The legend dots must NOT have position:absolute (blue block bug)
  const legendDots = chartLegend.locator('.dot');
  const dotCount = await legendDots.count();
  expect(dotCount).toBe(3);
  for (let i = 0; i < dotCount; i++) {
    const pos = await legendDots.nth(i).evaluate(el => getComputedStyle(el).position);
    expect(pos).not.toBe('absolute');
  }

  // Issue #39: Side-by-side panels must be top-aligned
  const panels = page.locator('.results-side-by-side .results-panel');
  expect(await panels.count()).toBe(2);
  const topLeft = await panels.nth(0).evaluate(el => el.getBoundingClientRect().top);
  const topRight = await panels.nth(1).evaluate(el => el.getBoundingClientRect().top);
  expect(Math.abs(topLeft - topRight)).toBeLessThan(5);
});
