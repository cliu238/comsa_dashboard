# Chrome E2E Browser Tests (REQUIRED for new features)

Browser automation tests via Chrome MCP tools (`mcp__claude-in-chrome__*`). **Required for all new features** — every user-facing change must be verified in a real browser before committing. Use Playwright (SKILL.md section 7) for reproducible CI tests; use Chrome E2E for feature verification, exploratory, and visual testing.

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

## File Upload via React Fiber (REQUIRED approach)

**IMPORTANT**: The DataTransfer API does NOT work with React. React's synthetic event system ignores manually dispatched native events on file inputs. You MUST use the React fiber approach to set files.

### Single file upload

```js
(async () => {
  const resp = await fetch('/comsa-dashboard/sample_interva_neonate.csv');
  const blob = await resp.blob();
  const file = new File([blob], 'sample_interva_neonate.csv', { type: 'text/csv' });

  const input = document.querySelector('input[type="file"]');
  const fiberKey = Object.keys(input).find(k => k.startsWith('__reactFiber$'));
  const onChange = input[fiberKey].memoizedProps?.onChange;
  onChange({ target: { files: [file] } });
  return 'File attached: ' + file.name;
})();
```

### Multi-file upload (ensemble)

```js
(async () => {
  const inputs = document.querySelectorAll('input[type="file"]');
  const files = [
    { url: '/comsa-dashboard/sample_interva_neonate.csv', name: 'sample_interva_neonate.csv' },
    { url: '/comsa-dashboard/sample_insilicova_neonate.csv', name: 'sample_insilicova_neonate.csv' }
  ];

  for (let i = 0; i < Math.min(inputs.length, files.length); i++) {
    const resp = await fetch(files[i].url);
    const blob = await resp.blob();
    const file = new File([blob], files[i].name, { type: 'text/csv' });
    const fiberKey = Object.keys(inputs[i]).find(k => k.startsWith('__reactFiber$'));
    inputs[i][fiberKey].memoizedProps?.onChange({ target: { files: [file] } });
  }
  return 'Attached ' + Math.min(inputs.length, files.length) + ' files';
})();
```

### Toggling checkboxes via React fiber

```js
const checkbox = document.querySelectorAll('input[type="checkbox"]')[INDEX];
const fiber = checkbox[Object.keys(checkbox).find(k => k.startsWith('__reactFiber$'))];
fiber.memoizedProps.onChange({ target: { checked: true } });
```

### Why React fiber?

React 18 uses its own event delegation system. Native `dispatchEvent(new Event('change'))` updates the DOM but NOT React state. The fiber approach calls React's `onChange` handler directly, correctly updating component state via `setState`/`setUploads`.

## Clicking Tab-Style Buttons

Ref-based clicking (`left_click` with `ref`) sometimes fails for tab buttons (Status/Log/Results). If a tab click doesn't change content, use **coordinate-based clicking** instead:
1. Take a screenshot to identify coordinates
2. Click using `coordinate: [x, y]`

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
4. **Upload file**: `javascript_tool` → run single file upload script (with `sample_interva_neonate.csv`)
5. **Verify file attached**: `find` → look for filename next to file input
6. **Submit**: Click "Calibrate" button
7. **Verify job created**: `find` → look for job ID or status indicator
8. **Poll until complete**: `javascript_tool` → check `document.body.innerText.includes('completed')` until true
9. **Click Results tab**: Use coordinate-based click if ref-based click doesn't switch tabs
10. **Verify result values**: `javascript_tool` → confirm `CSMF`, `Uncalibrated`, `Calibrated` in page text
11. **Screenshot #1** (results): `computer(screenshot)` → visual check of CSMF chart + results layout
12. **Verify CSMF table**: `read_page` → check table has Cause, Uncalibrated, Calibrated, 95% CI columns

## Test B — pipeline mode (openVA + vacalibration)

1. **Navigate**: Go to `localhost:5173/comsa-dashboard/`
2. **Verify app loaded**: `find` → look for "Submit Job" tab
3. **Set form**: Select "Pipeline", algorithm "InterVA"
4. **Upload file**: `javascript_tool` → file upload script (with `sample_openva_neonate.csv`)
5. **Verify file attached**: `find` → filename visible
6. **Submit**: Click "Calibrate"
7. **Verify job created**: `find` → job ID visible
8. **Poll until complete**: `javascript_tool` → status shows "completed" (longer wait — includes openVA)
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
8. **Poll until complete**: `javascript_tool` → status shows "completed"
9. **Screenshot #1** (results): `computer(screenshot)` → visual check of openVA CSMF results
10. **Verify results**: `read_page` → openVA CSMF present, no calibration results

## Test D — Demo Gallery flow

1. **Navigate**: Go to `localhost:5173/comsa-dashboard/`
2. **Verify app loaded**: `find` → look for "Demo Gallery" tab
3. **Click Demo Gallery tab**: `find` → click the tab
4. **Select a demo**: `find` → pick a scenario, click "Run This Demo"
5. **Verify job created**: `find` → job appears in job detail view
6. **Poll until complete**: `javascript_tool` → status shows "completed"
7. **Click Results tab**: Use coordinate-based click if needed
8. **Verify results**: `javascript_tool` → confirm CSMF data in page text
9. **Screenshot #1** (results): `computer(screenshot)` → visual check of demo results

## Test E — Ensemble vacalibration (multi-file upload)

Tests the ensemble workflow: 2+ algorithms with per-algorithm file uploads. This was the scenario that caused the `$` partial matching bug (job `09aec1de`).

1. **Navigate**: Go to `localhost:5173/comsa-dashboard/`
2. **Verify app loaded**: `find` → look for "Submit Job" heading
3. **Enable Ensemble**: `javascript_tool` → toggle ensemble checkbox via React fiber
4. **Check InterVA + InSilicoVA**: `javascript_tool` → check both algorithm checkboxes via React fiber
5. **Verify upload rows**: `find` → confirm 2 file input elements (one per algorithm)
6. **Upload files**: `javascript_tool` → run multi-file upload script (InterVA + InSilicoVA CSVs)
7. **Submit**: `javascript_tool` → `document.querySelector('button[type="submit"]').click()`
8. **Verify no 500 error**: `javascript_tool` → confirm no "500" or "Error" in page text
9. **Verify job running**: `javascript_tool` → confirm "running" in page text
10. **Poll until complete**: Wait ~30s, then check for "completed" (ensemble MCMC takes longer)
11. **Click Results tab**: Use coordinate-based click if needed
12. **Verify ensemble results**: `javascript_tool` → confirm "Ensemble", "InterVA", "InSilicoVA", "CSMF", "Uncalibrated" all in page text
13. **Screenshot #1** (results): `computer(screenshot)` → visual check of ensemble results (per-algorithm matrices + CSMF chart)
