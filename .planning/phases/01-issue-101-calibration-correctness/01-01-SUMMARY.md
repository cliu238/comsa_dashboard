---
phase: 01-issue-101-calibration-correctness
plan: 01
subsystem: backend
tags: [r, vacalibration, plumber, react, calibration-correctness]

# Dependency graph
requires:
  - phase: 01-issue-101-calibration-correctness
    provides: "assemble_calibration_result() in backend/jobs/utils.R (plan 01-03), the single post-vacalibration() result assembler both job paths delegate to"
provides:
  - "zero_count_causes(), unobserved_causes(), build_donotcalib(), build_calibrated_map() in backend/jobs/utils.R"
  - "donotcalib = build_donotcalib(va_input) passed to vacalibration() from both run_vacalibration() and run_pipeline()"
  - "hidden_causes plumbed through assemble_calibration_result() (drops zero-death causes from every cause-keyed field/CSV without renormalizing) and hide_causes through extract_misclass_matrix()/.build_misclass_entry() (masks the matrix display without touching the package's own not_calibrated footnote)"
  - "calibration_declined field on build_stall_fields(), strictly separate from path_correction_stalled"
  - "JobDetail.jsx summary-block disclosure of excluded zero-death causes and of a declined calibration"
affects: [01-02]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "vacalibration()'s own donotcalib argument used to exclude zero-death causes from the path-correction search WITHOUT shrinking the misclassification matrix handed to the package (matrix stays full 9x9/6x6; only the calibration exclusion set changes)"
    - "Two-tier masking: hide_causes masks a cause OUT of the displayed misclassification matrix but is excluded from the reported not_calibrated set, so the footnote still names only what the PACKAGE declined, while zero_count_causes discloses what WE excluded separately"
    - "RED-state test safety: every call to a not-yet-implemented function or a function given a new argument is wrapped in a local tryCatch(..., error = function(e) NULL) helper (try_zero_count_causes, try_build_donotcalib, try_extract_misclass, the existing try_assemble), so a RED run reports named FAILs instead of halting the whole test script"

key-files:
  created: []
  modified:
    - backend/jobs/utils.R
    - backend/jobs/algorithms/vacalibration.R
    - backend/jobs/processor.R
    - tests/test_vacalibration_backend.R
    - frontend/src/components/JobDetail.jsx
    - frontend/src/components/JobDetail.test.js
    - frontend/src/components/CSMFChart.test.js
    - .planning/phases/01-issue-101-calibration-correctness/deferred-items.md

key-decisions:
  - "build_donotcalib() always includes 'other' explicitly for every algorithm, even when that algorithm has no zero-count causes, because supplying ANY donotcalib value suppresses vacalibration()'s own default (`if (is.null(donotcalib)) donotcalib = 'other'`); omitting it would silently start calibrating 'other'."
  - "unobserved_causes() (the set hidden from display/export) is the INTERSECTION of each algorithm's zero-count set, not the union: a cause zero for one algorithm but observed by another must stay visible because that algorithm's facet carries real deaths. donotcalib itself stays per-algorithm (built from each algorithm's own zero set), which is a deliberately different rule."
  - "hidden_causes drop causes from cause-keyed fields WITHOUT renormalizing survivors -- they carry zero deaths by construction, so dropping them distorts nothing, and renormalizing would invent false precision."
  - "build_calibrated_map() uses a strict length match against dimnames(pcalib_postsumm)[[1]] (returns NULL on any mismatch), unlike build_lambda_map()'s min()-based tolerant match -- result$calibrated's own shape guarantee (len(calibrated) == len(labels) whenever both algorithm and ensemble mode are represented) makes NULL-on-mismatch the safer default here."
  - "No frontend cause filtering was added: CSMFChart.js's orderedCauses() already derives its cause list from Object.keys(results.calibrated_csmf), so a backend-filtered payload already yields filtered chart facets and table columns. A regression test (CSMFChart.test.js) locks this invariant instead of duplicating the filter client-side."

patterns-established:
  - "donotcalib built from observed death counts, never from raw uploaded cause strings: every entry is intersect(colnames(m), ...), which both satisfies the package's own name-validation and closes off any injection path from attacker-controlled CSV content (threat T-01-01-01)."

requirements-completed: [R1]

# Metrics
duration: ~45min
completed: 2026-08-24
---

# Phase 01 Plan 01: Zero-Count Cause Exclusion (R1) Summary

**`donotcalib` built from observed death counts (not raw cause strings) stops a zero-death broad cause from stalling path correction, while the full misclassification matrix — and malaria's calibration — is preserved; the excluded causes are dropped from every result field/CSV and disclosed in the UI.**

## Performance

- **Duration:** ~45 min
- **Started:** 2026-08-24T15:55:00-04:00 (approx.; base commit reset + research)
- **Completed:** 2026-08-24T16:12:31-04:00
- **Tasks:** 3 completed
- **Files modified:** 8

## Accomplishments
- `zero_count_causes()`, `unobserved_causes()`, `build_donotcalib()`, `build_calibrated_map()` added to `backend/jobs/utils.R`, all built from the one-hot matrices' own `colSums()` — never from raw uploaded cause strings (closes threat T-01-01-01).
- Both `run_vacalibration()` and `run_pipeline()` now pass `donotcalib = build_donotcalib(va_input)` to `vacalibration()`, and log the exclusion per algorithm before the call (threat T-01-01-06, "not silent").
- `assemble_calibration_result()` filters `hidden_causes` out of `uncalibrated_csmf`, `calibrated_csmf`, both CI bound lists, every `per_algorithm` entry's four lists, `cause_order`, and `cause_display_names`, without renormalizing survivors; `calibration_summary.csv` correspondingly has no row for a hidden cause.
- `extract_misclass_matrix()`/`.build_misclass_entry()` gained `hide_causes`: masks a zero-death cause out of the displayed matrix (no row/column) while keeping the `not_calibrated` footnote naming only what the PACKAGE declined — the causes WE excluded are disclosed separately via `zero_count_causes`.
- `build_stall_fields()` gained `calibration_declined` (via the new `build_calibrated_map()`), covering the "one or fewer calibratable causes" edge case, kept strictly distinct from `path_correction_stalled` (declined = lambda NA; stalled = lambda at the ceiling).
- `JobDetail.jsx` discloses excluded zero-death causes (both `unbox()` wire shapes: array or bare string) and a declined-calibration note, using strict `=== true`/`Array.isArray` checks matching the file's existing conventions.
- Reproduced the issue's own file end to end at low `nMCMC`: on `frontend/public/sample_eava_child.csv` (child, Mozambique, EAVA), lambda moves from the 0.99 stall to a real (unseeded, ~0.3–0.4) value, `other_infections` moves ~0.30 → ~0.45, malaria stays calibrated, and `Mmat_tomodel` stays `1 x 9 x 9`.
- Full R suite: 573 tests, 572 passed (the 1 failure is the pre-existing, unrelated MCMC flake in section 12c — see `deferred-items.md`). `test_misclass_matrix.R` 52/52, `test_auth_visibility.R` 32/32, `test_input_persistence.R` 18/18. Frontend: 34 files, 322/322 passing (up from the pre-plan 315).

## Task Commits

Each task was committed atomically:

1. **Task 1: Write the failing tests, including the two edge cases the fix creates** - `296caaa` (test)
2. **Task 2: Build donotcalib from the death counts, pass it from both paths, and filter the zero-death causes out of the payload** - `58af6b3` (feat)
3. **Task 3: Disclose the excluded causes and a declined calibration in the results summary** - `3418e72` (feat)

## Files Created/Modified
- `backend/jobs/utils.R` - Added `zero_count_causes()`, `unobserved_causes()`, `build_donotcalib()`, `build_calibrated_map()`; extended `build_stall_fields()` with `calibration_declined`; threaded `hidden_causes`/`hide_causes` through `assemble_calibration_result()` and `extract_misclass_matrix()`/`.build_misclass_entry()`
- `backend/jobs/algorithms/vacalibration.R` - `run_vacalibration()` passes `donotcalib = build_donotcalib(va_input)`, logs per-algorithm exclusions, passes `hidden_causes` to the assembler
- `backend/jobs/processor.R` - `run_pipeline()` does the same for the openVA→vacalibration pipeline path
- `tests/test_vacalibration_backend.R` - Added section 30 (deterministic: 24 assertions) and section 30b (MCMC reproduction of the issue's file: 8 assertions)
- `frontend/src/components/JobDetail.jsx` - Summary-block disclosure of `zero_count_causes` and `calibration_declined`
- `frontend/src/components/JobDetail.test.js` - Source-assertion tests for the new disclosure (5 tests)
- `frontend/src/components/CSMFChart.test.js` - View-model invariant test: hidden causes cannot reappear via a stale `cause_order`
- `.planning/phases/01-issue-101-calibration-correctness/deferred-items.md` - Logged 3 pre-existing, unrelated issues discovered during verification (see below)

## Decisions Made
See `key-decisions` in frontmatter. In summary: `donotcalib` is always explicit-and-full (including `"other"`) per algorithm; `unobserved_causes()` (the hidden/disclosed set) is an intersection across algorithms, deliberately different from `donotcalib`'s per-algorithm union-with-"other"; hidden causes are dropped, never renormalized; `build_calibrated_map()` fails closed (NULL) on any length mismatch; no cause filtering was duplicated into the frontend.

## Deviations from Plan

None — plan executed exactly as written. All three pre-existing issues discovered during verification (below) were confirmed via `git stash` to predate this plan and are out of scope per the scope-boundary rule; they were logged to `deferred-items.md`, not fixed.

## Issues Encountered

**Worktree base was stale at spawn time.** This worktree's branch tip (`b80773c`) was several commits behind the orchestrator's expected base (`fcedce4f`, which includes wave 1's plan 01-03 merge and phase-tracking docs). Per the `<worktree_branch_check>` protocol, `git reset --hard` to the expected base was safe here because the worktree's own tip was a strict ancestor of the expected base (verified via `git merge-base --is-ancestor`) — no local work was discarded.

**Three pre-existing, unrelated failures surfaced during full verification** (all confirmed via `git stash` to reproduce identically without this plan's changes, and logged to `deferred-items.md` rather than fixed, per the scope-boundary rule):
1. `tests/test_vacalibration_backend.R` section 12c MCMC flake (already documented from plan 01-03).
2. `check_integration.py` reports `GET /admin/users/{param}` as a frontend call with no backend route.
3. `npm run lint` reports 4 errors, all in `frontend/src/auth/AuthContext.jsx` (last touched in PR #60, long before this plan).

**Backend API / Playwright E2E verification not run against this worktree**, same reason documented in plan 01-03's summary: the only process listening on `:8000` has its cwd in the main repo checkout (`/Users/ericliu/projects5/comsa_dashboard/backend`), not this isolated worktree, so those suites would validate the main repo's unmodified code, not this plan's changes. The R unit suite (573 tests) and frontend suite (322 tests), which directly exercise every line this plan touched, were run in full and are green (except the one pre-existing MCMC flake).

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- R1 is complete: the issue's own file now calibrates instead of returning a silent no-op, malaria stays calibrated, and the exclusion is disclosed rather than silent.
- Plan 01-02 (which owns the stalled/ensemble wording, per this plan's `<action>` note) can build on `build_calibrated_map()` and `calibration_declined` without re-deriving them.
- No blockers. Three unrelated pre-existing issues are logged in `deferred-items.md` for their respective owners.

## Self-Check: PASSED

All files verified present via `ls -la`: `backend/jobs/utils.R`, `backend/jobs/algorithms/vacalibration.R`,
`backend/jobs/processor.R`, `tests/test_vacalibration_backend.R`, `frontend/src/components/JobDetail.jsx`,
`frontend/src/components/JobDetail.test.js`, `frontend/src/components/CSMFChart.test.js`, this
SUMMARY.md, and `deferred-items.md`. All commits verified present via `git log --oneline -5`:
`296caaa` (Task 1), `58af6b3` (Task 2), `3418e72` (Task 3).

---
*Phase: 01-issue-101-calibration-correctness*
*Completed: 2026-08-24*
