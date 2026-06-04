# Input Panel Presentation (Issue #73) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refine the job submission form so required inputs are obvious and the job's input/output is stated plainly, per the 10 items in GitHub issue #73.

**Architecture:** Frontend-only. A new pure-function module maps two friendly dropdowns ("Input Type" / "Output Type") onto the existing backend `job_type` string (`openva` / `pipeline` / `vacalibration`), so `backend/plumber.R` is untouched. A second pure-function module centralizes timezone-labeled timestamp formatting, reused by Job Detail and Job List.

**Tech Stack:** React (Vite), Vitest + @testing-library/react for tests. Run all tests with `cd frontend && npm test`.

**Spec:** `docs/superpowers/specs/2026-06-02-input-panel-presentation-issue-73-design.md`

---

## File Structure

**New files**
- `frontend/src/utils/jobTypeMapping.js` — pure mapping between (inputType, outputType) and backend `job_type`, plus the option lists. Single source of truth for item #7.
- `frontend/src/utils/jobTypeMapping.test.js` — unit tests for the mapping.
- `frontend/src/utils/datetime.js` — `formatTimestamp(value)`: timezone-labeled local time, handling R array + tz-less UTC strings. Item #5.
- `frontend/src/utils/datetime.test.js` — unit tests for the formatter.
- `frontend/src/components/JobForm.issue73.test.js` — source-assertion tests for the new form strings/markup.
- `frontend/src/components/JobForm.issue73.behavior.test.jsx` — render/interaction tests (cascade, required asterisks, field order).

**Modified files**
- `frontend/src/utils/progress.js` — export the existing private `parseTimestamp` so `datetime.js` reuses it (no logic change).
- `frontend/src/components/JobForm.jsx` — the bulk of the work (items #1–#9).
- `frontend/src/components/JobDetail.jsx` — use `formatTimestamp` for Created/Started/Completed.
- `frontend/src/components/JobList.jsx` — use `formatTimestamp` for the Created column.
- `frontend/src/App.css` — restyle `.advanced-toggle` (item #3); add `.output-type-locked` and `.required-legend`.
- `frontend/src/components/JobForm.issue68.test.js` — migrate the uncertainty-label assertions superseded by item #8.
- `frontend/src/components/JobForm.issue68.behavior.test.jsx` — migrate the uncertainty-checkbox label helper and the field-order sequence.
- `frontend/src/components/JobForm.test.js` — migrate the uncertainty-label assertion superseded by item #8.

**Deliberately NOT changed**
- The submit button stays `'Calibrate'` and the App nav tab stays `Calibrate` (issue #26). Item #1 renames only the panel `<h2>` heading. `JobForm.test.js`'s quote-anchored `/['"]Submit Job['"]/` guard is unaffected because the heading is JSX text, not a quoted string.

---

## Task 1: jobType mapping utility (item #7 core logic)

**Files:**
- Create: `frontend/src/utils/jobTypeMapping.js`
- Test: `frontend/src/utils/jobTypeMapping.test.js`

- [ ] **Step 1: Write the failing test**

Create `frontend/src/utils/jobTypeMapping.test.js`:

```js
import { describe, it, expect } from 'vitest'
import {
  INPUT_TYPES,
  outputTypeOptions,
  deriveJobType,
  jobTypeToSelectors,
} from './jobTypeMapping.js'

describe('jobTypeMapping (issue #73)', () => {
  it('offers two input types', () => {
    expect(INPUT_TYPES.map((o) => o.value)).toEqual(['individual', 'ccva_output'])
  })

  it('Individual VA Records offers top-cause and distribution outputs', () => {
    expect(outputTypeOptions('individual').map((o) => o.value)).toEqual([
      'top_cause',
      'distribution',
    ])
  })

  it('Output from CCVA locks output to a single distribution option', () => {
    expect(outputTypeOptions('ccva_output').map((o) => o.value)).toEqual(['distribution'])
  })

  it('derives job_type for every valid combination', () => {
    expect(deriveJobType('individual', 'top_cause')).toBe('openva')
    expect(deriveJobType('individual', 'distribution')).toBe('pipeline')
    expect(deriveJobType('ccva_output', 'distribution')).toBe('vacalibration')
  })

  it('falls back to vacalibration for the locked input regardless of output', () => {
    expect(deriveJobType('ccva_output', 'top_cause')).toBe('vacalibration')
  })

  it('inverts a job_type back into selector values', () => {
    expect(jobTypeToSelectors('openva')).toEqual({ inputType: 'individual', outputType: 'top_cause' })
    expect(jobTypeToSelectors('pipeline')).toEqual({ inputType: 'individual', outputType: 'distribution' })
    expect(jobTypeToSelectors('vacalibration')).toEqual({ inputType: 'ccva_output', outputType: 'distribution' })
  })

  it('defaults unknown job_type to the vacalibration selectors', () => {
    expect(jobTypeToSelectors('???')).toEqual({ inputType: 'ccva_output', outputType: 'distribution' })
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && npx vitest run src/utils/jobTypeMapping.test.js`
Expected: FAIL — cannot resolve `./jobTypeMapping.js`.

- [ ] **Step 3: Write minimal implementation**

Create `frontend/src/utils/jobTypeMapping.js`:

```js
/**
 * Maps the issue #73 "Input Type" / "Output Type" selectors onto the backend
 * job_type string the API already understands ('openva' | 'pipeline' |
 * 'vacalibration'). Pure functions — single source of truth for the cascade.
 */

export const INPUT_TYPES = [
  { value: 'individual', label: 'Individual VA Records' },
  { value: 'ccva_output', label: 'Output from CCVA' },
];

const TOP_CAUSE = { value: 'top_cause', label: 'Individual Top Cause of Death' };
const DISTRIBUTION = { value: 'distribution', label: 'Cause Distribution' };

/** Output Type options depend on the chosen Input Type. */
export function outputTypeOptions(inputType) {
  if (inputType === 'individual') return [TOP_CAUSE, DISTRIBUTION];
  return [DISTRIBUTION]; // 'ccva_output' is locked to a single option
}

/** Derive the backend job_type from the two selectors. */
export function deriveJobType(inputType, outputType) {
  if (inputType === 'individual') {
    return outputType === 'top_cause' ? 'openva' : 'pipeline';
  }
  return 'vacalibration';
}

/** Inverse mapping: which selectors produce a given job_type. */
export function jobTypeToSelectors(jobType) {
  switch (jobType) {
    case 'openva':
      return { inputType: 'individual', outputType: 'top_cause' };
    case 'pipeline':
      return { inputType: 'individual', outputType: 'distribution' };
    case 'vacalibration':
    default:
      return { inputType: 'ccva_output', outputType: 'distribution' };
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd frontend && npx vitest run src/utils/jobTypeMapping.test.js`
Expected: PASS (7 tests).

- [ ] **Step 5: Commit**

```bash
git add frontend/src/utils/jobTypeMapping.js frontend/src/utils/jobTypeMapping.test.js
git commit -m "feat(form): add Input/Output Type -> job_type mapping util (#73)"
```

---

## Task 2: timestamp formatter with timezone (item #5)

**Files:**
- Modify: `frontend/src/utils/progress.js` (export `parseTimestamp`)
- Create: `frontend/src/utils/datetime.js`
- Test: `frontend/src/utils/datetime.test.js`

- [ ] **Step 1: Export the existing parser from progress.js**

In `frontend/src/utils/progress.js`, change the private declaration:

```js
function parseTimestamp(value) {
```

to:

```js
export function parseTimestamp(value) {
```

(No other change — `getElapsedTime` in the same file keeps calling it.)

- [ ] **Step 2: Write the failing test**

Create `frontend/src/utils/datetime.test.js`:

```js
import { describe, it, expect } from 'vitest'
import { formatTimestamp } from './datetime.js'

describe('formatTimestamp (issue #73)', () => {
  it('returns a dash for empty values', () => {
    expect(formatTimestamp(null)).toBe('-')
    expect(formatTimestamp(undefined)).toBe('-')
    expect(formatTimestamp('')).toBe('-')
  })

  it('includes a timezone label in the formatted output', () => {
    // toLocaleString with timeZoneName:'short' appends a zone token (e.g. "EDT",
    // "GMT+8"). We assert a non-empty, non-dash string that differs from the raw
    // ISO input — i.e. it was actually formatted.
    const out = formatTimestamp('2026-06-02T15:04:00Z')
    expect(out).not.toBe('-')
    expect(out).not.toBe('2026-06-02T15:04:00Z')
    expect(out.length).toBeGreaterThan(0)
  })

  it('handles the R array epoch-seconds format', () => {
    const epoch = new Date('2026-06-02T15:04:00Z').getTime() / 1000
    const out = formatTimestamp([epoch])
    expect(out).not.toBe('-')
  })

  it('parses a tz-less R string as UTC (delegates to parseTimestamp)', () => {
    // Same instant expressed two ways must format identically.
    const a = formatTimestamp('2026-06-02 15:04:00')
    const b = formatTimestamp('2026-06-02T15:04:00Z')
    expect(a).toBe(b)
  })

  it('returns a dash for unparseable input', () => {
    expect(formatTimestamp('not-a-date')).toBe('-')
  })
})
```

- [ ] **Step 3: Run test to verify it fails**

Run: `cd frontend && npx vitest run src/utils/datetime.test.js`
Expected: FAIL — cannot resolve `./datetime.js`.

- [ ] **Step 4: Write minimal implementation**

Create `frontend/src/utils/datetime.js`:

```js
import { parseTimestamp } from './progress.js';

/**
 * Format a job timestamp in the viewer's local time WITH an explicit timezone
 * label, so it is unambiguous which zone is shown (issue #73, item #5).
 * Accepts ISO strings, tz-less R UTC strings, and the R [epoch_seconds] array
 * format (parsing is delegated to parseTimestamp).
 */
export function formatTimestamp(value) {
  if (value === null || value === undefined || value === '') return '-';
  const d = parseTimestamp(value);
  if (Number.isNaN(d.getTime())) return '-';
  return d.toLocaleString(undefined, { timeZoneName: 'short' });
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd frontend && npx vitest run src/utils/datetime.test.js`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add frontend/src/utils/progress.js frontend/src/utils/datetime.js frontend/src/utils/datetime.test.js
git commit -m "feat(utils): timezone-labeled timestamp formatter (#73)"
```

---

## Task 3: JobForm — Input Type / Output Type cascade (item #7)

Replaces the single "Job Type" `CustomSelect` with two cascading selects, deriving `job_type` from them. All existing `jobType`-keyed logic keeps working because `jobType` becomes a derived constant.

**Files:**
- Modify: `frontend/src/components/JobForm.jsx`
- Modify: `frontend/src/components/JobForm.issue68.behavior.test.jsx` (field-order sequence)
- Create: `frontend/src/components/JobForm.issue73.behavior.test.jsx` (cascade)

- [ ] **Step 1: Update the field-order test to the new labels (failing)**

In `frontend/src/components/JobForm.issue68.behavior.test.jsx`, replace the `sequence` array and the test title in the "Form field order" block:

```js
  it('renders fields in order: Input Type, Output Type, Country, Age Group, CCVA Algorithm, Uncertainty, Upload, MCMC', () => {
    const { container } = render(<JobForm onJobSubmitted={() => {}} />)
    const text = container.textContent
    const sequence = [
      'Input Type',
      'Output Type',
      'Country',
      'Age Group',
      'Computer-Coded Verbal Autopsy (CCVA) Algorithm',
      'Uncertainty in CCVA misclassification',
      'Upload VA Data',
      'MCMC Specifics',
    ]
    const positions = sequence.map((s) => text.indexOf(s))
    positions.forEach((p, i) => expect(p, `"${sequence[i]}" not found`).toBeGreaterThan(-1))
    for (let i = 1; i < positions.length; i++) {
      expect(positions[i], `"${sequence[i]}" should come after "${sequence[i - 1]}"`).toBeGreaterThan(positions[i - 1])
    }
  })
```

- [ ] **Step 2: Write the cascade behavior test (failing)**

Create `frontend/src/components/JobForm.issue73.behavior.test.jsx`:

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

describe('Input Type / Output Type cascade (issue #73)', () => {
  it('defaults to Output from CCVA with a locked Cause Distribution output', () => {
    render(<JobForm onJobSubmitted={() => {}} />)
    // Default landing state = vacalibration.
    expect(screen.getByText('Output from CCVA')).toBeTruthy()
    expect(screen.getByText('Cause Distribution')).toBeTruthy()
  })

  it('switching Input Type to Individual VA Records reveals the two outputs', () => {
    render(<JobForm onJobSubmitted={() => {}} />)
    fireEvent.click(screen.getByText('Output from CCVA'))     // open Input Type
    fireEvent.click(screen.getByText('Individual VA Records')) // select it
    // Output Type now defaults to the first individual option.
    expect(screen.getByText('Individual Top Cause of Death')).toBeTruthy()
  })
})
```

- [ ] **Step 3: Run both tests to verify they fail**

Run: `cd frontend && npx vitest run src/components/JobForm.issue73.behavior.test.jsx src/components/JobForm.issue68.behavior.test.jsx`
Expected: FAIL — "Input Type" not found / "Output from CCVA" not found (form still shows "Job Type").

- [ ] **Step 4: Wire the cascade into JobForm.jsx**

4a. Add the import near the top of `frontend/src/components/JobForm.jsx` (after the existing imports):

```jsx
import { INPUT_TYPES, outputTypeOptions, deriveJobType, jobTypeToSelectors } from '../utils/jobTypeMapping';
```

4b. Replace the job-type state declaration:

```jsx
  const [jobType, setJobType] = useState('vacalibration');
```

with the two selectors (default = vacalibration landing state) and a derived `jobType`:

```jsx
  const initialSelectors = jobTypeToSelectors('vacalibration');
  const [inputType, setInputType] = useState(initialSelectors.inputType);
  const [outputType, setOutputType] = useState(initialSelectors.outputType);
  const jobType = deriveJobType(inputType, outputType);
```

4c. Keep `jobType` valid after an Input Type change by resetting Output Type to the first option for that input. Add this effect right after the existing polling effect (so it sits with the other effects):

```jsx
  // When Input Type changes, snap Output Type to the first valid option for it.
  useEffect(() => {
    setOutputType(outputTypeOptions(inputType)[0].value);
  }, [inputType]);
```

4d. Replace the "Job Type" form group:

```jsx
        <div className="form-group">
          <label>Job Type</label>
          <CustomSelect
            value={jobType}
            onChange={setJobType}
            options={[
              { value: 'pipeline', label: 'Full Pipeline (openVA + Calibration)' },
              { value: 'openva', label: 'openVA Only' },
              { value: 'vacalibration', label: 'Calibration Only' }
            ]}
          />
        </div>
```

with two cascading groups (the locked-output case renders read-only text):

```jsx
        <div className="form-group">
          <label>Input Type <span className="required">*</span></label>
          <CustomSelect
            value={inputType}
            onChange={setInputType}
            options={INPUT_TYPES}
          />
        </div>

        <div className="form-group">
          <label>Output Type <span className="required">*</span></label>
          {inputType === 'individual' ? (
            <CustomSelect
              value={outputType}
              onChange={setOutputType}
              options={outputTypeOptions('individual')}
            />
          ) : (
            <div className="output-type-locked">Cause Distribution</div>
          )}
        </div>
```

- [ ] **Step 5: Run the behavior tests to verify they pass**

Run: `cd frontend && npx vitest run src/components/JobForm.issue73.behavior.test.jsx src/components/JobForm.issue68.behavior.test.jsx`
Expected: PASS. (The field-order test now finds Input Type → Output Type → … in order.)

- [ ] **Step 6: Run the full JobForm test set to catch regressions**

Run: `cd frontend && npx vitest run src/components/JobForm`
Expected: All JobForm specs PASS except the uncertainty-label and presentation assertions handled in Task 4 — note any failures; they should be limited to `JobForm.test.js` / `JobForm.issue68.test.js` uncertainty strings (fixed next task). If anything else fails, stop and investigate before continuing.

- [ ] **Step 7: Commit**

```bash
git add frontend/src/components/JobForm.jsx \
        frontend/src/components/JobForm.issue73.behavior.test.jsx \
        frontend/src/components/JobForm.issue68.behavior.test.jsx
git commit -m "feat(form): cascading Input Type/Output Type selectors (#73)"
```

---

## Task 4: JobForm — labels, timings, ordering, asterisks, uncertainty, links (items #1, #2, #4, #6, #8, #9)

**Files:**
- Modify: `frontend/src/components/JobForm.jsx`
- Create: `frontend/src/components/JobForm.issue73.test.js`
- Modify: `frontend/src/components/JobForm.issue68.test.js`
- Modify: `frontend/src/components/JobForm.test.js`

- [ ] **Step 1: Write the issue #73 source-assertion test (failing)**

Create `frontend/src/components/JobForm.issue73.test.js`:

```js
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const src = readFileSync(resolve(__dir, 'JobForm.jsx'), 'utf-8')

describe('Panel heading & required legend (issue #73 items #1, #4)', () => {
  it('heading is "Submit Job", not "Submit New Job"', () => {
    expect(src).toContain('<h2>Submit Job</h2>')
    expect(src).not.toContain('Submit New Job')
  })
  it('shows a "Required fields" legend', () => {
    expect(src).toContain('required-legend')
    expect(src).toContain('Required fields')
  })
})

describe('Upload label & example script link (issue #73 items #6, #9)', () => {
  it('renames the upload label to "Upload VA Data"', () => {
    expect(src).toContain('Upload VA Data')
    expect(src).not.toContain('VA Data Files (one CSV per selected algorithm)')
  })
  it('links to the vacalibration example repository', () => {
    expect(src).toContain('https://github.com/sandy-pramanik/vacalibration')
  })
})

describe('Timings removed & algorithm order (issue #73 item #2)', () => {
  it('removes all per-algorithm timing hints', () => {
    expect(src).not.toContain('~30sec')
    expect(src).not.toContain('~2-3min')
    expect(src).not.toContain('~1min')
  })
  it('removes ensemble runtime estimates', () => {
    expect(src).not.toContain('Estimated runtime')
    expect(src).not.toContain('will take approximately')
  })
  it('orders algorithm options EAVA, InSilicoVA, InterVA in the calibration block', () => {
    const block = src.slice(src.indexOf("jobType === 'vacalibration'"))
    const eava = block.indexOf("checked={algorithms.includes('EAVA')}")
    const insilico = block.indexOf("checked={algorithms.includes('InSilicoVA')}")
    const interva = block.indexOf("checked={algorithms.includes('InterVA')}")
    expect(eava).toBeGreaterThan(-1)
    expect(eava).toBeLessThan(insilico)
    expect(insilico).toBeLessThan(interva)
  })
  it('orders the sample CSV links EAVA, InSilicoVA, InterVA', () => {
    const eava = src.indexOf('sample_eava_neonate.csv')
    const insilico = src.indexOf('sample_insilicova_neonate.csv')
    const interva = src.indexOf('sample_interva_neonate.csv')
    expect(eava).toBeLessThan(insilico)
    expect(insilico).toBeLessThan(interva)
  })
})

describe('Uncertainty block restructure (issue #73 item #8)', () => {
  it('uses a heading + a "Propagate" checkbox, not the combined #68 label', () => {
    expect(src).toContain('Uncertainty in CCVA misclassification')
    expect(src).not.toContain('Propagate uncertainty in CCVA misclassification')
    // keeps the binding and the reference link from #68
    expect(src).toContain("checked={calibModelType === 'Mmatprior'}")
    expect(src).toContain('https://github.com/sandy-pramanik/CCVA-Misclassification-Matrices')
  })
})
```

- [ ] **Step 2: Migrate the conflicting issue #68 assertions (still failing build of expectations)**

2a. In `frontend/src/components/JobForm.test.js`, replace the body of the `it('label is the new CCVA wording, …')` test (the assertion superseded by item #8):

```js
  it('label is the new CCVA wording, not the old matrix wording', () => {
    expect(jobFormSrc).toContain('Propagate uncertainty in CCVA misclassification')
    expect(jobFormSrc).not.toContain('Propagate uncertainty in misclassification matrix')
    expect(jobFormSrc).not.toContain('Uncertainty Propagation')
  })
```

with the issue #73 structure:

```js
  it('label is the new CCVA wording, not the old matrix wording', () => {
    // Issue #73 item #8 splits the #68 label into a heading + "Propagate" checkbox.
    expect(jobFormSrc).toContain('Uncertainty in CCVA misclassification')
    expect(jobFormSrc).not.toContain('Propagate uncertainty in misclassification matrix')
    expect(jobFormSrc).not.toContain('Uncertainty Propagation')
  })
```

2b. In `frontend/src/components/JobForm.issue68.test.js`, replace the `it('uses the new label and hint with the CCVA matrices link', …)` body:

```js
  it('uses the new label and hint with the CCVA matrices link', () => {
    expect(src).toContain('Propagate uncertainty in CCVA misclassification')
    expect(src).toContain('Controls whether to propagate uncertainty in')
    expect(src).toContain('https://github.com/sandy-pramanik/CCVA-Misclassification-Matrices')
    expect(src).not.toContain('Controls how uncertainty in misclassification estimates is handled')
    expect(src).not.toContain('Propagate uncertainty in misclassification matrix')
  })
```

with:

```js
  it('uses the new label and hint with the CCVA matrices link', () => {
    // #73 item #8: heading "Uncertainty in CCVA misclassification" + "Propagate" checkbox.
    expect(src).toContain('Uncertainty in CCVA misclassification')
    expect(src).toContain('Controls whether to propagate uncertainty in')
    expect(src).toContain('https://github.com/sandy-pramanik/CCVA-Misclassification-Matrices')
    expect(src).not.toContain('Controls how uncertainty in misclassification estimates is handled')
    expect(src).not.toContain('Propagate uncertainty in misclassification matrix')
  })
```

2c. In `frontend/src/components/JobForm.issue68.behavior.test.jsx`, change the checkbox label helper:

```js
const uncertaintyCheckbox = () =>
  screen.getByLabelText(/Propagate uncertainty in CCVA misclassification/i)
```

to:

```js
const uncertaintyCheckbox = () =>
  screen.getByLabelText(/Propagate/i)
```

- [ ] **Step 3: Run the tests to verify they fail**

Run: `cd frontend && npx vitest run src/components/JobForm.issue73.test.js src/components/JobForm.issue68.test.js src/components/JobForm.test.js src/components/JobForm.issue68.behavior.test.jsx`
Expected: FAIL — the source still says "Submit New Job", has timings, old upload label, and the combined uncertainty label.

- [ ] **Step 4: Apply the JobForm.jsx presentation edits**

4a. Heading + required legend. Replace:

```jsx
    <div className="job-form">
      <h2>Submit New Job</h2>
```

with:

```jsx
    <div className="job-form">
      <h2>Submit Job</h2>
      <p className="required-legend"><span className="required">*</span> Required fields</p>
```

4b. Add a required asterisk to the Country and Age Group labels. Replace `<label>Country</label>` with:

```jsx
            <label>Country <span className="required">*</span></label>
```

and `<label>Age Group</label>` with:

```jsx
            <label>Age Group <span className="required">*</span></label>
```

4c. openVA algorithm selector — reorder + strip timings + add asterisk. Replace the `jobType === 'openva'` form group's label and `CustomSelect`:

```jsx
            <label>Computer-Coded Verbal Autopsy (CCVA) Algorithm</label>
            <CustomSelect
              value={algorithms[0] || 'InterVA'}
              onChange={handleAlgorithmSelect}
              options={[
                { value: 'InterVA', label: 'InterVA (fastest, ~30sec)' },
                { value: 'InSilicoVA', label: 'InSilicoVA (most accurate, ~2-3min)' },
                { value: 'EAVA', label: 'EAVA (deterministic, ~1min)' }
              ]}
            />
```

with:

```jsx
            <label>Computer-Coded Verbal Autopsy (CCVA) Algorithm <span className="required">*</span></label>
            <CustomSelect
              value={algorithms[0] || 'InterVA'}
              onChange={handleAlgorithmSelect}
              options={[
                { value: 'EAVA', label: 'EAVA' },
                { value: 'InSilicoVA', label: 'InSilicoVA' },
                { value: 'InterVA', label: 'InterVA' }
              ]}
            />
```

4d. Pipeline algorithm label — add asterisk. Replace:

```jsx
            <label>
              Computer-Coded Verbal Autopsy (CCVA) Algorithm{ensemble ? 's' : ''}
              {ensemble && (
                <span className="required"> * Select at least 2 for ensemble</span>
              )}
            </label>
```

with:

```jsx
            <label>
              Computer-Coded Verbal Autopsy (CCVA) Algorithm{ensemble ? 's' : ''} <span className="required">*</span>
              {ensemble && (
                <span className="required"> Select at least 2 for ensemble</span>
              )}
            </label>
```

4e. Pipeline ensemble checkboxes — reorder + strip timings + drop runtime hint. Replace the `<div className="algorithm-checkboxes">` block inside the pipeline `ensemble ? (...)`:

```jsx
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
```

with:

```jsx
              <div className="algorithm-checkboxes">
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={algorithms.includes('EAVA')}
                    onChange={() => handleAlgorithmToggle('EAVA')}
                  />
                  EAVA
                </label>
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={algorithms.includes('InSilicoVA')}
                    onChange={() => handleAlgorithmToggle('InSilicoVA')}
                  />
                  InSilicoVA
                </label>
                <label className="checkbox-label">
                  <input
                    type="checkbox"
                    checked={algorithms.includes('InterVA')}
                    onChange={() => handleAlgorithmToggle('InterVA')}
                  />
                  InterVA
                </label>
              </div>
```

4f. Pipeline non-ensemble select — reorder + strip timings. Replace:

```jsx
              <CustomSelect
                value={algorithms[0] || 'InterVA'}
                onChange={handleAlgorithmSelect}
                options={[
                  { value: 'InterVA', label: 'InterVA (fastest, ~30sec)' },
                  { value: 'InSilicoVA', label: 'InSilicoVA (most accurate, ~2-3min)' },
                  { value: 'EAVA', label: 'EAVA (deterministic, ~1min)' }
                ]}
              />
```

with:

```jsx
              <CustomSelect
                value={algorithms[0] || 'InterVA'}
                onChange={handleAlgorithmSelect}
                options={[
                  { value: 'EAVA', label: 'EAVA' },
                  { value: 'InSilicoVA', label: 'InSilicoVA' },
                  { value: 'InterVA', label: 'InterVA' }
                ]}
              />
```

4g. Vacalibration checkboxes — reorder + strip timings + asterisk on label. Replace:

```jsx
            <label>Computer-Coded Verbal Autopsy (CCVA) Algorithms *</label>

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
```

with:

```jsx
            <label>Computer-Coded Verbal Autopsy (CCVA) Algorithms <span className="required">*</span></label>

            <div className="algorithm-checkboxes">
              <label className="checkbox-label">
                <input
                  type="checkbox"
                  checked={algorithms.includes('EAVA')}
                  onChange={() => handleAlgorithmToggle('EAVA')}
                />
                EAVA
              </label>
              <label className="checkbox-label">
                <input
                  type="checkbox"
                  checked={algorithms.includes('InSilicoVA')}
                  onChange={() => handleAlgorithmToggle('InSilicoVA')}
                />
                InSilicoVA
              </label>
              <label className="checkbox-label">
                <input
                  type="checkbox"
                  checked={algorithms.includes('InterVA')}
                  onChange={() => handleAlgorithmToggle('InterVA')}
                />
                InterVA
              </label>
            </div>
```

4h. Vacalibration ensemble hint — drop the runtime estimate. Replace:

```jsx
                <small className="form-hint">
                  Runs per-algorithm calibration plus an additional combined ensemble result.
                  {' '}Estimated runtime: {algorithms.length === 2 ? '2-4 minutes' : '4-6 minutes'}.
                </small>
```

with:

```jsx
                <small className="form-hint">
                  Runs per-algorithm calibration plus an additional combined ensemble result.
                </small>
```

4i. Uncertainty block restructure. Replace:

```jsx
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
```

with:

```jsx
          <div className="form-group">
            <label>Uncertainty in CCVA misclassification</label>
            <label className="checkbox-label">
              <input
                type="checkbox"
                checked={calibModelType === 'Mmatprior'}
                onChange={(e) => setCalibModelType(e.target.checked ? 'Mmatprior' : 'Mmatfixed')}
              />
              {' '}Propagate
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
```

4j. Upload label (#6), asterisk (#4), reorder sample links (#2), and add the example-script link (#9). Replace:

```jsx
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
            </div>
```

with:

```jsx
            <label>Upload VA Data <span className="required">*</span></label>
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
            <small className="form-hint">
              See the{' '}
              <a
                href="https://github.com/sandy-pramanik/vacalibration"
                target="_blank"
                rel="noopener noreferrer"
              >
                vacalibration example code
              </a>
              {' '}for how to prepare, run, and save input data.
            </small>
            <div className="sample-download">
              <div className="sample-links">
                <span>Sample CSV (neonate, 1190 records):</span>
                <a href={`${import.meta.env.BASE_URL}sample_eava_neonate.csv`} download>EAVA</a>
                <a href={`${import.meta.env.BASE_URL}sample_insilicova_neonate.csv`} download>InSilicoVA</a>
                <a href={`${import.meta.env.BASE_URL}sample_interva_neonate.csv`} download>InterVA</a>
              </div>
            </div>
```

4k. Add an asterisk to the non-vacalibration upload label. Replace `<label>VA Data File (CSV)</label>` with:

```jsx
            <label>VA Data File (CSV) <span className="required">*</span></label>
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `cd frontend && npx vitest run src/components/JobForm.issue73.test.js src/components/JobForm.issue68.test.js src/components/JobForm.test.js src/components/JobForm.issue68.behavior.test.jsx`
Expected: PASS for all.

- [ ] **Step 6: Commit**

```bash
git add frontend/src/components/JobForm.jsx \
        frontend/src/components/JobForm.issue73.test.js \
        frontend/src/components/JobForm.issue68.test.js \
        frontend/src/components/JobForm.test.js \
        frontend/src/components/JobForm.issue68.behavior.test.jsx
git commit -m "feat(form): labels, asterisks, timings, uncertainty, links (#73)"
```

---

## Task 5: Timestamps with timezone in Job Detail & Job List (item #5)

**Files:**
- Modify: `frontend/src/components/JobDetail.jsx`
- Modify: `frontend/src/components/JobList.jsx`
- Create: `frontend/src/components/Timestamps.issue73.test.js`

- [ ] **Step 1: Write the failing source test**

Create `frontend/src/components/Timestamps.issue73.test.js`:

```js
import { describe, it, expect } from 'vitest'
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const detailSrc = readFileSync(resolve(__dir, 'JobDetail.jsx'), 'utf-8')
const listSrc = readFileSync(resolve(__dir, 'JobList.jsx'), 'utf-8')

describe('Timestamps use the shared timezone-labeled formatter (issue #73)', () => {
  it('JobDetail imports and uses formatTimestamp for the time rows', () => {
    expect(detailSrc).toContain("from '../utils/datetime'")
    expect(detailSrc).toContain('formatTimestamp(status.created_at)')
    expect(detailSrc).toContain('formatTimestamp(status.started_at)')
    expect(detailSrc).toContain('formatTimestamp(status.completed_at)')
  })
  it('JobList imports and uses formatTimestamp for the created column', () => {
    expect(listSrc).toContain("from '../utils/datetime'")
    expect(listSrc).toContain('formatTimestamp(job.created_at)')
    expect(listSrc).not.toContain('new Date(job.created_at).toLocaleString()')
  })
})
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && npx vitest run src/components/Timestamps.issue73.test.js`
Expected: FAIL — `formatTimestamp` not imported/used yet.

- [ ] **Step 3: Update JobDetail.jsx**

3a. Add the import at the top of `frontend/src/components/JobDetail.jsx` (with the other imports):

```jsx
import { formatTimestamp } from '../utils/datetime';
```

3b. Delete the local `formatDate` helper:

```jsx
function formatDate(value) {
  if (!value) return '-';
  if (typeof value === 'string') return value;
  if (Array.isArray(value)) return new Date(value[0] * 1000).toLocaleString();
  if (typeof value === 'object') return JSON.stringify(value);
  return String(value);
}
```

3c. Update the three table rows. Replace:

```jsx
          <tr><td>Created</td><td>{formatDate(status.created_at)}</td></tr>
          <tr><td>Started</td><td>{formatDate(status.started_at)}</td></tr>
          <tr><td>Completed</td><td>{formatDate(status.completed_at)}</td></tr>
```

with:

```jsx
          <tr><td>Created</td><td>{formatTimestamp(status.created_at)}</td></tr>
          <tr><td>Started</td><td>{formatTimestamp(status.started_at)}</td></tr>
          <tr><td>Completed</td><td>{formatTimestamp(status.completed_at)}</td></tr>
```

- [ ] **Step 4: Update JobList.jsx**

4a. Add the import at the top of `frontend/src/components/JobList.jsx`:

```jsx
import { formatTimestamp } from '../utils/datetime';
```

4b. Replace the created-at cell:

```jsx
              <td>{new Date(job.created_at).toLocaleString()}</td>
```

with:

```jsx
              <td>{formatTimestamp(job.created_at)}</td>
```

- [ ] **Step 5: Run the test plus the existing component tests**

Run: `cd frontend && npx vitest run src/components/Timestamps.issue73.test.js src/components/JobDetail.test.js`
Expected: PASS. (JobDetail.test.js asserts CSMF headings, not timestamps, so it stays green.)

- [ ] **Step 6: Commit**

```bash
git add frontend/src/components/JobDetail.jsx \
        frontend/src/components/JobList.jsx \
        frontend/src/components/Timestamps.issue73.test.js
git commit -m "feat(jobs): timezone-labeled timestamps in detail & list (#73)"
```

---

## Task 6: CSS — MCMC heading, locked output, required legend (items #3, #4, #7)

CSS-only; verified by visual run rather than unit tests.

**Files:**
- Modify: `frontend/src/App.css`

- [ ] **Step 1: Restyle the MCMC toggle to match input titles (item #3)**

In `frontend/src/App.css`, replace the `.advanced-toggle` rule:

```css
.advanced-toggle {
  background: none;
  border: none;
  color: var(--color-secondary);
  cursor: pointer;
  font-size: 0.9rem;
  padding: 4px 0;
  font-family: var(--font-mono, monospace);
}
```

with one that matches `.form-group label` (font-weight 500, 0.875rem, primary color, default font family):

```css
.advanced-toggle {
  background: none;
  border: none;
  color: var(--color-primary);
  cursor: pointer;
  font-size: 0.875rem;
  font-weight: 500;
  padding: 4px 0;
}
```

- [ ] **Step 2: Add the required-legend and locked-output styles**

Append to `frontend/src/App.css` (after the `.required` rule near line 1137):

```css
.required-legend {
  margin: 0 0 1rem;
  font-size: 0.8rem;
  color: var(--color-secondary);
}

.output-type-locked {
  width: 100%;
  padding: 0.625rem 0.75rem;
  border: 1px solid var(--color-border);
  border-radius: var(--radius-sm);
  background: var(--color-surface, #f1f3f5);
  color: var(--color-secondary);
}
```

- [ ] **Step 3: Verify the app renders**

Run: `cd frontend && npm run build`
Expected: build succeeds with no errors.

- [ ] **Step 4: Commit**

```bash
git add frontend/src/App.css
git commit -m "style(form): MCMC heading, locked output, required legend (#73)"
```

---

## Task 7: Full suite, lint, and final verification

**Files:** none (verification only)

- [ ] **Step 1: Run the entire frontend test suite**

Run: `cd frontend && npm test`
Expected: ALL tests pass. If any fail, fix before proceeding — do not leave a red suite.

- [ ] **Step 2: Lint (if configured)**

Run: `cd frontend && npm run lint`
Expected: no new errors. (If the project has no `lint` script, skip and note it.)

- [ ] **Step 3: Manual smoke test of the form**

Start the app per the project's run instructions and confirm:
- Heading reads "Submit Job" with a "* Required fields" legend.
- Default Input Type = "Output from CCVA", Output Type shows a locked "Cause Distribution".
- Switching Input Type to "Individual VA Records" reveals an Output Type dropdown with "Individual Top Cause of Death" and "Cause Distribution".
- Algorithm lists read EAVA, InSilicoVA, InterVA with no timing text.
- The uncertainty block has a "Uncertainty in CCVA misclassification" title above a "Propagate" checkbox.
- The "Upload VA Data" label shows, with the vacalibration example-code link below it.
- "MCMC Specifics" matches the other input titles in font.
- Job Detail and Job List timestamps show a timezone label (e.g. "EDT").

- [ ] **Step 4: Confirm backend untouched**

Run: `git status --short backend/`
Expected: no output (no backend changes).

---

## Self-Review (completed during planning)

- **Spec coverage:** Items #1 (Task 4 4a), #2 (Task 4 4c–4h, 4j), #3 (Task 6 S1), #4 (Task 4 asterisks + legend), #5 (Tasks 2 & 5), #6 (Task 4 4j), #7 (Tasks 1 & 3), #8 (Task 4 4i), #9 (Task 4 4j). All ten items mapped.
- **Resolved decisions honored:** default landing state = `vacalibration` (Task 3 4b); example link = `github.com/sandy-pramanik/vacalibration` (Task 4 4j).
- **Test migration:** the issue #68 / #26 assertions that conflict with the new strings are migrated in Task 4 Step 2; the field-order and uncertainty-helper behavior tests in Task 3 Step 1 and Task 4 Step 2c.
- **Type/name consistency:** `deriveJobType`, `outputTypeOptions`, `jobTypeToSelectors`, `INPUT_TYPES`, `formatTimestamp`, `parseTimestamp` are used with identical signatures across tasks.
- **No backend changes:** verified by Task 7 Step 4.
