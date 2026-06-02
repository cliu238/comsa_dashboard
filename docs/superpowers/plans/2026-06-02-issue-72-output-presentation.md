# Issue #72 Output Presentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the calibration results view (faceted CSMF figure, small-multiples misclassification matrices, one consolidated table), fix the negative elapsed-time bug, fix the summary wording, and remove the broken server-side calibration PDF plus redundant download UI.

**Architecture:** Almost entirely a frontend presentation change. The backend already returns every value the new figures need (`per_algorithm` includes each algorithm *and* the `ensemble` row; `misclassification_matrix` is keyed per algorithm). The only backend change is *removing* the broken `pdf()` plot generation. Figures render in-app and export via the existing html2canvas `exportToPNG`/`exportToPDF` helpers.

**Tech Stack:** React (Vite), vitest + @testing-library/react (jsdom), plain CSS in `src/App.css`, R plumber backend.

**Spec:** `docs/superpowers/specs/2026-06-02-issue-72-output-presentation-design.md`

**Branch:** `feat/72-output-presentation` (already checked out; the spec is already committed here).

---

## File Structure

New/changed files and their single responsibility:

- `frontend/src/utils/labels.js` (**create**) — display-label helpers: `formatAlgorithmName`, `formatAlgorithmList`, `formatAgeGroup`. One source of truth for `interva`→`InterVA`, `neonate`→`Neonate (0-27 days)`, etc.
- `frontend/src/utils/labels.test.js` (**create**) — unit tests for the label helpers.
- `frontend/src/utils/progress.js` (**modify**) — fix `getElapsedTime` UTC parsing + clamp.
- `frontend/src/utils/progress.test.js` (**modify**) — add regression tests for the `-14396s` bug.
- `frontend/src/components/CSMFChart.js` (**modify**) — replace `computeCSMFChartData` with CSMF view-model builders `buildCsmfFacets` and `buildCsmfTableRows`.
- `frontend/src/components/CSMFChart.test.js` (**modify/replace**) — test the new builders.
- `frontend/src/components/JobDetail.jsx` (**modify**) — summary wording; faceted chart component; consolidated table; remove per-algorithm tables, bulk download list, and PDF section.
- `frontend/src/components/MisclassificationMatrix.jsx` (**modify**) — small-multiples restyle, integer %, import shared `formatAlgorithmName`.
- `frontend/src/App.css` (**modify**) — styles for faceted chart, matrix small-multiples, consolidated table.
- `backend/jobs/algorithms/vacalibration.R` (**modify**) — remove `pdf()` plot generation and `files$plot`.

Tests run with: `cd frontend && npm test` (vitest). Run a single file with `cd frontend && npx vitest run src/utils/labels.test.js`.

---

## Task 1: Fix the negative elapsed-time bug

**Files:**
- Modify: `frontend/src/utils/progress.js:194-217`
- Test: `frontend/src/utils/progress.test.js:210-252`

Root cause: `new Date("2026-05-30 13:48:14.922977")` (R's UTC timestamp, no timezone suffix) is parsed as **local** time, yielding a negative elapsed value (`-14396s` ≈ −4h for a UTC−4 user).

- [ ] **Step 1: Add failing regression tests**

Add these two `it` blocks inside the existing `describe('getElapsedTime', ...)` in `frontend/src/utils/progress.test.js` (after the array-format test at line ~251, before the closing `})`):

```js
  it('treats a space-separated R timestamp (no timezone) as UTC, not local', () => {
    // R writes "YYYY-MM-DD HH:MM:SS.ffffff" in UTC with no tz suffix.
    const now = new Date('2026-05-30T13:48:30Z')
    vi.setSystemTime(now)
    const result = getElapsedTime('2026-05-30 13:48:14.922977')
    expect(result).toBe('16s') // 30s - 14s, NOT a negative number
  })

  it('never returns a negative elapsed time (clamped to 0)', () => {
    const now = new Date('2026-05-30T13:48:14Z')
    vi.setSystemTime(now)
    // start is a few seconds after "now" — must clamp, not show negative
    const result = getElapsedTime('2026-05-30 13:48:20')
    expect(result).toBe('0s')
  })
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `cd frontend && npx vitest run src/utils/progress.test.js`
Expected: the two new tests FAIL (the first yields a large negative-derived string; the second yields a negative number).

- [ ] **Step 3: Implement the UTC-aware parse + clamp**

In `frontend/src/utils/progress.js`, replace the body of `getElapsedTime` (lines 194-217) with:

```js
function parseTimestamp(value) {
  if (Array.isArray(value)) return new Date(value[0] * 1000);
  if (typeof value !== 'string') return new Date(value);
  // ISO strings carrying an explicit timezone (Z or ±hh:mm) parse correctly as-is.
  const hasTz = /[zZ]$|[+-]\d{2}:?\d{2}$/.test(value);
  if (hasTz) return new Date(value);
  // R writes UTC timestamps with no tz suffix, e.g. "2026-05-30 13:48:14.922977".
  // Normalize to an explicit UTC instant so the browser doesn't read it as local time.
  return new Date(value.replace(' ', 'T') + 'Z');
}

export function getElapsedTime(startedAt) {
  if (!startedAt) return null;

  const start = parseTimestamp(startedAt);
  const now = new Date();
  const elapsed = Math.max(0, Math.floor((now - start) / 1000));

  if (elapsed < 60) {
    return `${elapsed}s`;
  } else if (elapsed < 3600) {
    const mins = Math.floor(elapsed / 60);
    const secs = elapsed % 60;
    return `${mins}m ${secs}s`;
  } else {
    const hours = Math.floor(elapsed / 3600);
    const mins = Math.floor((elapsed % 3600) / 60);
    return `${hours}h ${mins}m`;
  }
}
```

- [ ] **Step 4: Run the full progress test file and confirm all pass**

Run: `cd frontend && npx vitest run src/utils/progress.test.js`
Expected: PASS, including the 4 pre-existing `getElapsedTime` tests (the `...Z` and array cases still parse correctly) and the 2 new tests.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/utils/progress.js frontend/src/utils/progress.test.js
git commit -m "fix(results): parse R UTC timestamps correctly in elapsed time (#72)"
```

---

## Task 2: Shared display-label helpers

**Files:**
- Create: `frontend/src/utils/labels.js`
- Test: `frontend/src/utils/labels.test.js`

Centralize algorithm/age-group display names so the summary, chart, matrix, and table all agree. Today `formatAlgorithmName` lives privately in `MisclassificationMatrix.jsx:45-52`; this task creates the shared version (Task 9 switches the matrix to import it).

- [ ] **Step 1: Write the failing test**

Create `frontend/src/utils/labels.test.js`:

```js
import { describe, it, expect } from 'vitest'
import { formatAlgorithmName, formatAlgorithmList, formatAgeGroup } from './labels.js'

describe('formatAlgorithmName', () => {
  it('maps known algorithm keys to proper names', () => {
    expect(formatAlgorithmName('interva')).toBe('InterVA')
    expect(formatAlgorithmName('insilicova')).toBe('InSilicoVA')
    expect(formatAlgorithmName('eava')).toBe('EAVA')
    expect(formatAlgorithmName('ensemble')).toBe('Ensemble')
  })

  it('is case-insensitive', () => {
    expect(formatAlgorithmName('InterVA')).toBe('InterVA')
  })

  it('uppercases unknown keys', () => {
    expect(formatAlgorithmName('foo')).toBe('FOO')
  })

  it('returns empty string for nullish input', () => {
    expect(formatAlgorithmName(null)).toBe('')
    expect(formatAlgorithmName(undefined)).toBe('')
  })
})

describe('formatAlgorithmList', () => {
  it('joins multiple algorithms with commas and proper names', () => {
    expect(formatAlgorithmList(['eava', 'insilicova', 'interva']))
      .toBe('EAVA, InSilicoVA, InterVA')
  })

  it('accepts a single string', () => {
    expect(formatAlgorithmList('eava')).toBe('EAVA')
  })
})

describe('formatAgeGroup', () => {
  it('maps neonate and child to friendly labels', () => {
    expect(formatAgeGroup('neonate')).toBe('Neonate (0-27 days)')
    expect(formatAgeGroup('child')).toBe('Children (1-59 months)')
  })

  it('returns the input unchanged for unknown groups', () => {
    expect(formatAgeGroup('adult')).toBe('adult')
  })
})
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `cd frontend && npx vitest run src/utils/labels.test.js`
Expected: FAIL — "Failed to resolve import './labels.js'".

- [ ] **Step 3: Implement `labels.js`**

Create `frontend/src/utils/labels.js`:

```js
/**
 * Display-label helpers for algorithm and age-group names.
 * Single source of truth so the summary, figures, and tables stay consistent.
 */

const ALGORITHM_NAMES = {
  interva: 'InterVA',
  insilicova: 'InSilicoVA',
  eava: 'EAVA',
  ensemble: 'Ensemble',
};

export function formatAlgorithmName(algo) {
  if (!algo) return '';
  const key = String(algo).toLowerCase();
  return ALGORITHM_NAMES[key] || String(algo).toUpperCase();
}

/** Format one algorithm or an array of them as a comma-separated proper-name list. */
export function formatAlgorithmList(algorithms) {
  const arr = Array.isArray(algorithms) ? algorithms : [algorithms];
  return arr.map(formatAlgorithmName).join(', ');
}

const AGE_GROUP_LABELS = {
  neonate: 'Neonate (0-27 days)',
  child: 'Children (1-59 months)',
};

export function formatAgeGroup(ageGroup) {
  if (!ageGroup) return '';
  return AGE_GROUP_LABELS[String(ageGroup).toLowerCase()] || ageGroup;
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `cd frontend && npx vitest run src/utils/labels.test.js`
Expected: PASS (all blocks).

- [ ] **Step 5: Commit**

```bash
git add frontend/src/utils/labels.js frontend/src/utils/labels.test.js
git commit -m "feat(results): add shared algorithm/age-group label helpers (#72)"
```

---

## Task 3: Summary block wording

**Files:**
- Modify: `frontend/src/components/JobDetail.jsx` — `CalibratedResults` summary (lines 293-324), `OpenVAResults` summary (lines 235-237)
- Test: `frontend/src/components/JobDetail.test.js`

Remove "Records processed:"; show algorithms comma-separated + proper-cased; show the friendly age-group label.

- [ ] **Step 1: Add failing source-assertion tests**

`JobDetail.test.js` asserts against the component source string (its existing pattern). Append a new `describe` block at the end of `frontend/src/components/JobDetail.test.js` (before EOF):

```js
describe('Summary block wording (issue #72)', () => {
  it('does not render a "Records processed" line', () => {
    expect(jobDetailSrc).not.toContain('Records processed')
  })

  it('uses the shared formatAlgorithmList for algorithm display', () => {
    expect(jobDetailSrc).toContain('formatAlgorithmList(')
  })

  it('uses the shared formatAgeGroup for the age group label', () => {
    expect(jobDetailSrc).toContain('formatAgeGroup(')
  })
})
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `cd frontend && npx vitest run src/components/JobDetail.test.js`
Expected: FAIL — source still contains "Records processed" and does not yet call the helpers.

- [ ] **Step 3: Wire the helpers into JobDetail**

In `frontend/src/components/JobDetail.jsx`:

3a. Add the import near the other util imports (after line 6):

```js
import { formatAlgorithmList, formatAgeGroup } from '../utils/labels.js';
```

3b. In `CalibratedResults`, replace the `algorithmsDisplay` definition (lines 293-295):

```js
  const algorithmsDisplay = formatAlgorithmList(results.algorithm);
```

3c. Replace the summary block (lines 314-324) with:

```jsx
      <div className="summary">
        <p><strong>Algorithm(s):</strong> {algorithmsDisplay}</p>
        <p><strong>Age group:</strong> {formatAgeGroup(results.age_group)}</p>
        <p><strong>Country:</strong> {results.country === 'other' ? 'All the countries' : results.country}</p>
        {isEnsemble && (
          <p className="ensemble-indicator">
            <strong>✓ Ensemble Mode:</strong> Results calibrated across {results.algorithm.length} algorithms
          </p>
        )}
      </div>
```

3d. In `OpenVAResults`, remove the "Records processed" summary (lines 235-237):

```jsx
      <div className="summary">
        <p><strong>Algorithm:</strong> {formatAlgorithmList(results.algorithm || 'OpenVA')}</p>
      </div>
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `cd frontend && npx vitest run src/components/JobDetail.test.js`
Expected: PASS, including the pre-existing issue-#28 heading tests.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/components/JobDetail.jsx frontend/src/components/JobDetail.test.js
git commit -m "feat(results): clean up summary wording and input echo (#72)"
```

---

## Task 4: Remove broken server-side calibration PDF

**Files:**
- Modify: `backend/jobs/algorithms/vacalibration.R` (lines 154-178, 241-245, 291)

The `pdf()`/`dev.off()` wrapper produces a `calibration_plot.pdf` that won't open. Figures now render in-app, so remove the PDF generation entirely. Keep the `vacalibration()` call.

- [ ] **Step 1: Remove the pdf device around the vacalibration call**

In `backend/jobs/algorithms/vacalibration.R`, replace lines 154-178 (from the `# Run vacalibration with plot capture` comment through the `dev.off()` after the `tryCatch`) with:

```r
  # Run vacalibration
  output_dir <- file.path("data", "outputs", job$id)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  result <- run_with_capture(job$id, {
    vacalibration(
      va_data = va_input,
      age_group = job$age_group,
      country = job$country,
      missmat_type = missmat_type,
      ensemble = ensemble_val,
      nMCMC = n_mcmc,
      nBurn = n_burn,
      nThin = n_thin,
      verbose = TRUE
    )
  })
```

- [ ] **Step 2: Remove the plot-file persistence block**

Replace lines 241-245 (the `# Save calibration plot` block):

```r
  # Save outputs (output_dir already created above)
```

(That single comment replaces the `if (file.exists(plot_file) ...) { add_job_file(...) }` block. The existing `# Save outputs (output_dir already created above for plot capture)` comment at line 239 can be deleted or left; ensure no `plot_file` reference remains.)

- [ ] **Step 3: Drop `plot` from the returned files list**

Change line 291 from:

```r
    files = list(summary = "calibration_summary.csv", plot = "calibration_plot.pdf")
```

to:

```r
    files = list(summary = "calibration_summary.csv")
```

- [ ] **Step 4: Verify no plot references remain**

Run: `grep -n "plot_file\|calibration_plot.pdf\|pdf(\|dev.off" backend/jobs/algorithms/vacalibration.R`
Expected: **no output** (all references removed).

- [ ] **Step 5: Smoke-test the R changes don't break (input-only, <10s)**

Check the backend dependency and run the fast R test. (Per CLAUDE.md: do not skip; start backend deps as needed.)

Run: `cd backend && Rscript ../tests/test_vacalibration_backend.R --input-only`
Expected: completes without error (the suite tests `vacalibration()` directly; removing the PDF wrapper must not affect it).

- [ ] **Step 6: Commit**

```bash
git add backend/jobs/algorithms/vacalibration.R
git commit -m "fix(backend): drop broken calibration_plot.pdf generation (#72)"
```

---

## Task 5: CSMF view-model builders (`buildCsmfFacets`, `buildCsmfTableRows`)

**Files:**
- Modify: `frontend/src/components/CSMFChart.js`
- Test: `frontend/src/components/CSMFChart.test.js` (replace contents)

The faceted chart uses a fixed `[0,1]` y-axis, so the old `maxVal` normalization in `computeCSMFChartData` is gone. Replace it with two pure builders that turn a results object into facet/table view-models. Both share the per-algorithm-vs-single fallback logic.

- [ ] **Step 1: Replace the test file**

Replace the entire contents of `frontend/src/components/CSMFChart.test.js` with:

```js
import { describe, it, expect } from 'vitest'
import { buildCsmfFacets, buildCsmfTableRows } from './CSMFChart.js'

const single = {
  algorithm: 'eava',
  cause_order: ['prematurity', 'sepsis_meningitis_inf', 'pneumonia'],
  uncalibrated_csmf: { prematurity: 0.40, sepsis_meningitis_inf: 0.35, pneumonia: 0.25 },
  calibrated_csmf:   { prematurity: 0.30, sepsis_meningitis_inf: 0.45, pneumonia: 0.25 },
  calibrated_ci_lower: { prematurity: 0.20, sepsis_meningitis_inf: 0.30, pneumonia: 0.15 },
  calibrated_ci_upper: { prematurity: 0.42, sepsis_meningitis_inf: 0.55, pneumonia: 0.35 },
}

const ensemble = {
  algorithm: ['eava', 'interva'],
  cause_order: ['prematurity', 'pneumonia'],
  uncalibrated_csmf: { prematurity: 0.29, pneumonia: 0.12 },
  calibrated_csmf:   { prematurity: 0.12, pneumonia: 0.09 },
  calibrated_ci_lower: { prematurity: 0.06, pneumonia: 0.02 },
  calibrated_ci_upper: { prematurity: 0.19, pneumonia: 0.21 },
  per_algorithm: {
    eava:     { uncalibrated_csmf: { prematurity: 0.19, pneumonia: 0.24 }, calibrated_csmf: { prematurity: 0.13, pneumonia: 0.24 }, calibrated_ci_lower: { prematurity: 0.05, pneumonia: 0.07 }, calibrated_ci_upper: { prematurity: 0.23, pneumonia: 0.45 } },
    interva:  { uncalibrated_csmf: { prematurity: 0.42, pneumonia: 0.07 }, calibrated_csmf: { prematurity: 0.44, pneumonia: 0.08 }, calibrated_ci_lower: { prematurity: 0.26, pneumonia: 0.01 }, calibrated_ci_upper: { prematurity: 0.62, pneumonia: 0.21 } },
    ensemble: { uncalibrated_csmf: { prematurity: 0.29, pneumonia: 0.12 }, calibrated_csmf: { prematurity: 0.12, pneumonia: 0.09 }, calibrated_ci_lower: { prematurity: 0.06, pneumonia: 0.02 }, calibrated_ci_upper: { prematurity: 0.19, pneumonia: 0.21 } },
  },
}

describe('buildCsmfFacets', () => {
  it('returns a single facet for a single-algorithm result', () => {
    const facets = buildCsmfFacets(single)
    expect(facets).toHaveLength(1)
    expect(facets[0].label).toBe('EAVA')
    expect(facets[0].causes.map(c => c.cause)).toEqual(['prematurity', 'sepsis_meningitis_inf', 'pneumonia'])
  })

  it('keeps raw [0,1] fractions (no maxVal normalization)', () => {
    const facets = buildCsmfFacets(single)
    const prem = facets[0].causes.find(c => c.cause === 'prematurity')
    expect(prem.calibrated).toBeCloseTo(0.30, 5)
    expect(prem.uncalibrated).toBeCloseTo(0.40, 5)
    expect(prem.ciLower).toBeCloseTo(0.20, 5)
    expect(prem.ciUpper).toBeCloseTo(0.42, 5)
  })

  it('returns one facet per algorithm plus ensemble, with ensemble last', () => {
    const facets = buildCsmfFacets(ensemble)
    expect(facets.map(f => f.label)).toEqual(['EAVA', 'InterVA', 'Ensemble'])
  })

  it('orders causes by cause_order across every facet', () => {
    const facets = buildCsmfFacets(ensemble)
    facets.forEach(f => expect(f.causes.map(c => c.cause)).toEqual(['prematurity', 'pneumonia']))
  })

  it('returns [] for nullish input', () => {
    expect(buildCsmfFacets(null)).toEqual([])
  })
})

describe('buildCsmfTableRows', () => {
  it('produces one group per algorithm (ensemble last) with two rows each', () => {
    const { groups } = buildCsmfTableRows(ensemble)
    expect(groups.map(g => g.algorithm)).toEqual(['EAVA', 'InterVA', 'Ensemble'])
    groups.forEach(g => expect(g.rows.map(r => r.type)).toEqual(['Uncalibrated', 'Calibrated']))
  })

  it('falls back to a single group for single-algorithm results', () => {
    const { groups } = buildCsmfTableRows(single)
    expect(groups).toHaveLength(1)
    expect(groups[0].algorithm).toBe('EAVA')
  })

  it('formats values as integer percents; uncalibrated has no CI, calibrated does', () => {
    const { groups } = buildCsmfTableRows(single)
    const [uncal, cal] = groups[0].rows
    const premUncal = uncal.cells.find(c => c.cause === 'prematurity')
    const premCal = cal.cells.find(c => c.cause === 'prematurity')
    expect(premUncal.mean).toBe(40)
    expect(premUncal.lower).toBeNull()
    expect(premCal.mean).toBe(30)
    expect(premCal.lower).toBe(20)
    expect(premCal.upper).toBe(42)
  })

  it('exposes the ordered cause list', () => {
    const { causes } = buildCsmfTableRows(single)
    expect(causes).toEqual(['prematurity', 'sepsis_meningitis_inf', 'pneumonia'])
  })
})
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `cd frontend && npx vitest run src/components/CSMFChart.test.js`
Expected: FAIL — `buildCsmfFacets` / `buildCsmfTableRows` are not exported.

- [ ] **Step 3: Implement the builders**

Replace the entire contents of `frontend/src/components/CSMFChart.js` with:

```js
/**
 * CSMF view-model builders. Pure functions (no React) used by the results chart,
 * the consolidated table, and tests. Handles the per-algorithm (ensemble) shape
 * and the single-algorithm fallback in one place.
 */
import { orderCauses } from '../utils/causeDisplay.js';
import { formatAlgorithmName } from '../utils/labels.js';

const ENSEMBLE_KEY = 'ensemble';

// Sort comparator that pushes the ensemble entry to the end, others stable.
function ensembleLast(a, b) {
  return (a === ENSEMBLE_KEY ? 1 : 0) - (b === ENSEMBLE_KEY ? 1 : 0);
}

function orderedCauses(results) {
  return orderCauses(Object.keys(results.calibrated_csmf || {}), results.cause_order);
}

/**
 * Build per-algorithm facets for the CSMF figure.
 * Each facet: { label, causes: [{ cause, uncalibrated, calibrated, ciLower, ciUpper }] }
 * Values are raw [0,1] fractions (the chart fixes the y-axis to [0,1]).
 */
export function buildCsmfFacets(results) {
  if (!results) return [];
  const causes = orderedCauses(results);

  const makeFacet = (label, uncal, cal, lo, hi) => ({
    label,
    causes: causes.map(cause => ({
      cause,
      uncalibrated: uncal?.[cause] ?? 0,
      calibrated: cal?.[cause] ?? 0,
      ciLower: lo?.[cause] ?? null,
      ciUpper: hi?.[cause] ?? null,
    })),
  });

  if (results.per_algorithm) {
    return Object.keys(results.per_algorithm).sort(ensembleLast).map(key => {
      const d = results.per_algorithm[key];
      return makeFacet(formatAlgorithmName(key), d.uncalibrated_csmf, d.calibrated_csmf, d.calibrated_ci_lower, d.calibrated_ci_upper);
    });
  }

  const algo = Array.isArray(results.algorithm) ? results.algorithm[0] : results.algorithm;
  return [makeFacet(formatAlgorithmName(algo), results.uncalibrated_csmf, results.calibrated_csmf, results.calibrated_ci_lower, results.calibrated_ci_upper)];
}

const pct = v => (v == null ? null : Math.round(v * 100));

/**
 * Build the consolidated CSMF table view-model.
 * Returns { causes, groups: [{ algorithm, rows: [{ type, cells: [{cause, mean, lower, upper}] }] }] }
 * Uncalibrated cells carry mean only (backend provides no uncalibrated CI);
 * Calibrated cells carry mean + lower/upper. All values are integer percents.
 */
export function buildCsmfTableRows(results) {
  if (!results) return { causes: [], groups: [] };
  const causes = orderedCauses(results);

  const makeGroup = (label, uncal, cal, lo, hi) => ({
    algorithm: label,
    rows: [
      { type: 'Uncalibrated', cells: causes.map(c => ({ cause: c, mean: pct(uncal?.[c]), lower: null, upper: null })) },
      { type: 'Calibrated', cells: causes.map(c => ({ cause: c, mean: pct(cal?.[c]), lower: pct(lo?.[c]), upper: pct(hi?.[c]) })) },
    ],
  });

  if (results.per_algorithm) {
    const groups = Object.keys(results.per_algorithm).sort(ensembleLast).map(key => {
      const d = results.per_algorithm[key];
      return makeGroup(formatAlgorithmName(key), d.uncalibrated_csmf, d.calibrated_csmf, d.calibrated_ci_lower, d.calibrated_ci_upper);
    });
    return { causes, groups };
  }

  const algo = Array.isArray(results.algorithm) ? results.algorithm[0] : results.algorithm;
  return { causes, groups: [makeGroup(formatAlgorithmName(algo), results.uncalibrated_csmf, results.calibrated_csmf, results.calibrated_ci_lower, results.calibrated_ci_upper)] };
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `cd frontend && npx vitest run src/components/CSMFChart.test.js`
Expected: PASS (all blocks).

- [ ] **Step 5: Commit**

```bash
git add frontend/src/components/CSMFChart.js frontend/src/components/CSMFChart.test.js
git commit -m "feat(results): add faceted CSMF chart + consolidated table builders (#72)"
```

---

## Task 6: Render the faceted CSMF figure + CSS

**Files:**
- Modify: `frontend/src/components/JobDetail.jsx` — `CSMFChart` component (lines 452-497) and its usage (lines 336-354)
- Modify: `frontend/src/App.css` (replace the `.csmf-chart` block region, lines ~1005-1130)
- Test: covered by Task 5 builder tests + the Task 11 full run.

Replace the horizontal single-facet chart with vertical small-multiples on a fixed `[0,1]` y-axis.

- [ ] **Step 1: Replace the `CSMFChart` component**

In `frontend/src/components/JobDetail.jsx`, replace the entire `CSMFChart` function (lines 452-497) with:

```jsx
const Y_TICKS = [1, 0.75, 0.5, 0.25, 0];

function CSMFChart({ results, causeDisplayNames }) {
  const facets = buildCsmfFacets(results);
  if (facets.length === 0) return null;

  return (
    <div className="csmf-figure">
      <div className="csmf-facets">
        {facets.map(facet => (
          <div key={facet.label} className="csmf-facet">
            <div className="csmf-facet-title">{facet.label}</div>
            <div className="csmf-plot">
              <div className="csmf-yaxis">
                {Y_TICKS.map(t => (
                  <span key={t} className="csmf-ytick" style={{ bottom: `${t * 100}%` }}>
                    {t === 1 ? '1.0' : t === 0 ? '0' : t.toFixed(2).slice(1)}
                  </span>
                ))}
              </div>
              <div className="csmf-plotarea">
                {Y_TICKS.map(t => (
                  <div key={t} className="csmf-gridline" style={{ bottom: `${t * 100}%` }} />
                ))}
                <div className="csmf-bars">
                  {facet.causes.map(({ cause, uncalibrated, calibrated, ciLower, ciUpper }) => (
                    <div key={cause} className="csmf-group" title={formatCauseDisplay(cause, causeDisplayNames)}>
                      <div className="csmf-bar uncal" style={{ height: `${uncalibrated * 100}%` }}
                        title={`Uncalibrated: ${(uncalibrated * 100).toFixed(1)}%`} />
                      <div className="csmf-bar cal" style={{ height: `${calibrated * 100}%` }}
                        title={`Calibrated: ${(calibrated * 100).toFixed(1)}%`}>
                        {ciLower != null && ciUpper != null && (
                          <div className="csmf-whisker"
                            style={{ bottom: `${(ciLower - calibrated) * 100}%`, height: `${(ciUpper - ciLower) * 100}%` }}
                            title={`95% CI: [${(ciLower * 100).toFixed(1)}% - ${(ciUpper * 100).toFixed(1)}%]`} />
                        )}
                      </div>
                    </div>
                  ))}
                </div>
              </div>
            </div>
            <div className="csmf-xlabels">
              {facet.causes.map(({ cause }) => (
                <span key={cause} className="csmf-xlabel">{formatCauseDisplay(cause, causeDisplayNames)}</span>
              ))}
            </div>
          </div>
        ))}
      </div>
      <div className="csmf-legend">
        <span><span className="csmf-dot uncal" /> Uncalibrated</span>
        <span><span className="csmf-dot cal" /> Calibrated</span>
        <span><span className="csmf-dot ci" /> 95% CI</span>
      </div>
    </div>
  );
}
```

Note: the whisker sits inside the calibrated bar; `bottom: (ciLower - calibrated)*100%` positions its base relative to the bar top, so it spans `ciLower → ciUpper` in plot coordinates.

- [ ] **Step 2: Update the chart usage and import**

2a. Add to the imports from `./CSMFChart.js`. Replace line 5:

```js
import { buildCsmfFacets, buildCsmfTableRows } from './CSMFChart.js';
```

2b. In `CalibratedResults`, replace the right-hand "CSMF Chart" panel (the `<div ref={chartRef}>...</div>` at lines 344-353) so it passes the whole results object:

```jsx
          <div ref={chartRef}>
            <CSMFChart results={results} causeDisplayNames={displayNames} />
          </div>
```

(The surrounding `section-header` with PNG/PDF export buttons stays; `chartRef` is unchanged.)

- [ ] **Step 3: Replace the chart CSS**

In `frontend/src/App.css`, replace the legacy chart styles (the contiguous block from `.csmf-chart {` at line ~1005 through the end of `.error-bar-whisker` rules near line ~1130) with:

```css
.csmf-figure { margin: 12px 0 8px; }
.csmf-facets { display: flex; gap: 16px; overflow-x: auto; padding-bottom: 6px; }
.csmf-facet { flex: 1 1 200px; min-width: 200px; }
.csmf-facet-title { text-align: center; font-weight: 600; color: #334155; margin-bottom: 6px; }
.csmf-plot { position: relative; display: flex; height: 200px; }
.csmf-yaxis { position: relative; width: 30px; }
.csmf-ytick { position: absolute; right: 4px; transform: translateY(50%); font-size: 10px; color: #94a3b8; }
.csmf-plotarea { position: relative; flex: 1; border-left: 1px solid #94a3b8; border-bottom: 1px solid #94a3b8; }
.csmf-gridline { position: absolute; left: 0; right: 0; border-top: 1px dashed #eef2f6; }
.csmf-bars { position: absolute; inset: 0; display: flex; align-items: flex-end; justify-content: space-around; padding: 0 4px; }
.csmf-group { display: flex; align-items: flex-end; gap: 2px; height: 100%; }
.csmf-bar { width: 12px; border-radius: 2px 2px 0 0; }
.csmf-bar.uncal { background: #7da7d9; }
.csmf-bar.cal { background: #a9ad6e; position: relative; }
.csmf-whisker { position: absolute; left: 50%; transform: translateX(-50%); width: 2px; background: #3f3f46; }
.csmf-whisker::before, .csmf-whisker::after { content: ''; position: absolute; left: -3px; width: 8px; height: 2px; background: #3f3f46; }
.csmf-whisker::before { top: 0; }
.csmf-whisker::after { bottom: 0; }
.csmf-xlabels { display: flex; justify-content: space-around; margin-left: 30px; margin-top: 4px; }
.csmf-xlabel { width: 28px; text-align: center; font-size: 9px; line-height: 1.1; color: #64748b; word-break: break-word; }
.csmf-legend { display: flex; gap: 20px; justify-content: center; margin-top: 12px; font-size: 13px; color: #334155; }
.csmf-dot { display: inline-block; width: 12px; height: 12px; border-radius: 3px; vertical-align: -1px; margin-right: 4px; }
.csmf-dot.uncal { background: #7da7d9; }
.csmf-dot.cal { background: #a9ad6e; }
.csmf-dot.ci { background: #3f3f46; width: 3px; height: 14px; border-radius: 0; }
```

- [ ] **Step 4: Verify the build/lint passes and the chart renders**

Run: `cd frontend && npx vitest run && npm run build`
Expected: tests PASS, production build succeeds (no unused-import/syntax errors). The legacy `CSMFChart` props (`causes`, `uncalibrated`, ...) are fully replaced by `results`.

- [ ] **Step 5: Commit**

```bash
git add frontend/src/components/JobDetail.jsx frontend/src/App.css
git commit -m "feat(results): faceted vertical CSMF figure on fixed [0,1] axis (#72)"
```

---

## Task 7: Render the consolidated table; remove per-algorithm tables

**Files:**
- Modify: `frontend/src/components/JobDetail.jsx` — replace the "CSMF Comparison" table (lines 357-389) and the per-algorithm `<details>` section (lines 391-423)
- Modify: `frontend/src/utils/export.js` — add `exportConsolidatedCSMF`
- Test: `frontend/src/components/JobDetail.test.js`

- [ ] **Step 1: Add failing source-assertion tests**

Append to `frontend/src/components/JobDetail.test.js`:

```js
describe('Consolidated CSMF table (issue #72)', () => {
  it('renders a consolidated table via buildCsmfTableRows', () => {
    expect(jobDetailSrc).toContain('buildCsmfTableRows(')
  })

  it('removes the per-algorithm <details> breakdown', () => {
    expect(jobDetailSrc).not.toContain('per-algorithm-section')
    expect(jobDetailSrc).not.toContain('Per-Algorithm Breakdown')
  })
})
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd frontend && npx vitest run src/components/JobDetail.test.js`
Expected: FAIL.

- [ ] **Step 3: Add the CSV exporter**

Append to `frontend/src/utils/export.js`:

```js
/**
 * Export the consolidated CSMF table to CSV.
 * tableData: { causes: [...], groups: [{ algorithm, rows: [{ type, cells: [{cause, mean, lower, upper}] }] }] }
 */
export function exportConsolidatedCSMF(tableData, jobId, algorithm) {
  if (!tableData || !tableData.groups) return;
  const { causes, groups } = tableData;

  let csvContent = 'Algorithm,Type,' + causes.map(c => `"${c}"`).join(',') + '\n';
  groups.forEach(group => {
    group.rows.forEach(row => {
      const cells = row.cells.map(cell => {
        if (cell.mean == null) return '';
        return cell.lower != null && cell.upper != null
          ? `"${cell.mean} (${cell.lower}, ${cell.upper})"`
          : `${cell.mean}`;
      });
      csvContent += `"${group.algorithm}","${row.type}",${cells.join(',')}\n`;
    });
  });

  const filename = generateFilename('csmf_table', algorithm, jobId, 'csv');
  exportToCSV(csvContent, filename);
}
```

- [ ] **Step 4: Replace the table sections in JobDetail**

4a. Update the export import (line 4) to include the new exporter:

```js
import { exportCSMFTable, exportConsolidatedCSMF, exportToPNG, exportToPDF, generateFilename } from '../utils/export';
```

4b. In `CalibratedResults`, build the table model near the top of the component (after the `exportData` block, around line 311):

```js
  const tableData = buildCsmfTableRows(results);
```

4c. Replace the "CSMF Comparison" section + table (lines 357-389) **and** the per-algorithm `<details>` block (lines 391-423) with a single consolidated table:

```jsx
      {/* Consolidated CSMF table: each algorithm x {Uncalibrated, Calibrated} */}
      <div className="section-header">
        <h3>CSMF Comparison</h3>
        <div className="export-buttons">
          <button onClick={() => exportConsolidatedCSMF(tableData, jobId, algorithmsDisplay)} className="export-btn" title="Export as CSV">CSV ↓</button>
          <button onClick={() => exportToPNG(csmfTableRef, generateFilename('csmf_table', algorithmsDisplay, jobId, 'png'))} className="export-btn" title="Export as PNG">PNG ↓</button>
          <button onClick={() => exportToPDF(csmfTableRef, generateFilename('csmf_table', algorithmsDisplay, jobId, 'pdf'))} className="export-btn" title="Export as PDF">PDF ↓</button>
        </div>
      </div>
      <div ref={csmfTableRef}>
        <table className="csmf-table consolidated">
          <thead>
            <tr>
              <th>Algorithm</th>
              <th>Type</th>
              {tableData.causes.map(cause => (
                <th key={cause}>{formatCauseDisplay(cause, displayNames)}</th>
              ))}
            </tr>
          </thead>
          <tbody>
            {tableData.groups.map(group => (
              group.rows.map((row, rowIdx) => (
                <tr key={`${group.algorithm}-${row.type}`} className={group.algorithm === 'Ensemble' ? 'ensemble-row' : ''}>
                  {rowIdx === 0 && <td className="algo-cell" rowSpan={group.rows.length}>{group.algorithm}</td>}
                  <td className="type-cell">{row.type}</td>
                  {row.cells.map(cell => (
                    <td key={cell.cause}>
                      {cell.mean == null ? '-' : (
                        cell.lower != null && cell.upper != null
                          ? `${cell.mean}% (${cell.lower}–${cell.upper})`
                          : `${cell.mean}%`
                      )}
                    </td>
                  ))}
                </tr>
              ))
            ))}
          </tbody>
        </table>
      </div>
```

4d. The `exportData` object and `exportCSMFTable` import are now unused in `CalibratedResults`. Remove the `exportData`/`csmf_intervals` block (lines 298-310). Keep `exportCSMFTable` in the import only if `OpenVAResults` still uses it (it does — line 243), so leave the import line as written in Step 4a.

- [ ] **Step 5: Add consolidated-table CSS**

Append to `frontend/src/App.css`:

```css
.csmf-table.consolidated th, .csmf-table.consolidated td { text-align: center; }
.csmf-table.consolidated .algo-cell { font-weight: 600; background: #f8fafc; vertical-align: middle; text-align: left; }
.csmf-table.consolidated .type-cell { text-align: left; color: #475569; }
.csmf-table.consolidated tr.ensemble-row td { background: #eef2ff; }
.csmf-table.consolidated tr.ensemble-row .algo-cell { background: #e0e7ff; }
```

- [ ] **Step 6: Run tests and build**

Run: `cd frontend && npx vitest run src/components/JobDetail.test.js && npm run build`
Expected: PASS + successful build.

- [ ] **Step 7: Commit**

```bash
git add frontend/src/components/JobDetail.jsx frontend/src/utils/export.js frontend/src/App.css
git commit -m "feat(results): single consolidated CSMF table replaces per-algorithm tables (#72)"
```

---

## Task 8: Misclassification matrices as small-multiples

**Files:**
- Modify: `frontend/src/components/MisclassificationMatrix.jsx` (lines 44-52, 90-108, 133-159)
- Modify: `frontend/src/App.css` (matrix styles near lines ~1525-1620)
- Test: `frontend/src/components/MisclassificationMatrix.test.js` already covers `matrixUtils` (unchanged); add a source-assertion test for the new layout.

Switch from tall stacked 3-decimal tables to compact side-by-side heatmaps showing integer percents, with the diagonal outlined in blue. Reuse `getCellColor`/`isDiagonalCell`; import the shared `formatAlgorithmName`.

- [ ] **Step 1: Add a failing source-assertion test**

Append to `frontend/src/components/MisclassificationMatrix.test.js`:

```js
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dirMM = dirname(fileURLToPath(import.meta.url))
const matrixSrc = readFileSync(resolve(__dirMM, 'MisclassificationMatrix.jsx'), 'utf-8')

describe('Misclassification small-multiples (issue #72)', () => {
  it('imports the shared formatAlgorithmName (no private copy)', () => {
    expect(matrixSrc).toContain("from '../utils/labels.js'")
    expect(matrixSrc).not.toContain('const algoMap = {')
  })

  it('renders integer-percent cells (round, not toFixed(3))', () => {
    expect(matrixSrc).toContain('Math.round(value * 100)')
    expect(matrixSrc).not.toContain('value.toFixed(3)')
  })

  it('lays out matrices as small-multiples', () => {
    expect(matrixSrc).toContain('matrix-small-multiples')
  })
})
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd frontend && npx vitest run src/components/MisclassificationMatrix.test.js`
Expected: FAIL.

- [ ] **Step 3: Import the shared helper and remove the private copy**

In `frontend/src/components/MisclassificationMatrix.jsx`:

3a. Add to the imports (after line 4):

```js
import { formatAlgorithmName } from '../utils/labels.js';
```

3b. Delete the private `formatAlgorithmName` function (lines 44-52, the block starting `// Format algorithm names for display` through its closing `}`).

- [ ] **Step 4: Render integer-percent cells**

In `MatrixTable`, change the cell value rendering (line 101) from:

```jsx
                      {value.toFixed(3)}
```

to:

```jsx
                      {Math.round(value * 100)}
```

And update the cell `title` (line 99) to percent:

```jsx
                      title={`P(VA=${va_causes[colIdx]} | CHAMPS=${champsCause}) = ${(value * 100).toFixed(1)}%${diag ? ' [Sensitivity]' : ''}`}
```

- [ ] **Step 5: Lay matrices out as small-multiples**

Replace the `MisclassificationMatrix` main component body (lines 141-158) with:

```jsx
  return (
    <div className="misclass-section">
      <h3>Misclassification Matrices</h3>
      <p className="matrix-description">
        P(VA cause | CHAMPS cause): how often each true (CHAMPS) cause is classified as
        each predicted (VA) cause. Rows = CHAMPS causes, columns = VA causes; the blue
        diagonal is sensitivity (correct classification).
      </p>

      <div className="matrix-small-multiples">
        {algorithms.map(algoName => (
          <div key={algoName} className="algorithm-matrix">
            <MatrixTable algoName={algoName} matrixData={matrixData[algoName]} jobId={jobId} causeDisplayNames={causeDisplayNames} causeOrder={causeOrder} />
          </div>
        ))}
      </div>
    </div>
  );
```

(The `<h3>{formatAlgorithmName(algoName)}</h3>` previously between the wrapper and `MatrixTable` is dropped — `MatrixTable`'s own `<h4>{algoDisplay} - Misclassification Matrix</h4>` already names each algorithm.)

- [ ] **Step 6: Update matrix CSS for small-multiples + blue diagonal**

In `frontend/src/App.css`, append (and ensure the diagonal rule wins):

```css
.matrix-small-multiples { display: flex; flex-wrap: wrap; gap: 16px; overflow-x: auto; }
.matrix-small-multiples .algorithm-matrix { flex: 0 1 auto; }
.matrix-small-multiples .misclass-table td,
.matrix-small-multiples .misclass-table th { padding: 3px 5px; font-size: 11px; }
.misclass-table .diagonal-cell { outline: 2px solid #2563eb; outline-offset: -2px; font-weight: 700; }
```

- [ ] **Step 7: Run tests and build**

Run: `cd frontend && npx vitest run src/components/MisclassificationMatrix.test.js && npm run build`
Expected: PASS (matrixUtils tests + new source tests) + successful build.

- [ ] **Step 8: Commit**

```bash
git add frontend/src/components/MisclassificationMatrix.jsx frontend/src/components/MisclassificationMatrix.test.js frontend/src/App.css
git commit -m "feat(results): misclassification matrices as small-multiples heatmaps (#72)"
```

---

## Task 9: Remove the bulk download list and the PDF section

**Files:**
- Modify: `frontend/src/components/JobDetail.jsx` — `CalibratedResults` (Calibration Plot section lines 425-438; Download Files section lines 440-447) and `OpenVAResults` (Download Files section lines 270-282)
- Test: `frontend/src/components/JobDetail.test.js`

Per-figure/per-table export buttons already cover downloads, so the bulk list and the broken-PDF block are redundant.

- [ ] **Step 1: Add failing source-assertion tests**

Append to `frontend/src/components/JobDetail.test.js`:

```js
describe('Redundant downloads removed (issue #72)', () => {
  it('removes the bulk "Download Files" section', () => {
    expect(jobDetailSrc).not.toContain('Download Files')
  })

  it('removes the calibration_plot.pdf section', () => {
    expect(jobDetailSrc).not.toContain('calibration_plot.pdf')
    expect(jobDetailSrc).not.toContain('calibration-plot-section')
  })
})
```

- [ ] **Step 2: Run and confirm failure**

Run: `cd frontend && npx vitest run src/components/JobDetail.test.js`
Expected: FAIL.

- [ ] **Step 3: Remove the sections from `CalibratedResults`**

Delete the entire "Calibration Plot" block (lines 425-438, `{results.files?.plot && (...)}`) and the "Download Files" block (lines 440-447, `<h3>Download Files</h3> ... </div>`).

- [ ] **Step 4: Remove the Download Files section from `OpenVAResults`**

Delete the "Download Files" block in `OpenVAResults` (lines 270-282, `<h3>Download Files</h3> ... </div>`).

- [ ] **Step 5: Clean up now-unused imports**

`getDownloadUrl` was only used by the deleted download/plot links. Confirm and remove it from the import on line 2:

Run: `grep -n "getDownloadUrl" frontend/src/components/JobDetail.jsx`
If the only remaining hit is the import line, change line 2 to drop `getDownloadUrl`:

```js
import { getJobStatus, getJobLog, getJobResults } from '../api/client';
```

- [ ] **Step 6: Run tests and build**

Run: `cd frontend && npx vitest run src/components/JobDetail.test.js && npm run build`
Expected: PASS + successful build (no unused-import errors).

- [ ] **Step 7: Commit**

```bash
git add frontend/src/components/JobDetail.jsx frontend/src/components/JobDetail.test.js
git commit -m "feat(results): remove redundant bulk downloads and broken PDF section (#72)"
```

---

## Task 10: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the entire frontend test suite**

Run: `cd frontend && npm test`
Expected: all suites PASS. Note the new totals (labels.test.js added; CSMFChart.test.js rewritten; JobDetail/MisclassificationMatrix tests expanded).

- [ ] **Step 2: Production build**

Run: `cd frontend && npm run build`
Expected: build succeeds with no errors.

- [ ] **Step 3: Backend fast regression**

Ensure backend deps available, then:
Run: `cd backend && Rscript ../tests/test_vacalibration_backend.R --input-only`
Expected: completes without error.

- [ ] **Step 4: Manual smoke test (browser)**

Start backend if not running (`lsof -ti:8000` → if empty, `cd backend && Rscript run.R &`), start frontend (`cd frontend && npm run dev`), run an ensemble calibration (sample data, neonate, Mozambique, EAVA+InSilicoVA+InterVA) and confirm on the Results tab:
- Summary shows `EAVA, InSilicoVA, InterVA` and `Neonate (0-27 days)`, no "Records processed".
- CSMF figure shows 4 facets (3 algos + Ensemble), 0–1 axis with labels, visible dark CI whiskers.
- Misclassification matrices render side-by-side with integer % and blue diagonals.
- One consolidated table with Uncalibrated/Calibrated rows per algorithm + ensemble.
- No "Download Files" list, no "Calibration Plot" PDF link.
- Status tab during a run shows a non-negative elapsed time.

- [ ] **Step 5: Update MEMORY.md test inventory**

Update the testing counts in `/Users/ericliu/.claude/projects/-Users-ericliu-projects5-comsa-dashboard/memory/MEMORY.md` to reflect `labels.test.js` (new) and the revised assertion counts for CSMFChart/JobDetail/MisclassificationMatrix.

- [ ] **Step 6: Final commit (if any uncommitted verification fixes)**

```bash
git add -A
git commit -m "test(results): verify issue #72 output presentation changes"
```

---

## Self-Review Notes

- **Spec coverage:** Item 1 → Task 1; Item 2 → Tasks 2-3; Item 3 (CSMF figure) → Tasks 5-6; Item 4 (matrices) → Task 8; Item 5 (consolidated table) → Tasks 5,7; broken PDF → Tasks 4,9; redundant downloads → Task 9. AI report explicitly out of scope.
- **Known deviation from mockup:** the consolidated table's Uncalibrated rows show point estimates only (no CI) because the backend returns no uncalibrated interval; only Calibrated rows show `mean% (low–high)`.
- **Type consistency:** builder shapes (`{label, causes:[{cause,uncalibrated,calibrated,ciLower,ciUpper}]}` and `{causes, groups:[{algorithm, rows:[{type, cells:[{cause,mean,lower,upper}]}]}]}`) are defined in Task 5 and consumed identically in Tasks 6-7. `exportConsolidatedCSMF` (Task 7) consumes the same table shape.
- **Test independence:** each task writes its test first, runs it red, implements, runs it green, commits.
