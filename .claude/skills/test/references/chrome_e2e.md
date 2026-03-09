# Chrome E2E Browser Tests (Manual)

Manual E2E testing via Chrome browser automation (`mcp__claude-in-chrome__*` tools). Requires the app running locally or deployed. Use Playwright (SKILL.md section 7) for reproducible tests; use Chrome E2E for exploratory or visual testing.

## Important Constraints

> **Context limit**: Browser screenshots accumulate in the Claude Code context. Running multiple E2E tests in one session WILL exceed the 20MB limit. Run at most ONE test (A, B, C, or D) per session. If context runs out mid-test, start a fresh session.

> **Screenshot discipline**: Only take screenshots at key verification points (after page load, after results appear). Avoid screenshot-after-every-action patterns. Use `read_page` or `find` for element checks instead of screenshots when possible.

## File Upload Script

Browser security prevents setting file inputs programmatically. Use JavaScript to fetch the CSV from the public URL and attach via DataTransfer API:

```js
(async () => {
  const resp = await fetch('/comsa-dashboard/sample_interva_neonate.csv');
  const blob = await resp.blob();
  const file = new File([blob], 'sample_interva_neonate.csv', { type: 'text/csv' });
  const dt = new DataTransfer();
  dt.items.add(file);
  document.querySelector('input[type="file"]').files = dt.files;
  document.querySelector('input[type="file"]').dispatchEvent(new Event('change', { bubbles: true }));
})();
```

## Test Data (all in `frontend/public/`)

| File | Format | Used by modes |
|------|--------|---------------|
| `sample_openva_neonate.csv` | WHO2016 (350+ indicator columns, y/n/.) | pipeline, openva |
| `sample_openva_child.csv` | WHO2016 (350+ indicator columns, y/n/.) | pipeline, openva |
| `sample_interva_neonate.csv` | ID + cause (1190 records) | vacalibration |
| `sample_insilicova_neonate.csv` | ID + cause (1190 records) | vacalibration |
| `sample_eava_neonate.csv` | ID + cause (1190 records) | vacalibration |

## Test A -- vacalibration mode (fastest, no openVA computation)

1. Open the app in Chrome (navigate to localhost:5173/comsa-dashboard/ or deployed URL)
2. Verify the app loads -- check for "Submit Job" and "Demo Gallery" tabs
3. Select job type "Calibration Only" (vacalibration), algorithm "InterVA", upload `sample_interva_neonate.csv`
4. Submit -- verify job created -- poll until complete
5. Verify results: CSMF chart, misclassification matrix, CI intervals
6. Test CSV export

## Test B -- pipeline mode (full flow, uses openVA + vacalibration)

1. Open the app in Chrome (navigate to localhost:5173/comsa-dashboard/ or deployed URL)
2. Verify the app loads -- check for "Submit Job" and "Demo Gallery" tabs
3. Select job type "pipeline", algorithm "InterVA", upload `sample_openva_neonate.csv`
4. Submit -- verify job created -- poll until complete (longer, includes openVA step)
5. Verify results include both openVA CSMF and calibrated CSMF

## Test C -- openva mode (classification only)

1. Open the app in Chrome (navigate to localhost:5173/comsa-dashboard/ or deployed URL)
2. Verify the app loads -- check for "Submit Job" and "Demo Gallery" tabs
3. Select job type "openva", algorithm "InterVA", upload `sample_openva_neonate.csv`
4. Submit -- verify job created -- poll until complete
5. Verify results show openVA CSMF (no calibration results)

## Test D -- Demo Gallery flow

1. Open the app in Chrome (navigate to localhost:5173/comsa-dashboard/ or deployed URL)
2. Verify the app loads -- check for "Submit Job" and "Demo Gallery" tabs
3. Click Demo Gallery tab -- select a demo scenario -- click launch
4. Verify job appears in job list and completes
