# Issue #68 — Form Copy, Ordering & Branding

**Date:** 2026-05-26
**Issue:** [#68 — general suggestions](https://github.com/cliu238/comsa_dashboard/issues/68)
**Related:** #69 (Resource/Acknowledgment tabs + credit line, already merged) — the credit line rendered by `PageHeader` stays beneath the new title.

## Goal

Apply the copy, input-ordering, control, and branding changes requested in issue
#68 to the job-submission form and the page title. These are surgical UI/copy
edits — no change to form behavior, state, effects, or the backend payload.

## Decisions (from clarifying questions)

| Topic | Decision |
|---|---|
| Country list | The 7 vacalibration-supported countries + "Other", alphabetical. NOT all ~195 (the package only has data for these; listing all would imply unsupported calibration). Selected default stays `Mozambique` (COMSA demo data). |
| "VA-Calibration" scope | Replace visible "VA Calibration" → "VA-Calibration". Leave the R package identifier `vacalibration` (lowercase) untouched everywhere. |
| Page title | Long phrase becomes the Calibrate page heading; subtitle removed. Sidebar nav item and submit button stay "Calibrate" (short action labels). |
| CCVA algorithm label | Relabel the algorithm field to include "Computer-Coded Verbal Autopsy (CCVA)" — matches the issue's consistent CCVA usage (confirmed with user). |
| Uncertainty control | Reuse existing `calibModelType` state (checked → `'Mmatprior'`, unchecked → `'Mmatfixed'`). No new state, identical payload. |

## Architecture

In-place edits to three files. No new components, no refactor (the form's
coupled algorithm/ensemble/upload effects are left untouched).

| File | Change |
|---|---|
| `frontend/src/components/JobForm.jsx` | Reorder form blocks; swap uncertainty dropdown → checkbox; update labels/hints/country list/age label; add CCVA hyperlink. |
| `frontend/src/App.jsx` | Calibrate-route `PageHeader` title (remove subtitle); sidebar brand → "VA-Calibration". |
| `frontend/index.html` | `<title>` → "VA-Calibration Platform". |
| `frontend/src/App.css`, `frontend/src/index.css` | Update the "VA Calibration Platform" header comments → "VA-Calibration Platform" (cosmetic consistency). |

## Detailed changes

### 1. Page title — `App.jsx` (~line 187)
Before:
```jsx
<PageHeader title="Calibrate" subtitle="Submit and monitor verbal autopsy calibration jobs" />
```
After:
```jsx
<PageHeader title="Correcting for Algorithmic Misclassification in Estimating Cause Distributions" />
```
`PageHeader` already renders the credit line (issue #69) and treats `subtitle` as
optional, so omitting it is safe.

### 2. "VA-Calibration" branding
- `App.jsx` (~line 116): `<span className="brand-name">VA Calibration</span>` → `VA-Calibration`.
- `index.html` (line 7): `<title>VA Calibration Platform</title>` → `<title>VA-Calibration Platform</title>`.
- `App.css` line 2 / `index.css` line 2 header comments: "VA Calibration Platform" → "VA-Calibration Platform".
- **Left as-is (out of scope):** the spelled-out prose "Verbal Autopsy Calibration Platform" in `LandingPage.jsx:12` and `VideosSection.jsx:27` — these are descriptive expansions, not the "VA Calibration" brand token. The `vacalibration` package name is untouched.

### 3. Input order — `JobForm.jsx`
Reorder the form `<div className="form-group">` blocks to this sequence (conditionals preserved):
1. Job Type
2. Country *(hidden for openVA — unchanged condition)*
3. Age Group
4. CCVA Algorithm(s) *(the existing per-jobType algorithm UI block)*
5. Propagate uncertainty *(calibration jobs only — unchanged condition)*
6. Upload VA Data
7. MCMC Specifics *(calibration jobs only — moves from before-upload to last)*

Then the existing demo-info, error, progress, and form-actions blocks follow, unchanged.

### 4. CCVA algorithm label — `JobForm.jsx`
The three algorithm-section labels ("Algorithm", "Algorithm(s)", "Algorithms *")
become "Computer-Coded Verbal Autopsy (CCVA) Algorithm(s)" (keep the existing
`*`/required and singular/plural affordances where present). The algorithm option
labels and values are unchanged.

### 5. Age group — `JobForm.jsx` (~line 377)
`{ value: 'child', label: 'Child (1-59 months)' }` → `label: 'Children (1-59 months)'`. Value `child` unchanged.

### 6. Country dropdown — `JobForm.jsx` (~lines 389-398)
Options, in order:
```jsx
{ value: 'Bangladesh', label: 'Bangladesh' },
{ value: 'Ethiopia', label: 'Ethiopia' },
{ value: 'Kenya', label: 'Kenya' },
{ value: 'Mali', label: 'Mali' },
{ value: 'Mozambique', label: 'Mozambique' },
{ value: 'Sierra Leone', label: 'Sierra Leone' },
{ value: 'South Africa', label: 'South Africa' },
{ value: 'other', label: 'Other' },
```
The `country` state default stays `'Mozambique'` (value `other` keeps the same
backend meaning; only its label changes from "All the countries" to "Other").

### 7. Uncertainty control — `JobForm.jsx` (~lines 404-419)
Replace the `CustomSelect` with a checkbox (calibration jobs only — same condition):
- Checkbox `checked={calibModelType === 'Mmatprior'}`; `onChange` sets `calibModelType` to `'Mmatprior'` when checked, `'Mmatfixed'` when unchecked. Default stays `'Mmatprior'` (checked).
- Label text: **"Propagate uncertainty in CCVA misclassification"**.
- Hint: **"Controls whether to propagate uncertainty in CCVA misclassification estimate"**, where "CCVA misclassification estimate" is an `<a href="https://github.com/sandy-pramanik/CCVA-Misclassification-Matrices" target="_blank" rel="noopener noreferrer">`.

### 8. MCMC section — `JobForm.jsx` (~lines 429, 465-467)
- Toggle button text: "Advanced MCMC Settings" → **"MCMC Specifics"** (keep the ▸/▾ caret).
- Replace the hint with three lines (each on its own line, e.g. separated by `<br />` or separate elements):
  - "Higher iteration improves accuracy but requires more time."
  - "Burn-in discards early samples to warm up MCMC chain."
  - "Thinning reduces dependency between subsequent MCMC samples."

## Error handling / edge cases
- The uncertainty checkbox derives its checked state from `calibModelType`; no new state means no desync risk. The submitted payload (`calibModelType`) is byte-for-byte what the backend already expects.
- Country `other` retains its existing value/semantics; only the label changes, so existing jobs/demo are unaffected.
- Reordering is pure JSX movement; the `useEffect`s and handlers key off state, not DOM order, so behavior is unchanged.

## Testing
- **Source-level vitest** (matches `JobForm.test.js` / `JobDetail.test.js` pattern — reads `.jsx`/`.html` as text):
  - `App.jsx` contains the new title string and no longer the old "Calibrate"/"Submit and monitor" PageHeader title; sidebar brand is "VA-Calibration".
  - `index.html` title is "VA-Calibration Platform".
  - `JobForm.jsx` contains: "Children (1-59 months)"; the alphabetical country order with label "Other"; "Computer-Coded Verbal Autopsy (CCVA)"; "Propagate uncertainty in CCVA misclassification"; the CCVA-Misclassification-Matrices href; "MCMC Specifics"; the three MCMC hint sentences; and no longer the old strings ("Advanced MCMC Settings", old uncertainty label/hint, "All the countries").
- **jsdom behavior** (`@vitest-environment jsdom`): render `JobForm`, in Calibration-Only mode toggle the "Propagate uncertainty…" checkbox and assert it starts checked (default) and unchecking it is reflected; assert it's an `<input type="checkbox">` not a select.
- **Manual:** run the dev server, eyeball the reordered form, the new title + retained credit line, the checkbox, the CCVA link (opens the repo), and the alphabetical country list.

## Out of scope
- No backend changes. No form-logic/effects changes. No component extraction/refactor.
- Spelled-out "Verbal Autopsy Calibration Platform" prose (landing hero, video caption) — left as descriptive text unless the user later wants it rebranded.
