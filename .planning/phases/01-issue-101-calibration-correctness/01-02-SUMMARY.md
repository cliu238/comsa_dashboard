---
phase: 01-issue-101-calibration-correctness
plan: 02
subsystem: backend
tags: [r, vacalibration, plumber, calibration-correctness, retraction]

# Dependency graph
requires:
  - phase: 01-issue-101-calibration-correctness
    provides: "assemble_calibration_result() in backend/jobs/utils.R (plan 01-03), the single post-vacalibration() result assembler both job paths delegate to"
  - phase: 01-issue-101-calibration-correctness
    provides: "calibration_declined field on build_stall_fields() and build_calibrated_map() (plan 01-01)"
provides:
  - "build_stall_fields() without ci_unreliable, warning wording retracting the false-precision claim"
  - "build_summary_df() with interval_note (replacing ci_omitted_reason) that keeps a stalled/declined run's bounds and blanks only the degenerate point-mass case"
  - "Section 28 of tests/test_vacalibration_backend.R rewritten to assert the corrected framing, plus a retraction guard scanning backend/jobs/utils.R comments"
affects: [01-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Retraction guard: a loop-generated test per forbidden phrase, run against the RAW (comment-inclusive) source of a single file, to prevent a corrected claim from regressing back into prose"

key-files:
  created: []
  modified:
    - backend/jobs/utils.R
    - tests/test_vacalibration_backend.R

key-decisions:
  - "A stalled OR declined run's interval_note applies to every row in the summary data frame (not just individually-blanked ones), matching the plan's explicit instruction; a row that is BOTH part of a stalled run AND individually a point-mass cause keeps the stalled note, since reason[] is set for all rows before the point-mass fallback only fills remaining NAs -- same precedence the pre-existing code used for the run-level flag it replaced."
  - "interval_note is attached to the data frame only when at least one row has a note (matching the prior ci_omitted_reason behavior), so a healthy, non-stalled, non-declined, non-point-mass result has no interval_note column at all rather than an all-NA one."
  - "Historical/rationale comments explaining WHY the old suppression was wrong were phrased to avoid ever containing the literal retracted words (e.g. 'substantially narrower' instead of a multiplier phrase, 'a second flag' instead of naming the deleted field), since the retraction guard scans ALL of utils.R's text including comments for those exact substrings."

patterns-established: []

requirements-completed: [R2]

# Metrics
duration: ~35min
completed: 2026-08-24
---

# Phase 01 Plan 02: Retract False-Precision Framing (R2) Summary

**Deleted `ci_unreliable` and restored a stalled run's credible-interval bounds in `calibration_summary.csv`, replacing the suppression with `interval_note` wording that correctly labels the interval as the uncertainty of an uncalibrated estimate.**

## Performance

- **Duration:** ~35 min
- **Started:** 2026-08-24T19:50:00Z (approx.; base-commit reset + research)
- **Completed:** 2026-08-24T20:31:54Z
- **Tasks:** 2 completed
- **Files modified:** 2

## Accomplishments
- `ci_unreliable` deleted from `build_stall_fields()`'s return value (and therefore from `build_per_algorithm()`'s per-algorithm entries and `assemble_calibration_result()`'s top-level payload) — the field's only meaning, "these intervals carry false precision," is exactly the retracted claim.
- `build_stall_fields()`'s warning branch now fires off `stalled || length(culprits) > 0 || declined` directly (the deleted flag was only ever an OR of those three), with corrected wording: a stalled row's warning states no calibration was applied and that the interval is the uncertainty of the uncalibrated estimate; the ensemble-with-stalled-constituent warning names each culprit with its lambda, says no calibration was applied to those constituents, and says the ensemble point estimate is still a genuine fit — with no claim about interval width, per the plan's `<wording>` spec.
- `build_summary_df()` no longer blanks `calibrated_lower`/`calibrated_upper` for a stalled or declined run. Blanking now happens ONLY per-cause for the pre-existing degenerate point-mass case (`is.na(lo)`, `is.na(hi)`, or `!(hi > lo)`) — completely unrelated to the stall, and left untouched.
- `ci_omitted_reason` replaced with `interval_note`, populated per the plan's exact three strings: the stalled string (with lambda) for every row of a stalled run, the declined string for every row of a declined run, and the point-mass string for any individually-blanked row; attached to the data frame only when at least one row needs one.
- Rewrote the three comment blocks the plan named (the `LAMBDA_CEILING` block, `build_stall_fields()`'s preamble, `build_summary_df()`'s preamble) plus two more discovered during implementation (`stalled_algorithms()`'s preamble, and a one-line comment inside `assemble_calibration_result()`) — all five previously asserted or implied the retracted "false precision" / "7x tighter" / "not meaningful" claim.
- Section 28 of the test suite rewritten: every assertion that tested detection (boundary conditions, `build_lambda_map()`, `stalled_algorithms()`, the 0.99/1.01 ceiling split) is untouched; every assertion that tested presentation is inverted to the corrected expectation; a new retraction guard scans `backend/jobs/utils.R`'s raw source (comments included) for six forbidden phrases and fails if any regress.
- Confirmed RED (28 failures, exactly the inverted assertions plus the guard) before implementing, then GREEN: full R suite 596/597 (the 1 failure is the pre-existing, documented MCMC flake in section 12c, unrelated to this plan), `test_misclass_matrix.R` 52/52, `test_auth_visibility.R` 32/32, `test_input_persistence.R` 18/18, `check_integration.py` fails only on the pre-existing, documented `GET /admin/users/{param}` gap. Frontend: 322/322 (after `npm install`, which this worktree's checkout was missing).

## Task Commits

Each task was committed atomically:

1. **Task 1: Rewrite section 28 to assert the corrected framing** - `660ab52` (test)
2. **Task 2: Restore the bounds, delete ci_unreliable, and correct the wording and the comments** - `7f0e1c3` (feat)

## Files Created/Modified
- `backend/jobs/utils.R` — Deleted `ci_unreliable` from `build_stall_fields()`; rewrote its warning branches; rewrote `build_summary_df()` to stop blanking a stalled/declined run's bounds and to emit `interval_note` instead of `ci_omitted_reason`; corrected five comment blocks that stated or implied the retracted claim.
- `tests/test_vacalibration_backend.R` — Rewrote section 28's presentation assertions (bounds survive, no `ci_unreliable`, `interval_note` wording, forbidden-word checks on the two warning branches); added the retraction guard loop; retargeted section 29's single-algo top-level-names assertion, which had asserted `ci_unreliable`'s presence and would otherwise contradict this plan's own deletion of the field.

## Decisions Made
See `key-decisions` in frontmatter. In summary: a stalled/declined run's `interval_note` covers every row (not just individually-blanked ones), matching the plan's explicit per-row population rule; the column is omitted entirely (not all-NA) when nothing needs a note; and every corrected comment was phrased to avoid literally containing the retracted words, since the new retraction guard scans the whole file's raw text.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Retargeted section 29's top-level-names assertion for `single_out`**
- **Found during:** Task 1 RED-state verification
- **Issue:** `tests/test_vacalibration_backend.R` section 29 (added by plan 01-03, wave 1) asserted `assemble_calibration_result()`'s single-algorithm output has `setequal(names(single_out), c(..., "path_correction_stalled", "ci_unreliable"))`. This positively asserts the presence of the exact field this plan deletes, so it would otherwise regress into a false failure once Task 2 landed, contradicting this plan's own acceptance criterion of `Failed: 0`.
- **Fix:** Removed `"ci_unreliable"` from the expected name set in that one assertion. No other section-29 assertion referenced the field.
- **Files modified:** tests/test_vacalibration_backend.R
- **Verification:** Full suite green after Task 2 (596/597, the 1 failure pre-existing and unrelated).
- **Committed in:** `660ab52` (Task 1 commit, alongside section 28's rewrite, since it is the same category of pre-existing-test fallout from the intentional field deletion)

**2. [Rule 1 - Bug] Extended the "no retracted comment" cleanup beyond the plan's three named blocks**
- **Found during:** Task 2 implementation, while verifying the retraction guard
- **Issue:** The plan's `<action>` named three comment blocks to rewrite (`LAMBDA_CEILING`, `build_stall_fields()` preamble, `build_summary_df()` preamble). Two more comments also stated or implied the retracted claim: `stalled_algorithms()`'s preamble ("its intervals inherit the false precision") and a one-line comment inside `assemble_calibration_result()` ("Blanks the bounds ... when the intervals are not meaningful"). Left as-is, a future reader would still be told the retracted story, and the first would have tripped the plan's own acceptance criterion `grep -ric 'not meaningful' backend/` returns 0 was actually about `not meaningful` verbatim (not "false precision"), so this specific comment would NOT have failed that grep -- but it directly contradicts the plan's `<retraction_scope>` instruction to rewrite "every code comment that asserts the retracted claim."
- **Fix:** Rewrote both comments to describe only the still-true facts (the ensemble is its own Stan fit; the function reports which constituents stalled) without any claim about interval reliability or width.
- **Files modified:** backend/jobs/utils.R
- **Verification:** `grep -in 'not meaningful\|implausibly\|falsely narrow\|7x\|ci_unreliable\|ci_omitted_reason' backend/jobs/utils.R` returns nothing; full suite green.
- **Committed in:** `7f0e1c3` (Task 2 commit)

**3. [Rule 1 - Bug] Fixed a test bug in the ensemble no-interval_note assertion**
- **Found during:** Task 2 GREEN-state verification
- **Issue:** My own Task 1 test `test("ensemble: no interval_note -- the row itself did not stall", is.na(sd_ens$interval_note[[1]]))` assumed the `interval_note` column always exists. Per the plan's explicit instruction ("Attach the column only when at least one row has a note, matching the current `if (any(!is.na(reason)))` pattern"), a result with no stall, no decline, and no point-mass row correctly has NO `interval_note` column at all — so `sd_ens$interval_note` is `NULL` and `NULL[[1]]` throws, which would report a spurious FAIL rather than exercising the intended invariant.
- **Fix:** Changed the assertion to `!("interval_note" %in% names(sd_ens)) || is.na(sd_ens$interval_note[[1]])`.
- **Files modified:** tests/test_vacalibration_backend.R
- **Verification:** Test passes; full suite green.
- **Committed in:** `7f0e1c3` (Task 2 commit, alongside the implementation whose correct column-omission behavior this test bug had mismatched)

**4. [Rule 3 - Blocking issue] Installed frontend dependencies**
- **Found during:** Frontend verification step
- **Issue:** This worktree's `frontend/` had no `node_modules/` (a fresh worktree checkout, never previously `npm install`ed here), so `npm test` failed with `vitest: command not found` rather than exercising any code.
- **Fix:** Ran `npm install` in `frontend/` (271 packages, matches `package-lock.json`; `node_modules/` is gitignored, no commit needed).
- **Files modified:** none (gitignored install artifact only)
- **Verification:** `npm test` then ran and passed 322/322.

---

**Total deviations:** 4 (3 Rule 1 test/comment-completeness fixes, 1 Rule 3 environment fix). No production-code behavior changed beyond what the plan specified; all fixes were either to test assertions that would otherwise have gone stale/wrong, comments that would otherwise still tell the retracted story, or environment setup needed to run an existing verification step.

## Issues Encountered

**Worktree base was stale at spawn time, same as prior waves.** This worktree's branch tip was several commits behind the orchestrator's expected wave-3 base (`494a9943da160b8d799af97874e0917f0618cc89`, which includes both wave 1 (01-03) and wave 2 (01-01)'s merges). Per the `<worktree_branch_check>` protocol, `git reset --hard` to the expected base was performed after confirming the working tree was clean and the merge-base check indicated a divergence, not an ahead-state — no local work existed to lose.

**Pre-existing, unrelated failures confirmed during full verification (not fixed, consistent with `deferred-items.md` from prior waves):**
1. `tests/test_vacalibration_backend.R` section 12c MCMC flake ("extracted matrix uses the 6 neonate broad causes") — already documented from plan 01-03/01-01.
2. `check_integration.py` reports `GET /admin/users/{param}` as a frontend call with no backend route — already documented from plan 01-01.

**Backend API / Playwright E2E verification not run against this worktree**, same reason documented in plans 01-03's and 01-01's summaries: the only process listening on `:8000` has its cwd in the main repo checkout, not this isolated worktree, so those suites would validate the main repo's unmodified code, not this plan's changes. The full R unit suite and frontend suite, which directly exercise every line this plan touched, were run in full and are green (except the one pre-existing MCMC flake).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness
- R2 is complete: `calibration_summary.csv` carries a stalled run's real bounds again, labelled honestly; `ci_unreliable` is gone from the payload entirely; stall detection (`path_correction_stalled`, `lambda_calibpath`, `stalled_constituents`) is untouched.
- Plan 01-04 (frontend half of R2) can now read a payload with no `ci_unreliable` field and wire the chart/comparison table to `interval_note` instead of the deleted `ci_omitted_reason`. Per this plan's verification step 5, the frontend's existing `=== true` checks against the now-absent `ci_unreliable` already read `false` harmlessly — no frontend regression, but the suppression UI is now a no-op that 01-04 should replace with the corrected labelling.
- No blockers.

## Self-Check: PASSED

All files verified present: `backend/jobs/utils.R`, `tests/test_vacalibration_backend.R`, this
SUMMARY.md. All commits verified present in git log: `660ab52` (Task 1), `7f0e1c3` (Task 2).

---
*Phase: 01-issue-101-calibration-correctness*
*Completed: 2026-08-24*
