---
phase: 01-issue-101-calibration-correctness
plan: 03
subsystem: backend
tags: [r, plumber, vacalibration, refactor, testing]

# Dependency graph
requires: []
provides:
  - "assemble_calibration_result() in backend/jobs/utils.R — the single post-vacalibration() result assembler"
  - "run_vacalibration() and run_pipeline() both delegate to it instead of duplicating ~90 lines each"
  - "Section 29 in tests/test_vacalibration_backend.R — behavior tests plus a source-level guard that fails if either job path stops delegating"
affects: [01-01, 01-02]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Shared result-assembly function called from both job paths (run_vacalibration, run_pipeline) instead of duplicated inline blocks"
    - "Comment-stripped source assertions (strip_comments() helper) for wiring/guard tests, so prose mentioning an identifier doesn't false-positive a grepl check"

key-files:
  created: []
  modified:
    - backend/jobs/utils.R
    - backend/jobs/algorithms/vacalibration.R
    - backend/jobs/processor.R
    - tests/test_vacalibration_backend.R

key-decisions:
  - "assemble_calibration_result() takes ensemble_val as an explicit parameter rather than recomputing it, since the two callers derive it differently upstream (sample-data auto-detect vs. explicit request flag) but both already hold the exact value passed to vacalibration(ensemble = ...); recomputing risked silently diverging from actual behavior."
  - "The one permitted behavior change (per plan): run_pipeline() now passes the full normalized algorithm vector to the `algorithm` field instead of collapsing to normalize_algo_name(algorithms[1]) when ensemble is off, unifying with run_vacalibration()'s existing behavior (issue #83)."
  - "Retargeted sections 14b, 14c, and 28's wiring assertions (which required vacalibration.R/processor.R to call the primitives directly) at utils.R, since those calls now live inside assemble_calibration_result() there. This was necessary for suite-green but not explicitly listed in the plan's Task 1 scope (Rule 1 auto-fix: the plan's own acceptance criteria require Failed: 0)."

patterns-established:
  - "Pure move-and-call refactor: one shared function, two call sites, zero result-field/filename/rounding/log-message changes except the one documented unification."

requirements-completed: [R3]

# Metrics
duration: 18min
completed: 2026-08-24
---

# Phase 01 Plan 03: Shared Result Assembly (R3) Summary

**Collapsed the two near-verbatim post-calibration result-assembly blocks in `vacalibration.R` and `processor.R` into one `assemble_calibration_result()` in `utils.R`, with a source-level guard test that fails if either path stops delegating to it.**

## Performance

- **Duration:** ~18 min
- **Started:** 2026-08-24T15:30:22-04:00 (base commit)
- **Completed:** 2026-08-24T15:48:36-04:00
- **Tasks:** 2 completed
- **Files modified:** 4 (+ 1 new deferred-items doc)

## Accomplishments
- `assemble_calibration_result()` added to `backend/jobs/utils.R`: the single place that builds CSMF/CI fields, per-algorithm breakdown, path-correction stall fields, misclassification matrices, and `calibration_summary.csv`/`misclass_matrix*.csv` output files.
- `run_vacalibration()` (vacalibration.R) shrank from 298 to 216 lines; `run_pipeline()` (processor.R) shrank from 292 to 222 lines. Both now call `assemble_calibration_result()` exactly once, verified by comment-stripped source assertions.
- Added test section 29 (23 behavior + guard assertions) covering: exact result-object field set for single-algorithm and ensemble runs, `per_algorithm` presence/absence, 4-decimal rounding, `calibration_summary.csv`/misclassification-CSV filenames and content, conditional `cause_display_names`/`cause_order`, and the no-payload-leak of the stall `warning`.
- Retargeted the now-contradictory pre-existing wiring assertions in sections 14b, 14c, and 28 (which asserted the two job-path files call `build_per_algorithm()`/`build_stall_fields()`/`extract_misclass_matrix()`/`build_summary_df()` directly) to assert against `utils.R` instead, since that's where the calls now live.
- Full R suite: 539 tests, 538 passed (1 pre-existing, unrelated MCMC flake — see Known Issues). `test_misclass_matrix.R` (52/52), `test_auth_visibility.R` (32/32), `test_input_persistence.R` (18/18) all green. Frontend `npm test`: 315/315 green (proves no payload field name moved).

## Task Commits

Each task was committed atomically:

1. **Task 1: Write the failing tests for the shared assembler and the both-paths guard** - `0468b1e` (test)
2. **Task 2: Extract assemble_calibration_result() and rewrite both call sites** - `881dc41` (feat)

## Files Created/Modified
- `backend/jobs/utils.R` - Added `assemble_calibration_result()`, the single post-vacalibration() result assembler
- `backend/jobs/algorithms/vacalibration.R` - `run_vacalibration()` now delegates assembly to the shared function
- `backend/jobs/processor.R` - `run_pipeline()` now delegates assembly, merging its own pipeline-only fields (n_records, openva_csmf, cause_counts, causes.csv)
- `tests/test_vacalibration_backend.R` - Added section 29; retargeted sections 14b/14c/28's wiring assertions to utils.R
- `.planning/phases/01-issue-101-calibration-correctness/deferred-items.md` - Logged one pre-existing, unrelated test failure (new file)

## Decisions Made
- `ensemble_val` is an explicit required parameter of `assemble_calibration_result()` rather than being recomputed from `"ensemble" %in% result_labels` inside it — both callers already compute it (differently) before calling `vacalibration()`, and passing it through preserves exact pre-refactor behavior with zero risk of divergence.
- Followed the plan's one explicitly-sanctioned behavior change: `run_pipeline()` now always passes the full normalized algorithm vector for the `algorithm` field (previously collapsed to a single name when ensemble was off), unifying with `run_vacalibration()`.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Retargeted sections 14b/14c's wiring assertions, not just section 28's**
- **Found during:** Task 2 verification (full test suite run)
- **Issue:** The plan's Task 1 `read_first`/`action` only mentioned retargeting section 28's trailing loops. Sections 14b ("extract_misclass_matrix() helper (issue #90)") and 14c ("build_per_algorithm() helper (issue #83)") also asserted `vacalibration.R`/`processor.R` call `extract_misclass_matrix`/`build_per_algorithm` directly — which becomes false once those calls move into `utils.R` via `assemble_calibration_result()`. Left as-is, these would fail after Task 2, contradicting the plan's own acceptance criterion of `Failed: 0`.
- **Fix:** Retargeted both sections' wiring checks to assert against `utils.R` instead, keeping the negative "no longer gated on ensemble_val" check across all three files for robustness.
- **Files modified:** tests/test_vacalibration_backend.R
- **Verification:** Full suite passes (539/540, 1 pre-existing unrelated failure).
- **Committed in:** `0468b1e` (Task 1 commit — done alongside section 29 since it's the same category of pre-existing-test fallout from the refactor)

**2. [Rule 1 - Bug] Fixed two test bugs found while turning section 29 green**
- **Found during:** Task 2 verification
- **Issue:** (a) `all.equal()` comparing a named list-derived vector against an explicitly `unname()`d one reported a spurious attribute mismatch. (b) The retargeted "no path still reads the dead v2.0 Mmat.asDirich/Mmat.fixed" assertion included `utils.R`, which legitimately mentions those field names in `extract_misclass_matrix()`'s own docstring explaining pre-2.2 history — a false positive I introduced in Task 1.
- **Fix:** (a) `unname()` both sides of the comparison. (b) Strip comment lines from `utils.R`'s source before checking that assertion.
- **Files modified:** tests/test_vacalibration_backend.R
- **Verification:** `Rscript tests/test_vacalibration_backend.R --input-only` → 390/390; full suite → 538/539 (see Known Issues).
- **Committed in:** `881dc41` (Task 2 commit)

---

**Total deviations:** 2 auto-fixed (both Rule 1 — test-suite correctness fallout from the intentional refactor, not scope creep on the production code).
**Impact on plan:** No production-code behavior changed beyond the plan's single sanctioned unification. All fixes were to test assertions that would otherwise have gone stale or been wrong.

## Issues Encountered

**Pre-existing, unrelated test failure (not fixed, logged to deferred-items.md):** `tests/test_vacalibration_backend.R` section 12c, `"extracted matrix uses the 6 neonate broad causes"`, fails intermittently on a real low-iteration (`nMCMC=400`) `vacalibration()` run. Confirmed to reproduce identically on the pre-refactor code (verified via `git stash` before any Task 2 changes) — the test calls `extract_misclass_matrix()` directly and does not exercise any code this plan touched. Consistent with this project's documented MCMC non-determinism (unseeded Dirichlet search). Out of scope for a pure-refactor plan; see `.planning/phases/01-issue-101-calibration-correctness/deferred-items.md`.

**Backend API / Playwright E2E verification steps not run against this worktree:** The only process listening on :8000 is a long-running R backend whose cwd is the main repo checkout (`/Users/ericliu/projects5/comsa_dashboard/backend`), not this isolated worktree — so `test_backend.py` and `npm run test:e2e` would validate the main repo's code, not this plan's changes, and restarting/redirecting that shared process risks interfering with concurrent work. The R unit suite (539 tests) and frontend suite (315 tests), which directly exercise the refactored code and its full payload shape, were run in full and are green.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- R1 (01-01) and R2 (01-02) can now each implement their #101 fixes exactly once, in `assemble_calibration_result()`, instead of twice.
- No blockers. The one pre-existing MCMC flake (section 12c) is unrelated and logged for whoever owns test-suite iteration-count tuning.

## Self-Check: PASSED

All files verified present: `backend/jobs/utils.R`, `backend/jobs/algorithms/vacalibration.R`,
`backend/jobs/processor.R`, `tests/test_vacalibration_backend.R`, this SUMMARY.md, and
`deferred-items.md`. All commits verified present in git log: `0468b1e` (Task 1),
`881dc41` (Task 2), `8c3d3c6` (docs).

---
*Phase: 01-issue-101-calibration-correctness*
*Completed: 2026-08-24*
