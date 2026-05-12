# Calibration-Only Mode: Algorithms-First Flow Redesign

**Date:** 2026-05-12
**Scope:** `frontend/src/components/JobForm.jsx` — Calibration Only mode UX only
**Status:** Design approved; ready for implementation plan

## Problem

In Calibration Only mode the user picks **Ensemble Mode** first, then algorithms.
The picker swaps between a single dropdown (ensemble OFF) and multi-select
checkboxes (ensemble ON). This treats "ensemble" as a *mode switch*.

The `vacalibration` R package treats ensemble as an *additional output*: pass it
2+ algorithms with `ensemble = TRUE` and you get per-algorithm calibration rows
**plus** an extra `"ensemble"` row in `pcalib_postsumm`. The backend already
auto-derives `ensemble_val` from algorithm count
(`backend/jobs/algorithms/vacalibration.R:18-19`); only the frontend forces the
inverted order.

## Goal

Flip the Calibration Only UI to algorithms-first:

1. User picks 1+ algorithms (always multi-select checkboxes).
2. If 2+ are picked, an **"Also run ensemble"** option appears and is checked
   by default.
3. Submit runs per-algorithm calibration for every selected algorithm, plus the
   ensemble combined result when the option is checked.

This matches the package's mental model and removes the dropdown/checkbox swap.

## Out of Scope

- Pipeline mode UI (keeps current ensemble-first checkbox flow).
- openVA-only mode UI.
- Backend code (`vacalibration.R`, `processor.R`, API endpoints) — no changes.
- `api/client.js` submit payload shape — unchanged.
- Result display in `JobDetail.jsx`.
- Sample CSV files in `frontend/public/`.

## UI Layout (Calibration Only)

```
Job Type:  [ Calibration Only            ▾ ]

Algorithms *
  ☑ InterVA      (fastest, ~30sec)
  ☐ InSilicoVA   (most accurate, ~2-3min)
  ☐ EAVA         (deterministic, ~1min)

  ── when 1 algorithm selected ──
  ☐ Also run ensemble  (disabled — requires 2+ algorithms)

  ── when 2+ algorithms selected ──
  ☑ Also run ensemble (combines algorithms)
    Runs per-algorithm calibration + an additional combined ensemble result.

Age Group:  [ Neonate (0-27 days)        ▾ ]
Country:    [ Mozambique                 ▾ ]
Propagate uncertainty: [ Yes (prior)     ▾ ]
▸ Advanced MCMC Settings

VA Data Files (one CSV per selected algorithm)
  InterVA      [ Choose file ]
  InSilicoVA   [ Choose file ]   ← shown only if checked
  EAVA         [ Choose file ]   ← shown only if checked

[ Calibrate ]    [ Run Demo ]
```

### Changes vs. current

| Today | New |
|-------|-----|
| Ensemble checkbox → algorithm picker | Algorithm picker → ensemble checkbox |
| Picker swaps dropdown ↔ checkboxes | Picker is always checkboxes |
| Upload section toggles between single/multi | One labeled upload row per selected algorithm, always |
| Ensemble checkbox always visible | Ensemble row always visible but **disabled when <2 algorithms** |
| Default: InterVA only, ensemble OFF | Default: InterVA only, ensemble row visible-disabled |

### Removed UI states

- Single "VA Data File" branch (`JobForm.jsx:419-453`) — gone for calibration-only.
- Dropdown picker (`JobForm.jsx:274-284`) — gone for calibration-only.
- File-algorithm-mismatch hint (`JobForm.jsx:232-238`) — removed; per-algorithm
  upload labels make it self-evident.

## State Model

Reuse existing state variables — no new ones.

```
algorithms : string[]    // e.g. ['InterVA'] or ['InterVA', 'EAVA']
ensemble   : boolean     // checked state of "Also run ensemble"
uploads    : Upload[]    // [{ id, algorithm, file }, ...]

Derived:
  canEnsemble       = algorithms.length >= 2
  ensembleEffective = canEnsemble && ensemble   // sent to backend
  allFilesProvided  = uploads.every(u => u.file)
```

### Effects

**A. Sync uploads to algorithms (calibration-only mode):**

```
uploads = algorithms.map(algo =>
  existing-row-with-same-algorithm || new row { algorithm: algo, file: null }
)
```

Preserves files for unchanged algorithms; adds rows for newly-checked algorithms;
drops rows for unchecked ones.

**B. Auto-enable ensemble on 1 → 2+ crossing:**

If `algorithms.length` transitions from 1 to ≥2 AND the user has not explicitly
unchecked ensemble in this session, set `ensemble = true`.

A session-scoped sentinel (e.g. `ensembleUserTouched`) tracks whether the user
clicked the ensemble checkbox. Sticky-uncheck means: user unchecks ensemble →
drops to 1 algo → re-adds 2nd algo → ensemble stays unchecked.

**C. Validation:**

```
algorithms.length === 0          → "Select at least one algorithm"
uploads.some(u => !u.file)       → "Upload a file for each selected algorithm"
                                    (or rely on submit-button disabled state)
```

No ensemble-specific validation — `canEnsemble` is derived; can't be invalid.

### Submit payload (unchanged shape)

```javascript
{
  jobType: 'vacalibration',
  algorithms,                          // e.g. ['InterVA', 'EAVA']
  ensemble: canEnsemble && ensemble,   // boolean — backend already handles this
  ageGroup, country, calibModelType,
  nMCMC, nBurn, nThin,
  uploads                              // [{ algorithm, file }, ...]
}
```

## Validation Rules

| Condition | Inline message | Submit disabled? |
|-----------|----------------|------------------|
| `algorithms.length === 0` | "Please select at least one algorithm" | ✓ |
| 1 algo, no file | none | ✓ |
| ≥2 algos, any missing file | "Upload a file for each selected algorithm" | ✓ |
| 1 algo, ensemble disabled | hint: "Requires 2+ algorithms" | — |
| All ok | none | ✗ |

## Edge Cases

1. **Unchecking all algorithms.** Existing guard in `handleAlgorithmToggle`
   (`JobForm.jsx:97-98`) prevents empty array. Keep.

2. **Removing a middle algorithm.** Other algorithms' files must be preserved.
   The keyed lookup in Effect A (`existing = prev.find(u => u.algorithm === algo)`)
   already handles this. Keep.

3. **Run Demo respects checkbox selection.** Demo loads sample data only for
   currently-checked algorithms. Backend supports this — `vacalibration.R:39-45`
   iterates `algo_names` and calls `load_vacalibration_sample(algo, ...)` per
   selected algorithm.

4. **Switching job type away and back.** State persists when toggling
   `jobType`. Only rendering branches on `jobType`. Current behavior preserved.

5. **File-algorithm hint banner.** Removed (no longer needed with per-algorithm
   upload labels).

6. **Pipeline mode untouched.** The conditional in `JobForm.jsx:218` splits:

   ```jsx
   {jobType === 'pipeline' && (
     // existing ensemble-first checkbox UI (unchanged)
   )}
   {jobType === 'vacalibration' && (
     // new algorithms-first UI
   )}
   ```

## Backend Compatibility

**No backend changes.** `vacalibration.R:11-23` already:

- Reads `algo_names` from the job payload.
- Derives `ensemble_val` from algorithm count when not explicitly set.
- Forces `ensemble_val = FALSE` if only 1 algorithm is present.
- Loads sample data per algorithm in the demo path (lines 39-45).
- Routes uploaded files by filename (`input_<algo>.csv`) in the upload path
  (lines 47-91).

The frontend's `canEnsemble && ensemble` gate is defense-in-depth — even if the
client sends `ensemble: true` with 1 algorithm, the backend safely downgrades to
single-algo and logs a warning.

## Testing Plan

| Test type | Location | What to change |
|-----------|----------|----------------|
| Unit (vitest) | `frontend/src/components/JobForm.test.js` | Add 4 cases: ensemble row hidden→disabled→enabled as algos toggle; auto-enable on 1→2 crossing; sticky-uncheck preserved; upload rows match selected algorithms 1:1 |
| Unit (vitest) | `frontend/src/components/JobForm.test.js` | Update existing assertions that depended on ensemble-first ordering |
| R backend | `tests/test_vacalibration_backend.R` | No changes — backend behavior unchanged |
| E2E (Playwright) | `frontend/e2e/demo-gallery.spec.js` | Verify Demo flow still works; selector updates for algorithm checkboxes likely |

## Risk Assessment

- **Backend contract:** unchanged → near-zero backend risk.
- **Client state surface:** the synchronization between `algorithms`,
  `ensemble`, and `uploads` is where bugs will hide. Vitest cases focus on
  transitions (1→2 algos, uncheck-then-recheck), not just static snapshots.
- **Pipeline mode regression:** mitigated by the explicit `jobType` split — the
  new branch only renders when `jobType === 'vacalibration'`.

## Acceptance Criteria

1. With Calibration Only selected and 1 algorithm checked: ensemble row visible
   but disabled with hint "Requires 2+ algorithms"; one labeled upload row
   visible.
2. Checking a 2nd algorithm: ensemble row auto-enables with checkbox checked;
   a 2nd labeled upload row appears.
3. Unchecking ensemble, then unchecking the 2nd algorithm, then re-checking it:
   ensemble row enables but checkbox remains unchecked (sticky behavior).
4. Demo button with N algorithms checked: loads sample data for exactly those N
   algorithms; ensemble row included in result iff ensemble checkbox is checked
   and N ≥ 2.
5. Pipeline mode and openVA Only mode behave identically to today.
6. Existing vitest suite passes; new vitest cases pass; E2E demo-gallery passes.
