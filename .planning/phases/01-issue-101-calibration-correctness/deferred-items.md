# Deferred Items — Phase 01

Issues discovered during execution that are out of scope for the current plan
(pre-existing, unrelated to the plan's changes). Logged per the executor's
scope-boundary rule rather than fixed inline.

## 01-03: Pre-existing failure in section 12c (unrelated to the R3 refactor)

**Test:** `tests/test_vacalibration_backend.R` section "12c. Misclassification
Matrix Extraction (issue #90)" — `"extracted matrix uses the 6 neonate broad
causes"` (around line 1440).

**Symptom:** `extract_misclass_matrix(res90, "interva")$champs_causes` /
`$va_causes` does not `setequal()` the full 6 neonate broad causes after a
real (low-iteration, `nMCMC = 400`, `nBurn = 200`) `vacalibration()` run.

**Confirmed pre-existing and unrelated to plan 01-03:** reproduced identically
on the pre-refactor code (before `assemble_calibration_result()` existed, and
before `run_vacalibration()`/`run_pipeline()` were touched) and after. The
test calls `extract_misclass_matrix()` directly on a real `vacalibration()`
result — it does not exercise any code this plan changed.

**Likely cause:** `donotcalib_type = "learn"` (vacalibration's default) can
exclude an additional near-constant-column cause per algorithm depending on
the MCMC draw; at `nMCMC = 400` the excluded set is not guaranteed to be
empty. Consistent with the documented λ/MCMC non-determinism for this
package (unseeded Dirichlet search) — see `MEMORY.md`.

**Action:** Not fixed in this plan (out of scope per the scope-boundary rule
— this plan is a pure refactor and must not change calibration behavior).
Flag for whichever future issue owns test flakiness / MCMC-iteration-count
tuning in this suite.

## 01-01: Pre-existing integration-check failure (unrelated to R1)

**Check:** `python3 .claude/skills/test/scripts/check_integration.py --project-root .`
reports `Failed: 1` — `Frontend calls endpoints that don't exist in backend:
GET /admin/users/{param}`.

**Confirmed pre-existing and unrelated to this plan:** reproduces identically
with `git stash` applied (i.e. on the pre-01-01 tree, before any of this
plan's `donotcalib`/zero-count-cause changes). This plan touches only
`backend/jobs/utils.R`, `backend/jobs/algorithms/vacalibration.R`,
`backend/jobs/processor.R`, and the test/frontend files listed in its
frontmatter — none of which define API routes.

**Action:** Not fixed in this plan (out of scope per the scope-boundary
rule). Flag for whoever owns the admin-users endpoint / integration-checker
route inventory.

## 01-01: Pre-existing `npm run lint` failures in AuthContext.jsx (unrelated to R1)

**Check:** `cd frontend && npm run lint` reports 4 errors, all in
`frontend/src/auth/AuthContext.jsx` (`react-hooks/set-state-in-effect`,
`react-refresh/only-export-components`).

**Confirmed pre-existing and unrelated to this plan:** reproduces identically
with `git stash` applied. `AuthContext.jsx` was last modified in PR #60
(`a92f9db`), long before this plan touched `JobDetail.jsx`/`JobDetail.test.js`/
`CSMFChart.test.js`. `npm run build` succeeds regardless (these are lint-only
errors, not build errors).

**Action:** Not fixed in this plan (out of scope per the scope-boundary
rule). Flag for whoever owns the auth module / lint-rule cleanup.

## 01-REVIEW WR-04: the pipeline path still truncates to one algorithm when ensemble is off

**Where:** `backend/jobs/processor.R:89` — `algorithms <- algorithms[1]` inside
`run_pipeline()`'s `else` branch.

**Symptom:** issue #83 ("an independent, ensemble-off multi-algorithm run must
list every algorithm") is closed on the `run_vacalibration()` path but NOT on
the pipeline path. A pipeline job with 2+ algorithms and "Combine algorithms?"
off runs openVA for only the first one, so `algo_names_pipeline` at line ~219
holds a single element no matter what was requested. The R3 refactor comment
claimed otherwise; the comment has been corrected (WR-04) and the behaviour
left alone.

**Why deferred:** removing the truncation is a behaviour change, not a review
fix — it makes the pipeline run openVA (including InSilicoVA's 4000-iteration
fit) once per algorithm, which changes runtime, log volume and the
`causes.csv` artifact. It needs its own plan and a real end-to-end run, not a
one-line edit in a code-review pass.

**Action:** Flag for whoever owns the remainder of issue #83.

## 01-HUMAN-UAT: comparison table rounds a real interval to "(0–0)"

**Where:** the CSMF Comparison table's calibrated row (`buildCsmfTableRows` /
`JobDetail.jsx`), integer-percent formatting.

**Symptom:** with a cause at ~0.1% CSMF, `calibration_summary.csv` reports a
genuine interval (`prematurity`: lower 0, upper 0.0049) and the chart correctly
draws its whisker, but the table prints `0% (0–0)`. A reader sees what looks
like a point mass — the exact appearance `csmfWhisker()` deliberately suppresses
for real point masses — contradicting the whisker beside it.

**Confirmed not a phase-01 regression:** the backend payload is correct (real
bounds, correct `interval_note`), the chart is correct (whisker drawn), and the
point-mass causes in the same row are correctly blank. Only the table's display
precision is at fault, and that formatting predates this phase.

**Why deferred:** the fix is a display-precision decision (significant figures,
or a "<1%" style floor) that affects every cell in the table, not just stalled
runs. It needs its own call on how small fractions should read, not a patch
inside the R2 retraction work.

**Action:** flag for whoever owns CSMF display formatting.
