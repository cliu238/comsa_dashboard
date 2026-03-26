# Pipeline Runtime Display Fix Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix inconsistent runtime displays in pipeline analyses by making `parseProgress()` phase-aware and adding a segmented progress bar for pipeline jobs.

**Architecture:** Frontend-only changes. Rewrite `parseProgress()` to detect pipeline phase markers from existing backend logs, compute overall pipeline progress with dynamic weights, and fix the regex ordering bug. Update `ProgressIndicator` to render a segmented bar for pipeline jobs.

**Tech Stack:** React, Vitest, CSS

**Spec:** `docs/superpowers/specs/2026-03-26-pipeline-runtime-display-design.md`

---

### Task 1: Fix regex ordering bug in parseProgress

**Files:**
- Modify: `frontend/src/utils/progress.js:18-38`
- Modify: `frontend/src/utils/progress.test.js:43-50`

This fixes the dead-code bug where `Iteration: X / Y` (Stan/vacalibration) is swallowed by the InSilicoVA `Iteration: X` regex. Move Stan check before InSilicoVA check.

- [ ] **Step 1: Update the existing test to expect correct Stan behavior**

In `frontend/src/utils/progress.test.js`, replace the test at lines 43-50:

```js
it('parses Stan/vacalibration iteration fraction correctly', () => {
  // With regex fix, "Iteration: X / Y" (with slash) matches Stan, not InSilicoVA
  const result = parseProgress(['Chain 1 Iteration: 2500 / 5000']);
  expect(result.percentage).toBe(50); // 2500/5000
  expect(result.stage).toBe('Calibration: 50%');
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && npx vitest run src/utils/progress.test.js`
Expected: FAIL — still returns `InSilicoVA: 63%` instead of `Calibration: 50%`

- [ ] **Step 3: Fix regex ordering in parseProgress**

In `frontend/src/utils/progress.js`, swap the order: move the Stan/vacalibration block (lines 29-38) BEFORE the InSilicoVA block (lines 18-27). The new order after the InterVA block:

```js
// Stan/vacalibration: "Chain X Iteration: 2500 / 5000" or "Iteration: X / Y"
// MUST check before InSilicoVA — both match "Iteration:" but Stan has " / total"
const stanMatch = logText.match(/Iteration:\s*(\d+)\s*\/\s*(\d+)/g);
if (stanMatch) {
  const lastMatch = stanMatch[stanMatch.length - 1];
  const nums = lastMatch.match(/(\d+)\s*\/\s*(\d+)/);
  if (nums) {
    const pct = Math.min(Math.round((parseInt(nums[1]) / parseInt(nums[2])) * 100), 99);
    return { percentage: pct, stage: `Calibration: ${pct}%` };
  }
}

// InSilicoVA: "Iteration: 2000" with total iterations (typically 4000)
const totalMatch = logText.match(/(\d+) Iterations to Sample/i);
const iterMatch = logText.match(/Iteration:\s*(\d+)/g);
if (iterMatch) {
  const total = totalMatch ? parseInt(totalMatch[1]) : 4000;
  const lastIter = iterMatch[iterMatch.length - 1];
  const current = parseInt(lastIter.match(/(\d+)/)[1]);
  const pct = Math.min(Math.round((current / total) * 100), 99);
  return { percentage: pct, stage: `InSilicoVA: ${pct}%` };
}
```

- [ ] **Step 4: Run tests to verify all pass**

Run: `cd frontend && npx vitest run src/utils/progress.test.js`
Expected: ALL PASS (20 assertions)

- [ ] **Step 5: Add test for mixed Stan + InSilicoVA logs**

Add to the `parseProgress` describe block:

```js
it('distinguishes InSilicoVA (bare) from Stan (with slash) iterations', () => {
  // Pure InSilicoVA (no slash) — should still match InSilicoVA
  const insilico = parseProgress(['Iteration: 2000']);
  expect(insilico.stage).toBe('InSilicoVA: 50%');

  // Stan with slash — should match Calibration
  const stan = parseProgress(['Iteration: 2500 / 5000']);
  expect(stan.stage).toBe('Calibration: 50%');
});
```

- [ ] **Step 6: Run tests**

Run: `cd frontend && npx vitest run src/utils/progress.test.js`
Expected: ALL PASS

- [ ] **Step 7: Commit**

```bash
git add frontend/src/utils/progress.js frontend/src/utils/progress.test.js
git commit -m "fix: correct regex ordering so Stan/vacalibration iterations are not swallowed by InSilicoVA (#47)"
```

---

### Task 2: Add pipeline phase detection to parseProgress

**Files:**
- Modify: `frontend/src/utils/progress.js`
- Modify: `frontend/src/utils/progress.test.js`

Extract a new `parsePipelineProgress()` function that detects `=== Step ===` markers, identifies the current phase/algorithm, and computes overall percentage.

- [ ] **Step 1: Write failing tests for pipeline phase detection**

Add a new `describe('parseProgress - pipeline jobs')` block in `progress.test.js`:

```js
describe('parseProgress - pipeline jobs', () => {
  it('detects openVA phase with single algorithm', () => {
    const logs = [
      'Starting pipeline: openVA -> vacalibration',
      '=== Step 1: openVA ===',
      'Running openVA: InterVA',
      '..........60% completed',
    ];
    const result = parseProgress(logs);
    expect(result.phase).toBe('openva');
    expect(result.subPhase).toBe('InterVA');
    expect(result.phaseProgress).toBe(60);
    // Single algo pipeline: openVA=50%, calibration=50%. At 60% of openVA = 30% overall
    expect(result.percentage).toBe(30);
    expect(result.stage).toContain('openVA');
    expect(result.stage).toContain('InterVA');
    expect(result.stage).toContain('60%');
  });

  it('detects openVA phase in 2-algo ensemble', () => {
    const logs = [
      '=== Step 1: openVA ===',
      'Running openVA: InterVA',
      'openVA InterVA complete: 100 causes assigned',
      'Running openVA: InSilicoVA',
      'Iteration: 2000',
    ];
    const result = parseProgress(logs);
    expect(result.phase).toBe('openva');
    expect(result.subPhase).toBe('InSilicoVA');
    expect(result.phaseProgress).toBe(50);
    // 2 algos + calib = 3 segments. Algo1 done (33%) + algo2 at 50% of 33% = 33+17 = 50%
    expect(result.percentage).toBe(50);
    expect(result.stage).toContain('2/2');
  });

  it('detects calibration phase in pipeline', () => {
    const logs = [
      '=== Step 1: openVA ===',
      'Running openVA: InterVA',
      'openVA InterVA complete: 100 causes assigned',
      '=== Step 3: vacalibration ===',
      'Chain 1 Iteration: 2500 / 5000',
    ];
    const result = parseProgress(logs);
    expect(result.phase).toBe('calibration');
    expect(result.phaseProgress).toBe(50);
    // Single algo pipeline: openVA done (50%) + calibration at 50% of 50% = 75%
    expect(result.percentage).toBe(75);
    expect(result.stage).toContain('Calibration');
  });

  it('shows 3-algo ensemble overall progress in calibration phase', () => {
    const logs = [
      '=== Step 1: openVA ===',
      'Running openVA: InterVA',
      'openVA InterVA complete: 100 causes assigned',
      'Running openVA: InSilicoVA',
      'openVA InSilicoVA complete: 100 causes assigned',
      'Running openVA: EAVA',
      'openVA EAVA complete: 100 causes assigned',
      '=== Step 3: vacalibration ===',
      'Chain 1 Iteration: 2500 / 5000',
    ];
    const result = parseProgress(logs);
    // 3 algos + calib = 4 segments, each 25%. All 3 algos done (75%) + calib at 50% of 25% = 88%
    expect(result.percentage).toBe(88);
  });

  it('returns null phase for non-pipeline logs', () => {
    const result = parseProgress(['..........60% completed']);
    expect(result.phase).toBeNull();
    expect(result.subPhase).toBeNull();
    expect(result.phaseProgress).toBeNull();
  });

  it('handles pipeline with phase marker but no progress yet', () => {
    const logs = [
      '=== Step 1: openVA ===',
      'Running openVA: InterVA',
    ];
    const result = parseProgress(logs);
    expect(result.phase).toBe('openva');
    expect(result.subPhase).toBe('InterVA');
    expect(result.phaseProgress).toBeNull();
    expect(result.percentage).toBeNull();
    expect(result.stage).toContain('openVA');
    expect(result.stage).toContain('Starting');
  });
});
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd frontend && npx vitest run src/utils/progress.test.js`
Expected: FAIL — `phase`, `subPhase`, `phaseProgress` are undefined

- [ ] **Step 3: Implement pipeline phase detection in parseProgress**

Rewrite `parseProgress()` in `frontend/src/utils/progress.js`. The function should:

1. Check if logs contain `=== Step` markers → pipeline job
2. If pipeline: call a new internal `parsePipelineProgress(logs)` function
3. If not pipeline: run existing logic (with regex fix from Task 1), adding `phase: null, subPhase: null, phaseProgress: null` to the return

`parsePipelineProgress(logs)` logic:
- Detect current phase: scan for last `=== Step` marker
  - `=== Step 1: openVA ===` → phase is `'openva'`
  - `=== Step 3: vacalibration ===` → phase is `'calibration'`
- Count algorithms: count `Running openVA: <algo>` OR `Running algorithm: <algo>` entries (total) and `openVA <algo> complete:` entries (completed). Both patterns appear in real logs — `processor.R` emits `Running openVA: <algo>` but older jobs or wrapped contexts may emit `Running algorithm: <algo>`. Match both with a single regex: `/Running (?:openVA|algorithm):\s*(\w+)/g`
- Identify current algorithm: last match from the above regex
- **Important**: Completed algorithms count as 100% of their segment even if no explicit progress lines (e.g., `% completed`) were logged for them. The `openVA <algo> complete:` marker is the authoritative signal.
- Parse current phase progress using existing regex patterns (InterVA %, InSilicoVA iterations, Stan iterations)
- Compute overall percentage:
  - `totalSegments = totalAlgorithms + 1` (algos + calibration)
  - `segmentWeight = 1 / totalSegments`
  - `completedWeight = completedAlgorithms * segmentWeight`
  - If in openva phase: `overall = (completedWeight + (phaseProgress/100) * segmentWeight) * 100`
  - If in calibration phase: `overall = (totalAlgorithms * segmentWeight + (phaseProgress/100) * segmentWeight) * 100`
- Build stage string:
  - openva: `Phase 1/2: openVA (M/N) — <algo> <pct>%`
  - calibration: `Phase 2/2: Calibration <pct>%`
- Return `{ percentage, stage, phase, subPhase, phaseProgress }`

For non-pipeline returns, add the three new null fields to maintain backward compatibility:

```js
return { percentage: pct, stage: `InterVA: ${pct}%`, phase: null, subPhase: null, phaseProgress: null };
```

- [ ] **Step 4: Run tests**

Run: `cd frontend && npx vitest run src/utils/progress.test.js`
Expected: ALL PASS

- [ ] **Step 5: Verify backward compatibility — run all existing tests**

Run: `cd frontend && npx vitest run src/utils/progress.test.js`
Expected: ALL original tests still pass (the added `phase: null` fields don't break existing `toEqual` checks because they weren't checking those fields)

Note: Existing tests use `result.percentage` and `result.stage` — they don't destructure or `toEqual` the full object except for 4 places that use `toEqual`. Update ALL of them to include the new null fields:

- Line 6: `expect(parseProgress(null)).toEqual({ percentage: null, stage: null, phase: null, subPhase: null, phaseProgress: null })`
- Line 7: `expect(parseProgress([])).toEqual({ percentage: null, stage: null, phase: null, subPhase: null, phaseProgress: null })`
- Line 8: `expect(parseProgress(undefined)).toEqual({ percentage: null, stage: null, phase: null, subPhase: null, phaseProgress: null })`
- Line 97: `expect(result).toEqual({ percentage: null, stage: null, phase: null, subPhase: null, phaseProgress: null })`

- [ ] **Step 6: Commit**

```bash
git add frontend/src/utils/progress.js frontend/src/utils/progress.test.js
git commit -m "feat: add pipeline phase detection to parseProgress (#47)"
```

---

### Task 3: Update ProgressIndicator and CSS for segmented pipeline display

**Files:**
- Modify: `frontend/src/components/ProgressIndicator.jsx`
- Create: `frontend/src/components/ProgressIndicator.test.jsx`
- Modify: `frontend/src/App.css` (after line ~1693)

- [ ] **Step 1: Write failing test for segmented rendering**

Create `frontend/src/components/ProgressIndicator.test.jsx`:

```jsx
import { describe, it, expect, vi } from 'vitest';
import { render, screen } from '@testing-library/react';
import ProgressIndicator from './ProgressIndicator';

// Mock progress utils
vi.mock('../utils/progress', () => ({
  parseProgress: vi.fn(),
  getElapsedTime: vi.fn(() => '2m 15s'),
}));

import { parseProgress } from '../utils/progress';

describe('ProgressIndicator', () => {
  it('renders segmented bar for pipeline jobs', () => {
    parseProgress.mockReturnValue({
      percentage: 50,
      stage: 'Phase 1/2: openVA (2/2) — InSilicoVA 50%',
      phase: 'openva',
      subPhase: 'InSilicoVA',
      phaseProgress: 50,
    });

    const { container } = render(
      <ProgressIndicator logs={['dummy']} startedAt="2024-01-01" />
    );

    expect(screen.getByText(/Phase 1\/2/)).toBeTruthy();
    expect(container.querySelector('.progress-segmented')).toBeTruthy();
    expect(screen.getByText(/50%/)).toBeTruthy();
  });

  it('renders simple bar for non-pipeline jobs', () => {
    parseProgress.mockReturnValue({
      percentage: 60,
      stage: 'InterVA: 60%',
      phase: null,
      subPhase: null,
      phaseProgress: null,
    });

    const { container } = render(
      <ProgressIndicator logs={['dummy']} startedAt="2024-01-01" />
    );

    expect(container.querySelector('.progress-bar')).toBeTruthy();
    expect(container.querySelector('.progress-segmented')).toBeNull();
  });

  it('renders compact mode with overall percentage only', () => {
    parseProgress.mockReturnValue({
      percentage: 45,
      stage: 'Phase 1/2: openVA (1/2) — InterVA 60%',
      phase: 'openva',
      subPhase: 'InterVA',
      phaseProgress: 60,
    });

    const { container } = render(
      <ProgressIndicator logs={['dummy']} startedAt="2024-01-01" compact={true} />
    );

    // Compact mode: no segmented bar
    expect(container.querySelector('.progress-segmented')).toBeNull();
    expect(container.querySelector('.progress-bar-mini')).toBeTruthy();
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd frontend && npx vitest run src/components/ProgressIndicator.test.jsx`
Expected: FAIL — no `.progress-segmented` element

- [ ] **Step 3: Update ProgressIndicator component**

Modify `frontend/src/components/ProgressIndicator.jsx` to handle the new fields:

```jsx
import { parseProgress, getElapsedTime } from '../utils/progress';

export default function ProgressIndicator({ logs, startedAt, compact = false }) {
  const { percentage, stage, phase, subPhase, phaseProgress } = parseProgress(logs);
  const elapsed = getElapsedTime(startedAt);
  const isPipeline = phase !== null;

  if (compact) {
    // Compact version for JobList — uses overall percentage, no segmentation
    return (
      <div className="progress-compact">
        {percentage !== null ? (
          <div className="progress-bar-mini">
            <div
              className="progress-fill"
              style={{ width: `${percentage}%` }}
            />
            <span className="progress-text">{percentage}%</span>
          </div>
        ) : (
          <span className="progress-spinner-mini" />
        )}
      </div>
    );
  }

  // Full version for JobDetail
  return (
    <div className="progress-indicator">
      <div className="progress-header">
        <span className="progress-stage">{stage || 'Processing...'}</span>
        {elapsed && <span className="progress-elapsed">{elapsed}</span>}
      </div>

      {isPipeline && percentage !== null ? (
        <div className="progress-segmented">
          <div
            className="progress-segmented-fill"
            style={{ width: `${percentage}%` }}
          />
        </div>
      ) : percentage !== null ? (
        <div className="progress-bar">
          <div
            className="progress-fill"
            style={{ width: `${percentage}%` }}
          />
        </div>
      ) : (
        <div className="progress-indeterminate">
          <div className="progress-indeterminate-bar" />
        </div>
      )}

      {percentage !== null && (
        <div className="progress-percentage">Overall: {percentage}%</div>
      )}
    </div>
  );
}
```

- [ ] **Step 4: Run component tests**

Run: `cd frontend && npx vitest run src/components/ProgressIndicator.test.jsx`
Expected: ALL PASS

- [ ] **Step 5: Add segmented progress bar CSS**

Add after the `.progress-percentage` block (~line 1693) in `frontend/src/App.css`:

```css
/* Segmented progress bar for pipeline jobs */
.progress-segmented {
  height: 8px;
  background: #e2e8f0;
  border-radius: 4px;
  overflow: hidden;
  position: relative;
}

.progress-segmented-fill {
  height: 100%;
  background: linear-gradient(90deg, var(--color-accent), #4a90c2);
  border-radius: 4px;
  transition: width 0.5s ease;
}
```

- [ ] **Step 6: Run all frontend tests**

Run: `cd frontend && npx vitest run`
Expected: ALL PASS

- [ ] **Step 7: Commit**

```bash
git add frontend/src/components/ProgressIndicator.jsx frontend/src/components/ProgressIndicator.test.jsx frontend/src/App.css
git commit -m "feat: add segmented progress bar for pipeline jobs (#47)"
```

---

### Task 4: Final integration verification

**Files:** None (verification only)

- [ ] **Step 1: Run full frontend test suite**

Run: `cd frontend && npx vitest run`
Expected: ALL PASS — no regressions

- [ ] **Step 2: Verify non-pipeline jobs are unaffected**

Check that `parseProgress` returns `phase: null` for:
- InterVA-only logs
- InSilicoVA-only logs
- vacalibration-only logs (Stan iterations)

These are covered by existing tests updated in Task 2 Step 5.

- [ ] **Step 3: Final commit (if any cleanup needed)**

Only if integration revealed issues. Otherwise, all commits are already done.
