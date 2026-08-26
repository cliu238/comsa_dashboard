---
phase: quick/260826-fps-fix-issue-130
plan: 01
subsystem: ui
tags: [react, csmf-table, view-model, vitest]

requires: []
provides:
  - "Adaptive-precision pct() formatter in CSMFChart.js so a real sub-1% credible
    interval is never displayed identically to a genuine point mass"
affects: [csmf-comparison-table, csmf-csv-export]

tech-stack:
  added: []
  patterns:
    - "Single string-returning formatter (pct) shared by mean and both bounds so a
      point estimate can never render outside its own printed interval (D-03)"

key-files:
  created:
    - .planning/quick/260826-fps-fix-issue-130/deferred-items.md
  modified:
    - frontend/src/components/CSMFChart.js
    - frontend/src/components/CSMFChart.test.js
    - frontend/src/utils/export.test.js

key-decisions:
  - "pct() return type changed from number|null to string|null; call sites and the
    raw-bounds degenerate/point-mass guard were left untouched (D-01, D-06)"
  - "Precision only becomes adaptive below 1% (p<1); at or above 1% output is
    byte-identical to the old Math.round(p), so ordinary values gain no decimals (D-02)"
  - "A non-zero value below 0.01% displays as '<0.01' instead of an unqualified '0' (D-02)"

patterns-established:
  - "issue #130 comment banner above pct() documents the fix without using any
    retracted-phrase substring the CSMFChart.test.js retraction guard scans for"

requirements-completed: ["#130"]

duration: 25min
completed: 2026-08-26
---

# Quick Task: Fix #130 CSMF Table False Precision Summary

**Adaptive-precision `pct()` formatter in CSMFChart.js so a real sub-1% credible interval (e.g. lower=0, upper=0.0049) prints as `0.21% (0-0.49)` instead of the false-precision `0% (0-0)` that looked identical to a genuine point mass.**

## Performance

- **Duration:** ~25 min
- **Started:** 2026-08-26 (worktree spawned at base commit `5815dca`)
- **Completed:** 2026-08-26T15:33:26Z
- **Tasks:** 2/2 completed
- **Files modified:** 3 (2 test files, 1 production file), plus 1 new deferred-items log

## Accomplishments
- `pct()` in `CSMFChart.js` now applies an adaptive precision rule: exact zero stays
  `'0'`; values at or above 1% still round to a bare integer string (byte-identical to
  the old behavior); a non-zero value below 0.01% discloses as `'<0.01'`; everything else
  in between renders to two decimal places.
- The mean and both bounds share this one rule (D-03), so a point estimate can never
  print outside its own printed credible interval.
- The CSV export (`exportConsolidatedCSMF`) inherits the fix with zero code change,
  because it interpolates `cell.mean/lower/upper` verbatim.
- Ten pre-existing `buildCsmfTableRows` assertions were restated from `toBe(20)` to
  `toBe('20')` (values unchanged, type changed) to match the new string return type.
- The retraction guard (issue #101, R2) and every do-not-touch invariant (`csmfWhisker`,
  the raw-bounds `degenerate` guard, `JobDetail.jsx`, `export.js`, the backend payload)
  remain untouched and passing.

## Task Commits

Each task was committed atomically:

1. **Task 1: Write the failing #130 tests and restate the existing assertions as strings** - `608d230` (test)
2. **Task 2: Make pct() adaptive so sub-1% values keep their precision** - `c9c43ec` (feat)

**Plan metadata:** this SUMMARY.md commit (docs)

## Files Created/Modified
- `frontend/src/components/CSMFChart.js` - `pct()` rewritten to the adaptive D-02 rule;
  JSDoc on `buildCsmfTableRows` updated to describe the new string-typed output
- `frontend/src/components/CSMFChart.test.js` - new `describe('adaptive precision below
  1% (issue #130)')` block (7 tests) plus 10 restated numeric-to-string assertions and one
  renamed test title
- `frontend/src/utils/export.test.js` - new `describe('exportConsolidatedCSMF (issue
  #130)')` block asserting the CSV cell for the same case is `"0.21 (0, 0.49)"`, never
  `"0 (0, 0)"`
- `.planning/quick/260826-fps-fix-issue-130/deferred-items.md` - logs a pre-existing,
  out-of-scope `integration.test.js` failure discovered while verifying this plan

## Decisions Made
- Followed the plan's D-01 through D-06 decisions exactly: one formatter (not two), the
  five-step adaptive rule in the specified order, mean shares the bounds' rule, string
  return type throughout, CSV keeps its current one-cell format, `JobDetail.jsx`/
  `export.js` not touched.
- Comment above `pct()` was worded to avoid every retraction-guard forbidden substring
  (in particular "false precision", never "falsely") and, on a second pass, to avoid the
  literal string "Math.round" in prose so the acceptance grep (`exactly one hit, inside
  pct`) stays satisfied -- the code itself is the only "Math.round" match.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Symlinked `frontend/node_modules` from the main repo into the worktree**
- **Found during:** Task 1 verification
- **Issue:** The worktree checkout has no `frontend/node_modules`, so `npx vitest` failed
  at startup with `ERR_MODULE_NOT_FOUND` for `vite`/`@vitejs/plugin-react`.
- **Fix:** Confirmed `frontend/package.json` and `package-lock.json` are byte-identical
  between the main repo and the worktree, then symlinked
  `frontend/node_modules -> ../../../frontend/node_modules` (gitignored; no commit needed,
  confirmed via `git status`).
- **Files modified:** none tracked (symlink only, outside git).
- **Verification:** `npx vitest run ...` and `npm test`/`npm run build`/`npm run lint`
  all ran successfully afterward.

**2. [Comment-wording self-correction] Removed literal "Math.round" text from the new pct() comment**
- **Found during:** Task 2 acceptance-criteria check
- **Issue:** The acceptance criteria require `grep -n "Math.round" CSMFChart.js` to return
  exactly one hit (inside `pct`). My first draft comment mentioned "Math.round" twice in
  prose, producing three hits.
- **Fix:** Reworded the comment to describe the old behavior as "rounding straight to the
  nearest whole percent" instead of naming the function, with no change to behavior or
  to the retraction-guard-forbidden phrases.
- **Files modified:** `frontend/src/components/CSMFChart.js`
- **Verification:** `grep -n "Math.round" frontend/src/components/CSMFChart.js` now
  returns exactly one line; full test suite and retraction guard both still pass.
- **Committed in:** `c9c43ec` (part of Task 2 commit)

---

**Total deviations:** 2 (1 blocking/environment fix, 1 self-caught acceptance-criteria
correction before commit)
**Impact on plan:** Neither changes behavior or scope; both were needed to execute and
verify the plan as written.

## Issues Encountered

- **Worktree HEAD was one commit behind the plan's expected base commit.** The
  `<worktree_branch_check>` found `git merge-base HEAD 5815dca` returned an ancestor
  commit, not `5815dca` itself; `5815dca` was confirmed to be a fast-forward descendant
  of the worktree's starting HEAD, so `git reset --hard 5815dca` was a safe fast-forward,
  not a destructive rewrite. Resolved before any task work began.
- **`frontend/src/api/integration.test.js` fails on `/jobs` and `/jobs/demo` (pre-existing,
  unrelated to this plan).** Root-caused by manually starting the worktree's backend and
  curling `/jobs` directly: it returns `401 {"error":["Missing or invalid Authorization
  header"]}`. This is because the user-auth system (added in an earlier phase) now
  protects `/jobs*`, and `integration.test.js` was never updated to send a JWT. Confirmed
  via `git stash` that this failure is identical before and after this plan's changes
  (Task 2 touches only `CSMFChart.js`, nothing backend- or auth-related). Logged to
  `deferred-items.md`, not fixed, per the executor's scope boundary.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- Issue #130 is resolved: the CSMF comparison table and its CSV export now disclose
  real sub-1% credible intervals instead of rounding them to a false `0`.
- `frontend/src/api/integration.test.js`'s `/jobs` and `/jobs/demo` auth failures remain
  open (see `deferred-items.md`) and should be picked up by a future auth-focused plan;
  they do not block this fix.

---
*Phase: quick/260826-fps-fix-issue-130*
*Completed: 2026-08-26*

## Self-Check: PASSED

- FOUND: frontend/src/components/CSMFChart.js
- FOUND: frontend/src/components/CSMFChart.test.js
- FOUND: frontend/src/utils/export.test.js
- FOUND: .planning/quick/260826-fps-fix-issue-130/deferred-items.md
- FOUND: .planning/quick/260826-fps-fix-issue-130/SUMMARY.md
- FOUND commit: 608d230 (test(quick-130): add failing tests for adaptive sub-1% CSMF precision)
- FOUND commit: c9c43ec (feat(quick-130): make pct() adaptive so sub-1% CSMF values keep precision)
