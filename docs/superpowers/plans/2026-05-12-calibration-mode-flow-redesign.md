# Calibration-Only Algorithms-First Flow — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Flip the Calibration Only mode UI in `JobForm.jsx` from ensemble-first to algorithms-first so it matches the `vacalibration` R package's mental model (ensemble = additional output, not a mode switch).

**Architecture:** Single-component refactor of `JobForm.jsx`. The conditional that today renders `(jobType === 'vacalibration' || jobType === 'pipeline')` ensemble UI is split: Pipeline keeps its existing ensemble-first checkbox flow, Calibration gets a new algorithms-first block where (a) algorithm checkboxes are always visible, (b) an "Also run ensemble" row is always rendered but disabled when <2 algos are selected, (c) upload rows are always per-algorithm. A new session-scoped sentinel `ensembleUserTouched` powers "sticky" ensemble behavior across 1↔2 crossings. Backend is unchanged.

**Tech Stack:** React 18 + hooks, vitest, @testing-library/react (jsdom env), Playwright for E2E.

**Spec:** `docs/superpowers/specs/2026-05-12-calibration-mode-flow-redesign.md`

---

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `frontend/src/components/JobForm.jsx` | Modify | Split `jobType` conditional; new vacalibration block; add `ensembleUserTouched` state and Effect B |
| `frontend/src/components/JobForm.test.js` | Modify | Update source-level assertions that depended on ensemble-first ordering |
| `frontend/src/components/JobForm.behavior.test.jsx` | Create | 4 RTL behavior tests for state transitions (uses `@vitest-environment jsdom`) |
| `frontend/e2e/demo-gallery.spec.js` | (Verify) | Re-run to confirm no selector regression; modify only if needed |
| `backend/**` | — | No changes |

`JobForm.test.js` uses source-level TDD (greps the JSX source for patterns). That style is fine for structural assertions ("ensemble row is rendered for vacalibration") but cannot verify state transitions, which is why we add a sibling `.behavior.test.jsx` file using React Testing Library for the 4 transition tests.

---

## Task 1: Add 4 RTL behavior tests (failing — TDD red phase)

**Files:**
- Create: `frontend/src/components/JobForm.behavior.test.jsx`

These tests describe the post-refactor behaviors; they will all fail against the current code.

- [ ] **Step 1: Create the new test file**

Create `frontend/src/components/JobForm.behavior.test.jsx` with:

```jsx
/**
 * @vitest-environment jsdom
 */
import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, screen, fireEvent } from '@testing-library/react'
import JobForm from './JobForm'

// Stub the API client — these tests are pure UI behavior, no backend calls.
vi.mock('../api/client', () => ({
  submitJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
  submitDemoJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
  getJobStatus: vi.fn(() => Promise.resolve({ status: 'completed' })),
  getJobLog: vi.fn(() => Promise.resolve({ log: [] })),
}))

const renderForm = () => render(<JobForm onJobSubmitted={() => {}} />)

const switchToCalibrationOnly = () => {
  // CustomSelect renders a button-driven popover. The current Job Type select
  // shows the label of the current value; click it and pick "Calibration Only".
  // If CustomSelect's interaction is hard to drive, prefer triggering its
  // onChange via a native select fallback or fireEvent on the option element.
  const trigger = screen.getByText(/Full Pipeline|openVA Only|Calibration Only/)
  fireEvent.click(trigger)
  fireEvent.click(screen.getByText('Calibration Only'))
}

const getAlgoCheckbox = (name) =>
  screen.getByLabelText(new RegExp(`^${name}\\b`, 'i'))

const getEnsembleCheckbox = () =>
  screen.getByLabelText(/Also run ensemble/i)

describe('Calibration Only — algorithms-first flow', () => {
  beforeEach(() => {
    // Make sure each test starts with a clean module/state.
    vi.clearAllMocks()
  })

  it('ensemble row is rendered but disabled when only 1 algorithm is selected', () => {
    renderForm()
    switchToCalibrationOnly()

    // Default state: InterVA only.
    const ensemble = getEnsembleCheckbox()
    expect(ensemble).toBeTruthy()
    expect(ensemble.disabled).toBe(true)

    // Hint text is visible.
    expect(screen.getByText(/requires 2\+ algorithms/i)).toBeTruthy()
  })

  it('auto-enables ensemble when user crosses from 1 to 2 algorithms', () => {
    renderForm()
    switchToCalibrationOnly()

    const ensemble = getEnsembleCheckbox()
    expect(ensemble.checked).toBe(false)

    // Check a second algorithm.
    fireEvent.click(getAlgoCheckbox('InSilicoVA'))

    // Ensemble enables AND auto-checks.
    expect(ensemble.disabled).toBe(false)
    expect(ensemble.checked).toBe(true)
  })

  it('respects sticky-uncheck: once user unchecks ensemble, do not auto-re-enable on re-crossing', () => {
    renderForm()
    switchToCalibrationOnly()

    // Add a 2nd algo → auto-enables.
    fireEvent.click(getAlgoCheckbox('InSilicoVA'))
    const ensemble = getEnsembleCheckbox()
    expect(ensemble.checked).toBe(true)

    // User unchecks ensemble.
    fireEvent.click(ensemble)
    expect(ensemble.checked).toBe(false)

    // Drop back to 1 algorithm.
    fireEvent.click(getAlgoCheckbox('InSilicoVA'))
    expect(ensemble.disabled).toBe(true)

    // Re-add 2nd algorithm. Ensemble must stay unchecked (sticky).
    fireEvent.click(getAlgoCheckbox('InSilicoVA'))
    expect(ensemble.disabled).toBe(false)
    expect(ensemble.checked).toBe(false)
  })

  it('renders one labeled upload row per selected algorithm, regardless of ensemble', () => {
    renderForm()
    switchToCalibrationOnly()

    // 1 algorithm → 1 labeled upload row showing "InterVA".
    expect(screen.getAllByText(/^InterVA/i).length).toBeGreaterThanOrEqual(1)
    expect(screen.queryByText(/^InSilicoVA/i)).toBeNull()

    // Add a 2nd algorithm → 2 labeled upload rows.
    fireEvent.click(getAlgoCheckbox('InSilicoVA'))
    expect(screen.getAllByText(/^InterVA/i).length).toBeGreaterThanOrEqual(1)
    expect(screen.getAllByText(/^InSilicoVA/i).length).toBeGreaterThanOrEqual(1)

    // Each upload row must have its own file input.
    const fileInputs = document.querySelectorAll('input[type="file"]')
    expect(fileInputs.length).toBe(2)
  })
})
```

- [ ] **Step 2: Run the tests to verify they all fail**

Run: `cd frontend && npx vitest run src/components/JobForm.behavior.test.jsx`
Expected: All 4 tests FAIL (current JobForm.jsx renders the ensemble-first UI; behavior assertions will not match).

If a test fails for an unexpected reason (e.g., the helper `switchToCalibrationOnly` can't find the dropdown trigger), inspect `CustomSelect.jsx` and adapt the helper. The default Job Type is already `'vacalibration'` (line 9), so `switchToCalibrationOnly()` may be a no-op in practice — keep it as a guard but accept that it may not need to actually click anything.

- [ ] **Step 3: Commit failing tests**

```bash
cd /Users/ericliu/projects5/comsa_dashboard
git add frontend/src/components/JobForm.behavior.test.jsx
git commit -m "test: add behavior tests for algorithms-first calibration UX (failing)"
```

---

## Task 2: Update source-level test assertions

**Files:**
- Modify: `frontend/src/components/JobForm.test.js:71-73` (keeps-single-file-input assertion)
- Modify: `frontend/src/components/JobForm.test.js:43-78` (Checkbox-driven ensemble uploads block — partial)

The current assertions encode the ensemble-first model. Two of them will break under the new design and need updating; the rest still hold for Pipeline mode (which is unchanged).

- [ ] **Step 1: Replace the obsolete "keeps single file input for non-ensemble vacalibration" assertion**

Open `frontend/src/components/JobForm.test.js`. The current block at lines 71-73:

```javascript
it('keeps single file input for non-ensemble vacalibration', () => {
  expect(jobFormSrc).toContain("type=\"file\"")
})
```

Replace with:

```javascript
it('vacalibration mode always uses per-algorithm upload rows (no single-file branch)', () => {
  // The vacalibration JSX branch never renders the "VA Data File (CSV)" label —
  // that label is reserved for openVA-only and Pipeline non-ensemble modes.
  // Per-algorithm rows are denoted by `upload-row`/`upload-algo-label`.
  expect(jobFormSrc).toContain('upload-algo-label')

  // Negative guard: in the vacalibration branch, the legacy single-file label
  // must not appear. We tolerate the label elsewhere (Pipeline non-ensemble).
  const calibBlock = jobFormSrc.match(
    /jobType === 'vacalibration'[\s\S]*?(?=jobType === 'pipeline'|jobType === 'openva'|$)/
  )?.[0] || ''
  expect(calibBlock).not.toMatch(/VA Data File \(CSV\)/)
})
```

- [ ] **Step 2: Add structural assertion for the new vacalibration branch**

Inside the existing `describe('Checkbox-driven ensemble uploads', ...)` block, append:

```javascript
it('renders an always-visible ensemble row in the vacalibration branch', () => {
  // Source contains a disabled hint for the 1-algo case.
  expect(jobFormSrc).toMatch(/requires 2\+ algorithms/i)
})

it('introduces ensembleUserTouched sentinel for sticky-uncheck behavior', () => {
  expect(jobFormSrc).toMatch(/ensembleUserTouched/)
})

it('splits the jobType conditional so pipeline and vacalibration are separate branches', () => {
  // The OLD combined conditional `(jobType === 'vacalibration' || jobType === 'pipeline')`
  // for the ensemble checkbox must not appear in the new code — it has been split.
  // Pipeline's ensemble-first UI stays under jobType === 'pipeline'.
  expect(jobFormSrc).toContain("jobType === 'pipeline'")
  expect(jobFormSrc).toContain("jobType === 'vacalibration'")
  // The combined form for the ensemble toggle should be gone.
  expect(jobFormSrc).not.toMatch(
    /\(jobType === ['"]vacalibration['"] \|\| jobType === ['"]pipeline['"]\)[\s\S]{0,200}ensemble-toggle/
  )
})

it('removes the file-algorithm-mismatch hint banner', () => {
  // The hint is no longer needed because each upload row is labeled.
  expect(jobFormSrc).not.toContain('algorithm selection below will be used to match the data format')
})
```

- [ ] **Step 3: Run JobForm.test.js to confirm new assertions fail**

Run: `cd frontend && npx vitest run src/components/JobForm.test.js`
Expected: The five new/modified assertions FAIL (current source doesn't match them yet); other assertions still PASS.

- [ ] **Step 4: Commit**

```bash
cd /Users/ericliu/projects5/comsa_dashboard
git add frontend/src/components/JobForm.test.js
git commit -m "test: update JobForm source-level assertions for algorithms-first flow (failing)"
```

---

## Task 3: Refactor JobForm.jsx — introduce ensembleUserTouched and split jobType branches

**Files:**
- Modify: `frontend/src/components/JobForm.jsx` (state hooks at lines 8-25; effects at lines 56-92; render at lines 209-287, 392-453)

This is the meat of the change. It's grouped into one task because the JSX edits are interconnected, but each step is a focused edit.

- [ ] **Step 1: Add `ensembleUserTouched` state hook**

Open `frontend/src/components/JobForm.jsx`. Find the existing state declarations (lines 9-22) and add a new line immediately after the `ensemble` state on line 15:

```javascript
const [ensemble, setEnsemble] = useState(false);
const [ensembleUserTouched, setEnsembleUserTouched] = useState(false);
```

- [ ] **Step 2: Add Effect B — auto-enable ensemble on 1→2 crossing for calibration-only**

Below the existing effect that ends at line 92 (validation effect for ensemble requirements), insert a new effect:

```javascript
// Effect B (issue: algorithms-first flow): when the user crosses from 1 to 2+
// algorithms in calibration-only mode, auto-enable the ensemble checkbox —
// UNLESS the user has explicitly touched it (sticky behavior).
useEffect(() => {
  if (
    jobType === 'vacalibration' &&
    algorithms.length >= 2 &&
    !ensembleUserTouched
  ) {
    setEnsemble(true);
  }
}, [algorithms.length, jobType, ensembleUserTouched]);
```

- [ ] **Step 3: Wire the ensemble checkbox to set the touched sentinel**

The existing ensemble checkbox at lines 219-227:

```jsx
<input
  type="checkbox"
  checked={ensemble}
  onChange={(e) => setEnsemble(e.target.checked)}
/>
```

This handler is shared between Pipeline and Calibration today. We're about to split the JSX so each mode has its own checkbox. The new vacalibration checkbox uses:

```jsx
onChange={(e) => {
  setEnsembleUserTouched(true);
  setEnsemble(e.target.checked);
}}
```

The Pipeline checkbox keeps the simpler `onChange={(e) => setEnsemble(e.target.checked)}`. (We don't need stickiness in Pipeline because its ensemble checkbox is rendered first, not auto-toggled.)

- [ ] **Step 4: Split the algorithm-section JSX by jobType**

Locate the current block at lines 208-287 (the `<div className="form-group">` containing the Algorithm label, ensemble-toggle, hint, and picker). Replace the **entire** block with:

```jsx
{/* Algorithm Selection - split by job type */}
{jobType === 'openva' && (
  <div className="form-group">
    <label>Algorithm</label>
    <CustomSelect
      value={algorithms[0] || 'InterVA'}
      onChange={handleAlgorithmSelect}
      options={[
        { value: 'InterVA', label: 'InterVA (fastest, ~30sec)' },
        { value: 'InSilicoVA', label: 'InSilicoVA (most accurate, ~2-3min)' },
        { value: 'EAVA', label: 'EAVA (deterministic, ~1min)' }
      ]}
    />
    {validationError && <small className="validation-error">{validationError}</small>}
  </div>
)}

{jobType === 'pipeline' && (
  <div className="form-group">
    <label>
      Algorithm{ensemble ? 's' : ''}
      {ensemble && (
        <span className="required"> * Select at least 2 for ensemble</span>
      )}
    </label>

    <div className="ensemble-toggle">
      <label>
        <input
          type="checkbox"
          checked={ensemble}
          onChange={(e) => setEnsemble(e.target.checked)}
        />
        {' '}Ensemble Mode (combine multiple algorithms)
      </label>
    </div>

    {ensemble ? (
      <div className="algorithm-checkboxes">
        <label className="checkbox-label">
          <input
            type="checkbox"
            checked={algorithms.includes('InterVA')}
            onChange={() => handleAlgorithmToggle('InterVA')}
          />
          InterVA (fastest, ~30sec)
        </label>
        <label className="checkbox-label">
          <input
            type="checkbox"
            checked={algorithms.includes('InSilicoVA')}
            onChange={() => handleAlgorithmToggle('InSilicoVA')}
          />
          InSilicoVA (most accurate, ~2-3min)
        </label>
        <label className="checkbox-label">
          <input
            type="checkbox"
            checked={algorithms.includes('EAVA')}
            onChange={() => handleAlgorithmToggle('EAVA')}
          />
          EAVA (deterministic, ~1min)
        </label>
        {algorithms.length > 1 && (
          <small className="form-hint warning">
            Running {algorithms.length} algorithms will take approximately{' '}
            {algorithms.length === 2 ? '2-4 minutes' : '4-6 minutes'}
          </small>
        )}
      </div>
    ) : (
      <CustomSelect
        value={algorithms[0] || 'InterVA'}
        onChange={handleAlgorithmSelect}
        options={[
          { value: 'InterVA', label: 'InterVA (fastest, ~30sec)' },
          { value: 'InSilicoVA', label: 'InSilicoVA (most accurate, ~2-3min)' },
          { value: 'EAVA', label: 'EAVA (deterministic, ~1min)' }
        ]}
      />
    )}

    {validationError && <small className="validation-error">{validationError}</small>}
  </div>
)}

{jobType === 'vacalibration' && (
  <div className="form-group">
    <label>Algorithms *</label>

    <div className="algorithm-checkboxes">
      <label className="checkbox-label">
        <input
          type="checkbox"
          checked={algorithms.includes('InterVA')}
          onChange={() => handleAlgorithmToggle('InterVA')}
        />
        InterVA (fastest, ~30sec)
      </label>
      <label className="checkbox-label">
        <input
          type="checkbox"
          checked={algorithms.includes('InSilicoVA')}
          onChange={() => handleAlgorithmToggle('InSilicoVA')}
        />
        InSilicoVA (most accurate, ~2-3min)
      </label>
      <label className="checkbox-label">
        <input
          type="checkbox"
          checked={algorithms.includes('EAVA')}
          onChange={() => handleAlgorithmToggle('EAVA')}
        />
        EAVA (deterministic, ~1min)
      </label>
    </div>

    {/* Ensemble row: always rendered, disabled when <2 algos */}
    <div className="ensemble-toggle">
      <label>
        <input
          type="checkbox"
          checked={ensemble && algorithms.length >= 2}
          disabled={algorithms.length < 2}
          onChange={(e) => {
            setEnsembleUserTouched(true);
            setEnsemble(e.target.checked);
          }}
        />
        {' '}Also run ensemble (combines algorithms)
      </label>
      {algorithms.length < 2 ? (
        <small className="form-hint">Requires 2+ algorithms</small>
      ) : (
        <small className="form-hint">
          Runs per-algorithm calibration plus an additional combined ensemble result.
          {algorithms.length > 1 && (
            <>{' '}Estimated runtime: {algorithms.length === 2 ? '2-4 minutes' : '4-6 minutes'}.</>
          )}
        </small>
      )}
    </div>

    {validationError && <small className="validation-error">{validationError}</small>}
  </div>
)}
```

- [ ] **Step 5: Split the upload-section JSX by jobType**

Locate the current upload block at lines 392-453 (the ternary `{jobType === 'vacalibration' && ensemble ? (...) : (...)}`). Replace it with:

```jsx
{jobType === 'vacalibration' ? (
  <div className="form-group">
    <label>VA Data Files (one CSV per selected algorithm)</label>
    {uploads.map((upload, index) => (
      <div key={upload.id} className="upload-row">
        <span className="upload-algo-label">{upload.algorithm}</span>
        <input
          type="file"
          accept=".csv"
          onChange={(e) => updateUpload(index, 'file', e.target.files[0])}
        />
        {upload.file && <span className="file-name">{upload.file.name}</span>}
      </div>
    ))}
    <small className="form-hint">
      Upload one CSV file per selected algorithm. Required columns: ID, cause.
    </small>
    <div className="sample-download">
      <div className="sample-links">
        <span>Sample CSV (neonate, 1190 records):</span>
        <a href={`${import.meta.env.BASE_URL}sample_interva_neonate.csv`} download>InterVA</a>
        <a href={`${import.meta.env.BASE_URL}sample_insilicova_neonate.csv`} download>InSilicoVA</a>
        <a href={`${import.meta.env.BASE_URL}sample_eava_neonate.csv`} download>EAVA</a>
      </div>
      <small className="sample-source">Source: Pramanik S, Wilson E, Fiksel J, Gilbert B, Datta A (2025). <a href="https://github.com/VA-calibration/vacalibration" target="_blank" rel="noopener noreferrer"><em>vacalibration: Calibration of Computer-Coded Verbal Autopsy Algorithm</em></a>. R package version 2.0. COMSA Mozambique data.</small>
    </div>
  </div>
) : (
  <div className="form-group">
    <label>VA Data File (CSV)</label>
    <input
      type="file"
      accept=".csv"
      onChange={(e) => updateUpload(0, 'file', e.target.files[0])}
    />
    <small className="form-hint">
      WHO 2016 VA questionnaire format (columns: i004a, i004b, ...)
    </small>
    <div className="sample-download">
      <a
        href={`${import.meta.env.BASE_URL}${ageGroup === 'neonate' ? 'sample_openva_neonate.csv' : 'sample_openva_child.csv'}`}
        download
      >
        Download sample CSV ({ageGroup === 'neonate' ? 'neonate' : 'child'})
      </a>
    </div>
  </div>
)}
```

Note: Pipeline mode now uses the "openVA-style" single-file upload branch (the else). This is consistent with how the openVA portion of Pipeline accepts WHO 2016 input. Pipeline's ensemble mode previously didn't get per-algorithm upload rows either (the old multi-upload block was gated on `jobType === 'vacalibration' && ensemble`), so this is no behavior change for Pipeline.

- [ ] **Step 6: Update the existing upload-sync effect to always sync for vacalibration**

Find lines 69-79 (the effect that syncs upload rows from checked algorithms). Replace with:

```javascript
// Auto-generate upload rows from checked algorithms (calibration-only mode:
// always per-algorithm; pipeline/openva: single upload).
useEffect(() => {
  if (jobType === 'vacalibration') {
    setUploads(prev => {
      return algorithms.map(algo => {
        const existing = prev.find(u => u.algorithm === algo);
        return existing || { id: nextUploadId++, algorithm: algo, file: null };
      });
    });
  }
}, [algorithms, jobType]);
```

Also adjust the earlier effect at lines 56-67 — remove the upload-collapse logic that was tied to `ensemble`. The new version:

```javascript
// Sync algorithms state when switching between single/multi mode.
useEffect(() => {
  const needsSingleSelect =
    jobType === 'openva' ||
    (jobType === 'pipeline' && !ensemble);

  if (needsSingleSelect) {
    setAlgorithms(prev => prev.length > 1 ? [prev[0]] : prev);
  }

  // For openva/pipeline modes, collapse uploads to a single row.
  if (jobType !== 'vacalibration') {
    setUploads(prev => prev.length > 1 ? [prev[0]] : prev);
  }
}, [jobType, ensemble]);
```

- [ ] **Step 7: Update submit-button disabled condition**

Locate the submit button at line 479. The current expression:

```jsx
disabled={loading || activeJob || (
  jobType === 'vacalibration' && ensemble
    ? uploads.some(u => !u.file)
    : !uploads[0]?.file
)}
```

Replace with (vacalibration always requires every upload row to have a file):

```jsx
disabled={loading || activeJob || (
  jobType === 'vacalibration'
    ? uploads.some(u => !u.file)
    : !uploads[0]?.file
)}
```

- [ ] **Step 8: Update validation effect — remove ensemble-specific gating**

The current validation effect at lines 82-92 enforces "ensemble requires ≥2 algos". With the new flow, ensemble is automatically disabled when <2 algos are selected (it can't be set true via UI), so this constraint is structurally enforced. Simplify to:

```javascript
useEffect(() => {
  if (algorithms.length === 0) {
    setValidationError('Please select at least one algorithm');
  } else if (jobType === 'pipeline' && ensemble && algorithms.length < 2) {
    // Pipeline still requires explicit validation (its ensemble checkbox is
    // user-toggled before the algorithm picker — different UX shape).
    setValidationError('Ensemble calibration requires at least 2 algorithms');
  } else {
    setValidationError(null);
  }
}, [ensemble, algorithms, jobType]);
```

- [ ] **Step 9: Update submit / demo handlers — remove vacalibration-specific ensemble validation**

Lines 125-129 in `handleSubmit` and the matching block in `handleDemo` (lines 169-173) currently throw the "Ensemble calibration requires at least 2 algorithms" error for vacalibration too. Since the UI now prevents this state for vacalibration, remove the vacalibration arm:

Replace lines 125-129 with:

```javascript
if (ensemble && algorithms.length < 2 && jobType === 'pipeline') {
  setError('Ensemble calibration requires at least 2 algorithms');
  setLoading(false);
  return;
}
```

Make the identical change in `handleDemo` (lines 169-173).

Also update the submit payload — pass `ensemble: ensemble && algorithms.length >= 2` so the client never sends a logically-invalid combination:

In `handleSubmit` (line 139): replace `ensemble,` with `ensemble: ensemble && algorithms.length >= 2,`.
In `handleDemo` (line 176): replace `ensemble` with `ensemble: ensemble && algorithms.length >= 2`.

- [ ] **Step 10: Remove the file-algorithm-mismatch hint**

The hint at lines 232-238 (`If your data already contains algorithm information, the algorithm selection below will be used to match the data format`) is in the old combined-conditional block, which Step 4 already replaced. Confirm it's gone by searching:

Run: `grep -n 'algorithm selection below will be used to match' frontend/src/components/JobForm.jsx`
Expected: (no output)

If still present, delete the offending lines.

- [ ] **Step 11: Run all JobForm tests — expect PASS**

Run: `cd frontend && npx vitest run src/components/JobForm.test.js src/components/JobForm.behavior.test.jsx`

Expected:
- All assertions in `JobForm.test.js` PASS (including the 4 new ones added in Task 2).
- All 4 assertions in `JobForm.behavior.test.jsx` PASS.

If a behavior test fails because `screen.getByLabelText` can't find an element, double-check that:
- The ensemble checkbox is wrapped in its `<label>` (it is, per Step 4).
- The label text exactly matches the regex (`Also run ensemble`).
- Algorithm checkboxes are inside `<label className="checkbox-label">` with the algorithm name as label text.

If `switchToCalibrationOnly` is failing on the CustomSelect interaction, you can short-circuit it by relying on the default `jobType = 'vacalibration'` and removing the helper call from the tests (the form starts in calibration-only mode already).

- [ ] **Step 12: Commit**

```bash
cd /Users/ericliu/projects5/comsa_dashboard
git add frontend/src/components/JobForm.jsx
git commit -m "feat(ui): algorithms-first flow for Calibration Only mode

- Split jobType conditional into separate openva/pipeline/vacalibration JSX
  branches so the new algorithms-first UI for Calibration doesn't affect
  Pipeline's existing ensemble-first flow.
- For vacalibration: algorithm checkboxes always visible; 'Also run ensemble'
  row always rendered, disabled when <2 algos selected, with hint.
- Add ensembleUserTouched sentinel powering sticky-uncheck across 1<->2
  algorithm crossings.
- Auto-enable ensemble when crossing 1->2 algorithms (Effect B), respecting
  the touched sentinel.
- Upload section always shows one labeled row per selected algorithm in
  calibration-only mode.
- Remove obsolete file-algorithm-mismatch hint banner.
- Backend contract unchanged; ensemble is gated client-side as
  defense-in-depth before submit."
```

---

## Task 4: Run full test suite + manual smoke test

**Files:** None modified — verification only.

- [ ] **Step 1: Run the entire frontend vitest suite**

Run: `cd frontend && npm test -- --run`
Expected: All test files PASS. Failure here usually means another file depended on JobForm's old structure (unlikely — only JobForm.test.js and the new behavior file reference JobForm directly).

- [ ] **Step 2: Verify the backend is running and start it if not**

Run: `lsof -ti:8000 || (cd backend && Rscript run.R &)`
Wait a few seconds for it to come up. Verify with `curl -s http://localhost:8000/health`.

- [ ] **Step 3: Run the Playwright E2E suite**

Run: `cd frontend && npm run test:e2e`
Expected: Both E2E tests PASS. The E2E tests exercise the Demo Gallery flow, not JobForm directly, so they should be unaffected. If they fail with a selector error, inspect the failure and update the selector in `frontend/e2e/demo-gallery.spec.js`; do NOT update anything in JobForm.jsx.

- [ ] **Step 4: Manual UI smoke test**

Start the frontend (`cd frontend && npm run dev`) and open it in the browser.

Verify the following by hand:

1. Switch Job Type to "Calibration Only". Confirm:
   - Three algorithm checkboxes visible (InterVA checked by default).
   - "Also run ensemble" row visible but checkbox **disabled** with "Requires 2+ algorithms" hint.
   - One upload row labeled "InterVA".
2. Check "InSilicoVA". Confirm:
   - Ensemble row becomes **enabled** and **auto-checks**.
   - Hint changes to "Runs per-algorithm calibration plus an additional combined ensemble result. Estimated runtime: 2-4 minutes."
   - Upload rows now show "InterVA" and "InSilicoVA".
3. Uncheck "Also run ensemble". Drop "InSilicoVA". Re-check "InSilicoVA". Confirm:
   - Ensemble row enabled but checkbox **stays unchecked** (sticky).
4. Click "Run Demo". Confirm the job submits and runs (backend log shows 2 algorithms loaded).
5. Switch Job Type to "Full Pipeline". Confirm:
   - Ensemble checkbox appears FIRST (above the algorithm picker).
   - Picker is a single dropdown by default; switches to checkboxes when Ensemble Mode is checked.
   - This is the original flow, unchanged.
6. Switch Job Type to "openVA Only". Confirm single dropdown picker, single file upload.

- [ ] **Step 5: Commit any final adjustments**

If any step in Task 4 required a code tweak (e.g., E2E selector update), commit it now:

```bash
cd /Users/ericliu/projects5/comsa_dashboard
git add -p   # review hunks
git commit -m "fix: adjustments after end-to-end verification of algorithms-first flow"
```

If nothing was modified, skip this step.

---

## Acceptance Verification

After Task 4 passes:

- [ ] Acceptance #1: 1 algo selected → ensemble row disabled with "Requires 2+ algorithms" hint; one labeled upload row.
- [ ] Acceptance #2: 2nd algo checked → ensemble row enables and auto-checks; 2nd labeled upload row appears.
- [ ] Acceptance #3: Sticky-uncheck behavior verified manually (Task 4 Step 4 case 3) and by behavior test #3.
- [ ] Acceptance #4: Run Demo with N algorithms loads sample data for exactly those N algorithms; ensemble row included iff ensemble checkbox is checked and N ≥ 2.
- [ ] Acceptance #5: Pipeline mode and openVA Only mode behave identically to before (manual verification in Task 4 Step 4 cases 5 and 6).
- [ ] Acceptance #6: Existing vitest suite + 4 new vitest cases + E2E demo-gallery all PASS.

---

## Self-Review Notes

**Spec coverage:**
- UI Layout — Task 3 Steps 4-5.
- State Model (ensembleUserTouched, derived `canEnsemble`) — Task 3 Steps 1-3.
- Effect A (sync uploads) — Task 3 Step 6.
- Effect B (auto-enable 1→2) — Task 3 Step 2.
- Effect C (validation) — Task 3 Step 8.
- Submit payload gating — Task 3 Step 9.
- Edge case #1 (empty-array guard) — existing code preserved.
- Edge case #2 (keyed upload preservation) — Task 3 Step 6 retains `prev.find(u => u.algorithm === algo)`.
- Edge case #3 (Demo respects checkbox selection) — Task 3 Step 9 payload change; backend already supports this.
- Edge case #4 (job-type switch state persistence) — existing behavior preserved; only rendering branches on jobType.
- Edge case #5 (remove file-algorithm hint) — Task 3 Step 10.
- Edge case #6 (Pipeline mode untouched) — Task 3 Step 4 keeps Pipeline branch identical to today's code.
- Testing plan — Tasks 1, 2, 4.

**No placeholders detected:** All code blocks contain full text; all commands have expected outputs; all file paths are absolute or clearly relative-to-frontend.

**Type/name consistency:** `ensembleUserTouched` / `setEnsembleUserTouched` used consistently across the state declaration, Effect B, and the onChange handler. `handleAlgorithmToggle`, `handleAlgorithmSelect`, `updateUpload`, `uploads`, `algorithms` all use existing names from JobForm.jsx.
