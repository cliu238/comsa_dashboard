# Issue #72 — Output Presentation Redesign

**Date:** 2026-06-02
**Issue:** [#72 — output presentation](https://github.com/cliu238/comsa_dashboard/issues/72)
**Status:** Design approved, ready for implementation plan

## Summary

Redesign the calibration job **results/output presentation** to match the figure and
table conventions from the team's BMJGH paper
([gh.bmj.com/content/11/3/e021747](https://gh.bmj.com/content/11/3/e021747)), fix a
broken elapsed-time display and a broken PDF download, and clean up redundant UI.

The work is overwhelmingly a **frontend presentation** change. The backend already
returns all the data the new figures need (`per_algorithm` includes every algorithm
*and* the ensemble row; `misclassification_matrix` is keyed per algorithm). The only
backend change is **removing** the broken server-side `pdf()` plot generation.

## Scope

In scope (issue items 1–5 + redundant-download cleanup):

1. Fix the negative elapsed-time (`-14396s`) on the Status tab.
2. Clean up the results summary block wording / input echo.
3. Redesign the CSMF figure (vertical small-multiples, faithful to BMJGH).
4. Plot misclassification matrices as small-multiples (replace stacked tables).
5. Replace per-algorithm tables with one consolidated CSMF table.
6. Remove the redundant bulk "Download Files" list and the broken
   `calibration_plot.pdf` section.

Out of scope (deferred to a **separate future issue**):

- The AI/LLM-generated narrative report (figures + interpretations + citations).
  This is the last bullet of the issue. It is a distinct feature (prompt design,
  API keys, cost handling) and gets its own spec → plan → implementation cycle.

## Guiding architecture decision

Figures render **in-app** (React + HTML/CSS) and are exported to PNG/PDF via the
existing `exportToPNG` / `exportToPDF` (html2canvas) helpers. The server-side R
`pdf()` plot is **removed entirely**. Rationale: a single source of truth that
cannot drift from what is on screen and cannot independently corrupt (the broken
`calibration_plot.pdf` was produced by wrapping `vacalibration()` in a `pdf()`
device that did not reliably draw to it).

## Detailed design

### 1. Status tab — fix `-14396s` elapsed time

**Root cause:** `getElapsedTime()` in `frontend/src/utils/progress.js` parses the R
timestamp string `"2026-05-30 13:48:14.922977"` (which is UTC, no timezone suffix)
with `new Date(string)`, which JavaScript interprets as **local time**. For a user in
UTC−4 this yields a start time ~4h in the future relative to `now`, producing the
negative `-14396s` (~−4h).

**Fix:** In the string branch of `getElapsedTime()`, normalize the timestamp to UTC
before constructing the `Date` (convert `"YYYY-MM-DD HH:MM:SS[.ffffff]"` to an ISO
UTC instant, e.g. replace the space with `T` and append `Z`). Clamp the computed
elapsed seconds to `>= 0` defensively. The array branch (epoch seconds) is already
correct and is unchanged. The counter remains visible — only the math is corrected.

### 2. Results summary block

Applies to `CalibratedResults` (and the wording-relevant parts of `OpenVAResults`)
in `frontend/src/components/JobDetail.jsx`.

- **Remove** the `Records processed:` line.
- **Algorithm(s):** display proper names, comma-separated — e.g.
  `EAVA, InSilicoVA, InterVA`. Reuse the existing `formatAlgorithmName` map
  (currently in `MisclassificationMatrix.jsx`; promote to a shared util so both the
  summary and the figures use it). Replace the current `" + "` join with `", "`.
- **Age group:** friendly label via a fixed map —
  `neonate` → `Neonate (0-27 days)`, `child` → `Children (1-59 months)`.
- **Country:** unchanged; keeps the existing `other` → `All the countries` mapping.

### 3. CSMF figure — vertical small-multiples (Option A, approved)

Rewrite the `CSMFChart` component (in `JobDetail.jsx`; chart-data helper in
`CSMFChart.js`) as **faceted vertical grouped bars**:

- One facet per algorithm, plus an **Ensemble** facet (ensemble jobs).
  Single-algorithm jobs render a single facet.
- Within each facet: causes on the x-axis; **CSMF on the y-axis fixed to the full
  `[0, 1.00]` range** with tick labels (0, .25, .50, .75, 1.0) and horizontal
  gridlines (addresses "CSMF-axis labels absent" and "use the full [0,1] range").
- Per cause: two grouped bars — **Uncalibrated** (light blue) and **Calibrated**
  (olive) — with a **dark CI whisker** drawn on top of the calibrated bar
  (addresses "CI colors identical to bar colors → lower CIs not visible"; uses
  lighter bars + darker CI as the user preferred).
- Legend: Uncalibrated / Calibrated / 95% CI.
- **Data source:** `per_algorithm` (which already includes the `ensemble` row). For
  single-algorithm jobs where `per_algorithm` is absent, fall back to the primary
  `uncalibrated_csmf` / `calibrated_csmf` / `calibrated_ci_*` fields.
- Facets wrap and/or scroll horizontally so child data (9 causes × up to 4 facets)
  stays legible.
- The whole figure is wrapped in a single `ref` and exportable as one PNG/PDF.

### 4. Misclassification matrices — small-multiples (approved)

Restyle `frontend/src/components/MisclassificationMatrix.jsx` from tall, vertically
stacked per-algorithm tables into **compact side-by-side heatmaps**:

- One heatmap per algorithm, displayed as small-multiples.
- Cells show **integer percentages** (not 3-decimal probabilities), on a red
  intensity color scale.
- The **diagonal (sensitivity) cells are outlined in blue**.
- Axis titles: rows labeled "CHAMPS Cause" (true), columns "VA Cause" (predicted).
- Horizontally scrollable for child data (9×9).
- Per-matrix CSV / PNG export retained (reuse existing export buttons).
- Cause ordering continues to honor `cause_order` / `cause_display_names`
  (issue #29 behavior preserved).
- No ensemble matrix (the package's `Mmat` has no ensemble row — matches BMJGH,
  which shows one matrix per algorithm only).

### 5. One consolidated CSMF table (approved)

Replace **both** the main "CSMF Comparison" table and the per-algorithm collapsible
`<details>` tables in `CalibratedResults` with a **single consolidated table**:

- Columns: `Algorithm`, `Type`, then one column per cause.
- Rows: for each algorithm — plus the ensemble — two rows, `Uncalibrated` and
  `Calibrated`.
- Cells: `mean % (low, high)` (point estimate with CI), percentages as integers
  consistent with the BMJGH S4 table.
- Ensemble row-group visually highlighted.
- **Data source:** `per_algorithm` when present (includes ensemble); otherwise build
  a single algorithm's two rows from the primary fields (single-algo fallback).
- Cause labels honor `cause_display_names`.
- Exports to CSV / PNG / PDF (reuse existing export buttons; the CSV exporter is
  extended to emit the consolidated long/wide shape).

### 6. Remove redundant downloads and the broken PDF

- **Frontend:** delete the bottom bulk "Download Files" list and the
  "Calibration Plot" PDF block from `CalibratedResults` (and the equivalent bulk
  list in `OpenVAResults`). Downloads happen through the per-figure / per-table
  export buttons that already sit next to each artifact.
- **Backend (`backend/jobs/algorithms/vacalibration.R`):** remove the
  `pdf(plot_file, ...)` / `dev.off()` wrapping, the `calibration_plot.pdf`
  file write, the `add_job_file(... "calibration_plot.pdf" ...)` call, and the
  `plot = "calibration_plot.pdf"` entry in the returned `files` list. The
  `vacalibration()` call is preserved (just no longer wrapped in a PDF device).
  `calibration_summary.csv` and the misclassification-matrix CSVs are unchanged.

## Data flow (unchanged backend contract, minus the plot)

`vacalibration.R` returns (already today, except `files$plot` is dropped):

- `algorithm`, `age_group`, `country`, `ensemble`
- `uncalibrated_csmf`, `calibrated_csmf`, `calibrated_ci_lower`, `calibrated_ci_upper`
  (primary = ensemble row when ensemble, else the single algorithm)
- `per_algorithm[label] = { uncalibrated_csmf, calibrated_csmf, calibrated_ci_lower,
  calibrated_ci_upper }` for each label including `ensemble`
- `misclassification_matrix[algo] = { matrix, champs_causes, va_causes }`
- `cause_display_names`, `cause_order` (when user upload)
- `files = { summary: "calibration_summary.csv", misclass_*: ... }` (no `plot`)

## Error handling / edge cases

- **Single-algorithm jobs:** no `per_algorithm` → chart renders one facet and the
  consolidated table has one algorithm's two rows, built from primary fields.
- **openVA-only results** (`csmf` but no `calibrated_csmf`): `OpenVAResults` keeps
  its single CSMF table; only summary wording and bulk-download cleanup apply.
- **Missing CI values:** whiskers omitted for that bar; table shows the mean only.
- **Elapsed time:** clamp to `>= 0`; return `null` when `started_at` is absent.

## Testing

Per CLAUDE.md, write a test for each edge case **before** implementing it.

Frontend (vitest):

- `progress.test.js`: regression — a UTC timestamp string yields a **non-negative**
  elapsed time (guards the `-14396s` bug); array (epoch) branch still correct;
  absent `started_at` → `null`.
- `JobDetail.test.js`: summary block has **no** "Records processed"; algorithms shown
  comma-separated and proper-cased; age group shows the friendly label.
- New: CSMF faceted chart data builder — produces a facet per algorithm + ensemble;
  single-algo fallback produces exactly one facet; y-axis fixed to [0,1].
- New: consolidated-table row builder — `per_algorithm` path includes ensemble rows;
  single-algo fallback produces two rows; cells format as `mean (low, high)`.
- Matrix small-multiples: integer-% formatting, diagonal flagged, `cause_order`
  honored.

Backend (R, `tests/test_vacalibration_backend.R`):

- `calibration_plot.pdf` is **not** produced and **not** present in `files`.
- `per_algorithm` (incl. `ensemble`) and `misclassification_matrix` still returned
  with the expected shapes.

## Files touched

- `frontend/src/components/JobDetail.jsx` — summary block, chart, consolidated table,
  remove bulk downloads + PDF section
- `frontend/src/components/CSMFChart.js` — faceted vertical chart data/render
- `frontend/src/components/MisclassificationMatrix.jsx` — small-multiples restyle
- `frontend/src/utils/progress.js` — UTC elapsed-time fix
- shared util for `formatAlgorithmName` / age-group label (promoted from the matrix
  component, e.g. into `causeDisplay.js` or a small `labels.js`)
- `frontend/src/utils/export.js` — consolidated-table CSV shape (if needed)
- related CSS (`App.css` or component styles) for facets, heatmap, table
- `backend/jobs/algorithms/vacalibration.R` — remove `pdf()` plot generation
- corresponding test files
