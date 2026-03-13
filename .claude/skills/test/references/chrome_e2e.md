# Chrome E2E Browser Tests (Manual)

Manual E2E testing via Chrome browser automation (`mcp__claude-in-chrome__*` tools). Requires the app running locally or deployed. Use Playwright (SKILL.md section 7) for reproducible tests; use Chrome E2E for exploratory or visual testing.

## Tool Selection Hierarchy

For each verification step, use the lightest tool that gets the job done:

| Priority | Tool | Use when | Response size |
|----------|------|----------|---------------|
| 1st | `find` | Checking if a specific element exists (button, label, message) | ~1KB |
| 2nd | `read_page` | Checking page structure or multiple elements at once | ~5-20KB |
| 3rd | `javascript_tool` | Reading specific DOM values (text content, input values, row counts) | ~1KB |
| 4th | `computer(screenshot)` | Visual layout verification that cannot be checked structurally | ~300-800KB |

**Hard cap: max 2 screenshots per test.** Use `find`/`read_page` for all other checks.

## Pre-flight Context Check

Before starting Chrome E2E, assess the session's context load:

- If this session has already made **>10 tool calls** (Bash, Edit, Read, etc.), warn the user:
  > "This session has substantial prior context. Chrome E2E tests add ~1-2MB per test. Recommend starting a fresh session to avoid the 20MB API request limit."
- This is a **warning, not a hard block** — the user decides whether to continue or start fresh.

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

Adjust the filename in both `fetch()` and `new File()` for other sample files.

## Test Data (all in `frontend/public/`)

| File | Format | Used by modes |
|------|--------|---------------|
| `sample_openva_neonate.csv` | WHO2016 (350+ indicator columns, y/n/.) | pipeline, openva |
| `sample_openva_child.csv` | WHO2016 (350+ indicator columns, y/n/.) | pipeline, openva |
| `sample_interva_neonate.csv` | ID + cause (1190 records) | vacalibration |
| `sample_insilicova_neonate.csv` | ID + cause (1190 records) | vacalibration |
| `sample_eava_neonate.csv` | ID + cause (1190 records) | vacalibration |

## Test A — vacalibration mode (fastest, no openVA)

1. **Navigate**: Go to `localhost:5173/comsa-dashboard/` (or deployed URL)
2. **Verify app loaded**: `find` → look for "Submit Job" tab
3. **Set form**: Select "Calibration Only", algorithm "InterVA", age group "Neonate", country "Mozambique"
4. **Upload file**: `javascript_tool` → run the file upload script (with `sample_interva_neonate.csv`)
5. **Verify file attached**: `find` → look for filename next to file input
6. **Submit**: Click "Calibrate" button
7. **Verify job created**: `find` → look for job ID or status indicator
8. **Poll until complete**: `find` or `javascript_tool` → check job status text until "completed"
9. **Screenshot #1** (results): `computer(screenshot)` → visual check of CSMF chart + results layout
10. **Verify result values**: `read_page` → check CSMF table has expected columns (Uncalibrated, Calibrated, 95% CI)
11. **Test CSV export**: `javascript_tool` → trigger export, verify response

## Test B — pipeline mode (openVA + vacalibration)

1. **Navigate**: Go to `localhost:5173/comsa-dashboard/`
2. **Verify app loaded**: `find` → look for "Submit Job" tab
3. **Set form**: Select "Pipeline", algorithm "InterVA"
4. **Upload file**: `javascript_tool` → file upload script (with `sample_openva_neonate.csv`)
5. **Verify file attached**: `find` → filename visible
6. **Submit**: Click "Calibrate"
7. **Verify job created**: `find` → job ID visible
8. **Poll until complete**: `find` or `javascript_tool` → status shows "completed" (longer wait — includes openVA)
9. **Screenshot #1** (results): `computer(screenshot)` → visual check of results page
10. **Verify results**: `read_page` → check both openVA CSMF and calibrated CSMF sections present

## Test C — openva mode (classification only)

1. **Navigate**: Go to `localhost:5173/comsa-dashboard/`
2. **Verify app loaded**: `find` → look for "Submit Job" tab
3. **Set form**: Select "OpenVA Only", algorithm "InterVA"
4. **Upload file**: `javascript_tool` → file upload script (with `sample_openva_neonate.csv`)
5. **Verify file attached**: `find` → filename visible
6. **Submit**: Click submit button
7. **Verify job created**: `find` → job ID visible
8. **Poll until complete**: `find` or `javascript_tool` → status shows "completed"
9. **Screenshot #1** (results): `computer(screenshot)` → visual check of openVA CSMF results
10. **Verify results**: `read_page` → openVA CSMF present, no calibration results

## Test D — Demo Gallery flow

1. **Navigate**: Go to `localhost:5173/comsa-dashboard/`
2. **Verify app loaded**: `find` → look for "Demo Gallery" tab
3. **Click Demo Gallery tab**: `find` → click the tab
4. **Select a demo**: `find` → pick a scenario, click "Launch"
5. **Verify job created**: `find` → job appears in job list
6. **Poll until complete**: `find` or `javascript_tool` → status shows "completed"
7. **Screenshot #1** (results): `computer(screenshot)` → visual check of demo results
