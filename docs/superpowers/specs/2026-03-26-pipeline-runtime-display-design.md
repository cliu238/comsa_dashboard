# Fix: Inconsistent Runtime Displays in Pipeline Analyses

**Issue**: #47
**Date**: 2026-03-26
**Approach**: Frontend-only (Approach A) — rewrite `parseProgress()` to be phase-aware using existing backend log markers. No backend changes.

## Problem

Pipeline jobs run multiple sequential phases (openVA per algorithm → vacalibration), but the progress system only tracks the current phase's percentage. This causes:

1. **Progress bar jumps backwards** when transitioning between phases (e.g., InterVA at 80% → InSilicoVA at 5%)
2. **No overall progress** — users can't tell how far along the entire pipeline is
3. **Regex ordering bug** — vacalibration-only jobs show incorrect progress because the InSilicoVA `Iteration: X` regex fires before the Stan `Iteration: X / Y` regex

### Scope by Job Type

| Job type | Issue | Fix |
|----------|-------|-----|
| openva-only | None | No changes |
| vacalibration-only | Regex ordering bug — wrong pattern matches | Fix regex priority |
| pipeline | No phase awareness, progress jumps | Phase-aware parsing + segmented display |

## Design

### 1. Phase-Aware Progress Parser (`frontend/src/utils/progress.js`)

Rewrite `parseProgress()` to detect pipeline phases from existing backend log markers.

**Existing backend markers** (no changes needed):
- `=== Step 1: openVA ===` — openVA phase start
- `Running openVA: <algo>` — per-algorithm start within openVA
- `openVA <algo> complete: N causes assigned` — per-algorithm completion
- `=== Step 3: vacalibration ===` — calibration phase start
- `Calibration complete` — calibration done

**New return structure** (superset of current):

```js
{
  percentage: 45,              // overall pipeline progress (0-100)
  stage: 'openVA (2/3): InSilicoVA 60%',  // human-readable status
  phase: 'openva',             // 'openva' | 'calibration' | 'loading' | null
  subPhase: 'InSilicoVA',     // current algorithm name (openva phase only)
  phaseProgress: 60,          // progress within current phase (0-100)
}
```

Non-pipeline jobs continue returning `{ percentage, stage }` with `phase`, `subPhase`, `phaseProgress` as `null`.

**Detection logic**:
1. Check for `=== Step` markers → pipeline job
2. If pipeline: scan `Running openVA: <algo>` entries to count total algorithms and identify current one
3. Scan `openVA <algo> complete` entries to count completed algorithms
4. Parse algorithm-specific progress (InterVA %, InSilicoVA iterations, Stan iterations)
5. Compute overall percentage from dynamic weights

**Overall percentage calculation (dynamic weights)**:
- Pipeline with N algorithms + calibration: each segment gets `1 / (N + 1)` weight
- Example: 2-algo ensemble → algo1 = 33%, algo2 = 33%, calibration = 33%
- Single-algo pipeline → algo = 50%, calibration = 50%
- Current phase progress fills only its segment of the overall bar

**Regex ordering fix**:
Move the Stan/vacalibration pattern (`Iteration: X / Y` with slash) BEFORE the InSilicoVA pattern (`Iteration: X` without slash). This fixes the dead-code bug where the InSilicoVA regex swallows Stan iterations, affecting both vacalibration-only and pipeline jobs.

### 2. Updated ProgressIndicator Component (`frontend/src/components/ProgressIndicator.jsx`)

**Full mode (JobDetail)** — pipeline jobs get a segmented display:

```
Phase 1/2: openVA (2/3) — InSilicoVA 60%     2m 15s
[████████|██████|▓▓▓      |              |          ]
 algo1    algo2   algo3     calibration
Overall: 45%
```

- Progress bar has visual segment dividers (CSS borders or subtle color variations)
- Completed segments: fully filled
- Active segment: partially filled
- Future segments: empty/gray
- Stage text: `Phase X/Y: <phase> (<algo M/N>) — <algo> <pct>%`
- Elapsed time: top-right (unchanged)
- Overall percentage: below bar

**Compact mode (JobList)**: Show only the overall percentage in the mini bar — no segmentation.

**Non-pipeline jobs**: No visual changes — simple progress bar as today.

### 3. Files Changed

| File | Change |
|------|--------|
| `frontend/src/utils/progress.js` | Rewrite `parseProgress()` with phase detection, fix regex ordering |
| `frontend/src/components/ProgressIndicator.jsx` | Add segmented bar rendering for pipeline jobs |
| `frontend/src/components/ProgressIndicator.css` (or equivalent styles) | Styles for segmented progress bar |
| `frontend/src/utils/progress.test.js` | New tests for phase-aware parsing |

### 4. Testing Strategy

**Unit tests** (`progress.test.js`):
- Pipeline log sequences: single-algo, 2-algo ensemble, 3-algo ensemble
- Phase transitions: logs containing both openVA and calibration markers
- Overall percentage at various points (mid-algo-1, between algos, mid-calibration)
- Backward compatibility: non-pipeline logs produce same results as before
- Regex ordering: vacalibration `Iteration: X / Y` correctly matched (not swallowed by InSilicoVA regex)
- Edge cases: empty logs, only phase markers (no iteration data), partial logs

**Component tests** (ProgressIndicator):
- Renders segmented bar when pipeline progress data present
- Renders simple bar for non-pipeline data
- Compact mode shows only overall percentage

No backend tests needed — no backend changes.

### 5. Edge Cases

1. **No logs yet**: Indeterminate spinner (same as today)
2. **Phase marker but no algorithm progress**: Show `"Phase 1/2: openVA — Starting..."` with no percentage
3. **Algorithm completes instantly**: Phase weight still counts; segment goes 0→100% quickly
4. **Single-algorithm pipeline**: 2 segments (algo + calibration), 50/50 weight
5. **Non-pipeline jobs**: Zero changes — falls back to current behavior when no `=== Step ===` markers found

### 6. What Does NOT Change

- Backend code (R plumber, processor, algorithms)
- API endpoints or response shapes
- Database schema
- `getElapsedTime()` function
- Compact mode visual complexity
- Non-pipeline job behavior
