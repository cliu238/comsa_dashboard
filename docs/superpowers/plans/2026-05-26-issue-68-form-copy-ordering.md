# Issue #68 — Form Copy, Ordering & Branding Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply issue #68's copy, input-ordering, control, and branding changes to the job form and page title — without changing form behavior, effects, or the backend payload.

**Architecture:** Surgical in-place edits to `JobForm.jsx`, `App.jsx`, `index.html`, and two CSS header comments. The uncertainty dropdown becomes a checkbox that reuses the existing `calibModelType` state (checked → `'Mmatprior'`, unchecked → `'Mmatfixed'`), so the submitted payload is identical. No component extraction, no logic changes.

**Tech Stack:** React 18, Vite, Vitest (`environment: 'node'`; jsdom opt-in per-file via `@vitest-environment jsdom` docblock), @testing-library/react.

---

## Conventions (match the existing repo)

- **Source-level tests** (`*.test.js`, node env): `readFileSync` the `.jsx`/`.html` and assert `toContain` / `not.toContain`. See `src/components/JobForm.test.js`.
- **Render tests** (`*.test.jsx` with `/** @vitest-environment jsdom */` as the FIRST lines): `render` + `screen` from `@testing-library/react`. Mock `../api/client` (see `src/components/JobForm.behavior.test.jsx`). No `@testing-library/jest-dom` — use `getByLabelText`/`getByText` (throw on absence), `.checked`, `expect(...).toBeTruthy()`.
- Run tests from `frontend/`: `cd frontend && npx vitest run <path>`.
- Outbound links use `target="_blank" rel="noopener noreferrer"`.

## File Structure

| File | Responsibility | Action |
|---|---|---|
| `frontend/src/App.jsx` | Calibrate-route title (remove subtitle); sidebar brand → "VA-Calibration" | Modify |
| `frontend/index.html` | `<title>` → "VA-Calibration Platform" | Modify |
| `frontend/src/App.css`, `frontend/src/index.css` | header comment branding (cosmetic) | Modify |
| `frontend/src/branding.test.js` | source test for title + branding | Create |
| `frontend/src/components/JobForm.jsx` | copy/options, uncertainty checkbox, reorder | Modify |
| `frontend/src/components/JobForm.test.js` | update obsolete issue-#25 assertions | Modify |
| `frontend/src/components/JobForm.issue68.test.js` | source tests for #68 form copy + checkbox | Create |
| `frontend/src/components/JobForm.issue68.behavior.test.jsx` | jsdom: checkbox toggle + field order | Create |

---

## Task 1: App-level text — title, subtitle removal, VA-Calibration branding

**Files:**
- Modify: `frontend/src/App.jsx` (PageHeader for `/`; sidebar `brand-name` span)
- Modify: `frontend/index.html` (`<title>`)
- Modify: `frontend/src/App.css` line 2, `frontend/src/index.css` line 2 (header comments)
- Test: `frontend/src/branding.test.js`

- [ ] **Step 1: Write the failing test**

Create `frontend/src/branding.test.js`:
```js
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const appSrc = readFileSync(resolve(__dir, 'App.jsx'), 'utf-8')
const htmlSrc = readFileSync(resolve(__dir, '../index.html'), 'utf-8')

describe('Page title (issue #68)', () => {
  it('Calibrate page heading is the long misclassification title', () => {
    expect(appSrc).toContain('Correcting for Algorithmic Misclassification in Estimating Cause Distributions')
  })
  it('drops the old "Submit and monitor" subtitle', () => {
    expect(appSrc).not.toContain('Submit and monitor verbal autopsy calibration jobs')
  })
})

describe('VA-Calibration branding (issue #68)', () => {
  it('sidebar brand and tab title use the hyphenated "VA-Calibration"', () => {
    expect(appSrc).toContain('VA-Calibration')
    expect(htmlSrc).toContain('VA-Calibration Platform')
  })
  it('no unhyphenated "VA Calibration" remains in App.jsx or index.html', () => {
    expect(appSrc).not.toContain('VA Calibration')
    expect(htmlSrc).not.toContain('VA Calibration')
  })
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx vitest run src/branding.test.js`
Expected: FAIL — old title/subtitle and unhyphenated "VA Calibration" still present.

- [ ] **Step 3: Update the Calibrate page title in App.jsx**

In `frontend/src/App.jsx`, the `/` route's PageHeader currently reads:
```jsx
<PageHeader title="Calibrate" subtitle="Submit and monitor verbal autopsy calibration jobs" />
```
Replace with:
```jsx
<PageHeader title="Correcting for Algorithmic Misclassification in Estimating Cause Distributions" />
```

- [ ] **Step 4: Update the sidebar brand in App.jsx**

In the sidebar brand block, change:
```jsx
          <span className="brand-name">VA Calibration</span>
```
to:
```jsx
          <span className="brand-name">VA-Calibration</span>
```

- [ ] **Step 5: Update index.html title**

In `frontend/index.html` (line 7), change:
```html
    <title>VA Calibration Platform</title>
```
to:
```html
    <title>VA-Calibration Platform</title>
```

- [ ] **Step 6: Update the two CSS header comments**

In `frontend/src/App.css` line 2 (`   VA Calibration Platform - Modern Data Platform`) and `frontend/src/index.css` line 2 (`   VA Calibration Platform - Design System`), change "VA Calibration Platform" → "VA-Calibration Platform".

- [ ] **Step 7: Run the test to verify it passes**

Run: `cd frontend && npx vitest run src/branding.test.js`
Expected: PASS (4 tests).

- [ ] **Step 8: Run the existing App/JobForm tests to confirm no regression**

Run: `cd frontend && npx vitest run src/components/JobForm.test.js src/App.routes.test.js`
Expected: PASS (the nav label "Calibrate" and routes are unchanged).

- [ ] **Step 9: Commit**

```bash
git add frontend/src/App.jsx frontend/index.html frontend/src/App.css frontend/src/index.css frontend/src/branding.test.js
git commit -m "feat(ui): new Calibrate page title + VA-Calibration branding (#68)"
```

---

## Task 2: JobForm copy & options (age, country, CCVA labels, MCMC)

**Files:**
- Modify: `frontend/src/components/JobForm.jsx`
- Test: `frontend/src/components/JobForm.issue68.test.js`

- [ ] **Step 1: Write the failing test**

Create `frontend/src/components/JobForm.issue68.test.js`:
```js
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const src = readFileSync(resolve(__dir, 'JobForm.jsx'), 'utf-8')

describe('Age group label (issue #68)', () => {
  it('uses "Children (1-59 months)"', () => {
    expect(src).toContain('Children (1-59 months)')
    expect(src).not.toContain("label: 'Child (1-59 months)'")
  })
})

describe('Country dropdown (issue #68)', () => {
  it('lists the supported countries alphabetically with an "Other" option', () => {
    expect(src).toContain("{ value: 'other', label: 'Other' }")
    expect(src).not.toContain('All the countries')
    const order = ['Bangladesh', 'Ethiopia', 'Kenya', 'Mali', 'Mozambique', 'Sierra Leone', 'South Africa']
      .map((c) => src.indexOf(`value: '${c}', label: '${c}'`))
    order.forEach((p) => expect(p).toBeGreaterThan(-1))
    for (let i = 1; i < order.length; i++) expect(order[i]).toBeGreaterThan(order[i - 1])
  })
})

describe('CCVA algorithm label (issue #68)', () => {
  it('labels the algorithm field with the CCVA full name', () => {
    expect(src).toContain('Computer-Coded Verbal Autopsy (CCVA) Algorithm')
  })
})

describe('MCMC section (issue #68)', () => {
  it('renames the toggle to "MCMC Specifics"', () => {
    expect(src).toContain('MCMC Specifics')
    expect(src).not.toContain('Advanced MCMC Settings')
  })
  it('uses the new three-sentence MCMC hint', () => {
    expect(src).toContain('Higher iteration improves accuracy but requires more time.')
    expect(src).toContain('Burn-in discards early samples to warm up MCMC chain.')
    expect(src).toContain('Thinning reduces dependency between subsequent MCMC samples.')
  })
})
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx vitest run src/components/JobForm.issue68.test.js`
Expected: FAIL (old strings still present).

- [ ] **Step 3: Update the age group label**

In `frontend/src/components/JobForm.jsx`, the Age Group `CustomSelect` options:
```jsx
              { value: 'child', label: 'Child (1-59 months)' }
```
→
```jsx
              { value: 'child', label: 'Children (1-59 months)' }
```

- [ ] **Step 4: Replace the Country options (alphabetical + "Other")**

Replace the Country `CustomSelect` `options` array with:
```jsx
              options={[
                { value: 'Bangladesh', label: 'Bangladesh' },
                { value: 'Ethiopia', label: 'Ethiopia' },
                { value: 'Kenya', label: 'Kenya' },
                { value: 'Mali', label: 'Mali' },
                { value: 'Mozambique', label: 'Mozambique' },
                { value: 'Sierra Leone', label: 'Sierra Leone' },
                { value: 'South Africa', label: 'South Africa' },
                { value: 'other', label: 'Other' }
              ]}
```
(The `country` state default stays `'Mozambique'` — do not change `useState('Mozambique')`.)

- [ ] **Step 5: Relabel the three algorithm-field labels with the CCVA name**

There are three algorithm `<label>`s (one per job type). Update each field label (NOT the per-algorithm option labels like "InterVA (fastest...)"):
- openVA branch: `<label>Algorithm</label>` → `<label>Computer-Coded Verbal Autopsy (CCVA) Algorithm</label>`
- pipeline branch: `<label>Algorithm{ensemble ? 's' : ''}` → `<label>Computer-Coded Verbal Autopsy (CCVA) Algorithm{ensemble ? 's' : ''}` (keep the rest of that label, including the `{ensemble && (<span ...>)}` part, unchanged)
- vacalibration branch: `<label>Algorithms *</label>` → `<label>Computer-Coded Verbal Autopsy (CCVA) Algorithms *</label>`

- [ ] **Step 6: Rename the MCMC toggle and replace its hint**

Change the toggle button text:
```jsx
              {showAdvanced ? '▾' : '▸'} Advanced MCMC Settings
```
→
```jsx
              {showAdvanced ? '▾' : '▸'} MCMC Specifics
```
Replace the MCMC hint `<small>`:
```jsx
                <small className="form-hint">
                  Higher iterations = more accuracy but longer runtime. Burn-in discards early samples. Thinning reduces autocorrelation.
                </small>
```
→
```jsx
                <small className="form-hint">
                  Higher iteration improves accuracy but requires more time.<br />
                  Burn-in discards early samples to warm up MCMC chain.<br />
                  Thinning reduces dependency between subsequent MCMC samples.
                </small>
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `cd frontend && npx vitest run src/components/JobForm.issue68.test.js`
Expected: PASS (5 tests).

- [ ] **Step 8: Run the existing JobForm tests (no regression yet expected here)**

Run: `cd frontend && npx vitest run src/components/JobForm.test.js src/components/JobForm.behavior.test.jsx`
Expected: PASS. (The issue-#25 dropdown assertions are still valid until Task 3.)

- [ ] **Step 9: Commit**

```bash
git add frontend/src/components/JobForm.jsx frontend/src/components/JobForm.issue68.test.js
git commit -m "feat(form): age/country/CCVA-label/MCMC copy updates (#68)"
```

---

## Task 3: Uncertainty control — dropdown → checkbox

**Files:**
- Modify: `frontend/src/components/JobForm.jsx` (uncertainty `form-group`)
- Modify: `frontend/src/components/JobForm.test.js` (replace obsolete issue-#25 dropdown assertions)
- Test (source): append to `frontend/src/components/JobForm.issue68.test.js`
- Test (jsdom): create `frontend/src/components/JobForm.issue68.behavior.test.jsx`

- [ ] **Step 1: Write the failing source assertions**

Append to `frontend/src/components/JobForm.issue68.test.js`:
```js
describe('Uncertainty checkbox (issue #68)', () => {
  it('uses a checkbox bound to calibModelType, not a Yes/No dropdown', () => {
    expect(src).toContain("checked={calibModelType === 'Mmatprior'}")
    expect(src).toContain("e.target.checked ? 'Mmatprior' : 'Mmatfixed'")
    expect(src).not.toContain("'Yes (Informative Prior)'")
    expect(src).not.toContain("'No (Fixed misclassification matrix)'")
  })
  it('uses the new label and hint with the CCVA matrices link', () => {
    expect(src).toContain('Propagate uncertainty in CCVA misclassification')
    expect(src).toContain('Controls whether to propagate uncertainty in')
    expect(src).toContain('https://github.com/sandy-pramanik/CCVA-Misclassification-Matrices')
    expect(src).not.toContain('Controls how uncertainty in misclassification estimates is handled')
    expect(src).not.toContain('Propagate uncertainty in misclassification matrix')
  })
})
```

- [ ] **Step 2: Write the failing jsdom behavior test**

Create `frontend/src/components/JobForm.issue68.behavior.test.jsx`:
```jsx
/**
 * @vitest-environment jsdom
 */
import { describe, it, expect, vi } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import JobForm from './JobForm'

vi.mock('../api/client', () => ({
  submitJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
  submitDemoJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
  getJobStatus: vi.fn(() => Promise.resolve({ status: 'completed' })),
  getJobLog: vi.fn(() => Promise.resolve({ log: [] })),
}))

const uncertaintyCheckbox = () =>
  screen.getByLabelText(/Propagate uncertainty in CCVA misclassification/i)

describe('Uncertainty checkbox behavior (issue #68)', () => {
  it('renders a checkbox that is checked by default (propagate = on)', () => {
    render(<JobForm onJobSubmitted={() => {}} />)
    const cb = uncertaintyCheckbox()
    expect(cb.type).toBe('checkbox')
    expect(cb.checked).toBe(true)
  })
  it('unchecks when clicked', () => {
    render(<JobForm onJobSubmitted={() => {}} />)
    const cb = uncertaintyCheckbox()
    fireEvent.click(cb)
    expect(cb.checked).toBe(false)
  })
})
```

- [ ] **Step 3: Run both new tests to verify they fail**

Run: `cd frontend && npx vitest run src/components/JobForm.issue68.test.js src/components/JobForm.issue68.behavior.test.jsx`
Expected: FAIL — checkbox/handler strings absent; `getByLabelText` can't find the checkbox (it's still a dropdown).

- [ ] **Step 4: Replace the uncertainty form-group with a checkbox**

In `frontend/src/components/JobForm.jsx`, replace the entire uncertainty block:
```jsx
        {/* Vacalibration-specific parameters */}
        {(jobType === 'vacalibration' || jobType === 'pipeline') && (
          <div className="form-group">
            <label>Propagate uncertainty in misclassification matrix</label>
            <CustomSelect
              value={calibModelType}
              onChange={setCalibModelType}
              options={[
                { value: 'Mmatprior', label: 'Yes (Informative Prior)' },
                { value: 'Mmatfixed', label: 'No (Fixed misclassification matrix)' }
              ]}
            />
            <small className="form-hint">
              Controls how uncertainty in misclassification estimates is handled
            </small>
          </div>
        )}
```
with:
```jsx
        {/* Vacalibration-specific parameters */}
        {(jobType === 'vacalibration' || jobType === 'pipeline') && (
          <div className="form-group">
            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={calibModelType === 'Mmatprior'}
                onChange={(e) => setCalibModelType(e.target.checked ? 'Mmatprior' : 'Mmatfixed')}
              />
              {' '}Propagate uncertainty in CCVA misclassification
            </label>
            <small className="form-hint">
              Controls whether to propagate uncertainty in{' '}
              <a
                href="https://github.com/sandy-pramanik/CCVA-Misclassification-Matrices"
                target="_blank"
                rel="noopener noreferrer"
              >
                CCVA misclassification estimate
              </a>
            </small>
          </div>
        )}
```

- [ ] **Step 5: Update the obsolete issue-#25 assertions in JobForm.test.js**

In `frontend/src/components/JobForm.test.js`, replace the entire `describe('Uncertainty propagation labels (issue #25)', ...)` block (the one asserting the old label and the `'Yes (Informative Prior)'` / `'No (Fixed misclassification matrix)'` option labels) with:
```js
describe('Uncertainty propagation control (issue #68 supersedes #25)', () => {
  it('label is the new CCVA wording, not the old matrix wording', () => {
    expect(jobFormSrc).toContain('Propagate uncertainty in CCVA misclassification')
    expect(jobFormSrc).not.toContain('Propagate uncertainty in misclassification matrix')
    expect(jobFormSrc).not.toContain('Uncertainty Propagation')
  })

  it('is a checkbox bound to calibModelType (no Yes/No dropdown options)', () => {
    expect(jobFormSrc).toContain("checked={calibModelType === 'Mmatprior'}")
    expect(jobFormSrc).not.toContain("'Yes (Informative Prior)'")
    expect(jobFormSrc).not.toContain("'No (Fixed misclassification matrix)'")
  })
})
```

- [ ] **Step 6: Run the new + updated tests to verify they pass**

Run: `cd frontend && npx vitest run src/components/JobForm.issue68.test.js src/components/JobForm.issue68.behavior.test.jsx src/components/JobForm.test.js`
Expected: PASS.

- [ ] **Step 7: Run the existing behavior test (no regression)**

Run: `cd frontend && npx vitest run src/components/JobForm.behavior.test.jsx`
Expected: PASS (4 tests — algorithm/ensemble flow is unaffected by the uncertainty checkbox).

- [ ] **Step 8: Commit**

```bash
git add frontend/src/components/JobForm.jsx frontend/src/components/JobForm.test.js frontend/src/components/JobForm.issue68.test.js frontend/src/components/JobForm.issue68.behavior.test.jsx
git commit -m "feat(form): uncertainty propagation as a checkbox with CCVA link (#68)"
```

---

## Task 4: Input reorder

**Files:**
- Modify: `frontend/src/components/JobForm.jsx` (relocate form-group blocks)
- Test (jsdom): append to `frontend/src/components/JobForm.issue68.behavior.test.jsx`

- [ ] **Step 1: Write the failing order test**

Append to `frontend/src/components/JobForm.issue68.behavior.test.jsx`:
```jsx
describe('Form field order (issue #68)', () => {
  it('renders fields in the order: Job Type, Country, Age Group, CCVA Algorithm, Propagate uncertainty, Upload, MCMC', () => {
    const { container } = render(<JobForm onJobSubmitted={() => {}} />)
    const text = container.textContent
    const sequence = [
      'Job Type',
      'Country',
      'Age Group',
      'Computer-Coded Verbal Autopsy (CCVA) Algorithm',
      'Propagate uncertainty in CCVA misclassification',
      'VA Data Files',
      'MCMC Specifics',
    ]
    const positions = sequence.map((s) => text.indexOf(s))
    positions.forEach((p, i) => expect(p, `"${sequence[i]}" not found`).toBeGreaterThan(-1))
    for (let i = 1; i < positions.length; i++) {
      expect(positions[i], `"${sequence[i]}" should come after "${sequence[i - 1]}"`).toBeGreaterThan(positions[i - 1])
    }
  })
})
```
(Default `jobType` is `vacalibration`, so Country, uncertainty, upload rows, and MCMC all render.)

- [ ] **Step 2: Run the test to verify it fails**

Run: `cd frontend && npx vitest run src/components/JobForm.issue68.behavior.test.jsx`
Expected: FAIL — current order is Job Type, Algorithm, Age Group, Country, ... (Country/Age/Algorithm out of the target order; MCMC before Upload).

- [ ] **Step 3: Reorder the form-group blocks**

In `frontend/src/components/JobForm.jsx`, the `<form>` currently renders these blocks in this order:
1. Job Type
2. Algorithm blocks (the three `{jobType === ...}` algorithm `form-group`s)
3. Age Group
4. Country (`{jobType !== 'openva' && ...}`)
5. Uncertainty (now a checkbox, from Task 3)
6. MCMC (`Advanced` → `MCMC Specifics`)
7. VA Data upload (the `{jobType === 'vacalibration' ? (...) : (...)}` block)
8. demo-info / error / progress / form-actions

Move them (cut whole blocks, paste — do not edit their contents) into this order:
1. Job Type
2. **Country** block
3. **Age Group** block
4. Algorithm blocks (all three `{jobType === ...}` blocks, kept together in their existing relative order: openva, pipeline, vacalibration)
5. Uncertainty checkbox block
6. **VA Data upload** block
7. **MCMC** block
8. demo-info / error / progress / form-actions (unchanged, stay last)

So the net moves are: Country and Age Group move up above the algorithm blocks; the MCMC block moves down to sit *after* the VA Data upload block. Each block's internal JSX (including its `{jobType ...}` / `{jobType !== 'openva'}` guard) is unchanged — only their order in the file changes.

- [ ] **Step 4: Run the order test to verify it passes**

Run: `cd frontend && npx vitest run src/components/JobForm.issue68.behavior.test.jsx`
Expected: PASS (checkbox tests + order test).

- [ ] **Step 5: Run the full JobForm + form test set to confirm no regression**

Run: `cd frontend && npx vitest run src/components/JobForm.test.js src/components/JobForm.behavior.test.jsx src/components/JobForm.issue68.test.js src/components/JobForm.issue68.behavior.test.jsx`
Expected: PASS. (Behavior tests query by label/`.upload-row`, so reorder doesn't affect them; the issue-#25/#26/#28-style source regexes still match because each `{jobType === 'vacalibration'}` block stays a contiguous unit.)

- [ ] **Step 6: Build to confirm valid JSX after the move**

Run: `cd frontend && npm run build`
Expected: build succeeds (no JSX/syntax errors from the relocation).

- [ ] **Step 7: Commit**

```bash
git add frontend/src/components/JobForm.jsx frontend/src/components/JobForm.issue68.behavior.test.jsx
git commit -m "feat(form): reorder inputs per issue #68 (MCMC last)"
```

---

## Task 5: Full verification

**Files:** none (verification only)

- [ ] **Step 1: Run the entire frontend suite**

Run: `cd frontend && npx vitest run --exclude '**/integration.test.js'`
Expected: all pass. (The integration test needs a live backend on :8000 and can flake under full-suite concurrency — run it separately if the backend is up: `npx vitest run src/api/integration.test.js`.)

- [ ] **Step 2: Manual check (dev server)**

Run: `cd frontend && npm run dev`, open `http://localhost:5173/comsa-dashboard/`, log in, and on the Calibrate page confirm:
- Heading is "Correcting for Algorithmic Misclassification in Estimating Cause Distributions" (no "Submit and monitor…" subtitle); the #69 credit line still shows beneath it.
- Sidebar brand reads "VA-Calibration"; browser tab title is "VA-Calibration Platform".
- Field order top→bottom: Job Type, Country, Age Group, CCVA Algorithm, Propagate uncertainty (checkbox, checked by default), Upload VA Data, then MCMC Specifics.
- Age Group shows "Children (1-59 months)"; Country list is alphabetical ending in "Other".
- The "CCVA misclassification estimate" link opens the CCVA-Misclassification-Matrices repo in a new tab.
- "MCMC Specifics" toggle shows the three-line hint.
- Submitting still works (payload unchanged: checked → `Mmatprior`, unchecked → `Mmatfixed`).

---

## Self-Review (completed by plan author)

- **Spec coverage:** title + subtitle removal (Task 1); VA-Calibration branding (Task 1); input reorder w/ MCMC last (Task 4); "Children (1-59 months)" (Task 2); alphabetical country list + "Other" (Task 2); CCVA algorithm label (Task 2); uncertainty checkbox default-checked + new label + hint + CCVA link reusing `calibModelType` (Task 3); "MCMC Specifics" + three-line hint (Task 2). All covered. Out-of-scope items (spelled-out prose, package name) correctly untouched.
- **Existing-test impact:** the issue-#25 block in `JobForm.test.js` (old uncertainty label + Yes/No option labels) is explicitly updated in Task 3 Step 5; issue-#26 button/nav-label assertions and `JobForm.behavior.test.jsx` are verified unaffected (Tasks 1/3/4 regression steps).
- **Placeholder scan:** none — every code step shows the exact before/after.
- **Type/string consistency:** the uncertainty handler `e.target.checked ? 'Mmatprior' : 'Mmatfixed'` and `checked={calibModelType === 'Mmatprior'}` match across the implementation (Task 3 Step 4), the source tests (Task 3 Step 1), and the updated `JobForm.test.js` (Task 3 Step 5). The label "Propagate uncertainty in CCVA misclassification", country option `{ value: 'other', label: 'Other' }`, and "MCMC Specifics" are used identically in implementation and tests. The order test (Task 4) reuses the same label strings introduced in Tasks 2–3.
