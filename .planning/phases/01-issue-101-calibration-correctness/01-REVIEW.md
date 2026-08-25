---
phase: 01-issue-101-calibration-correctness
reviewed: 2026-08-25T14:44:07Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - backend/jobs/algorithms/vacalibration.R
  - backend/jobs/processor.R
  - backend/jobs/utils.R
  - frontend/src/components/CSMFChart.js
  - frontend/src/components/CSMFChart.test.js
  - frontend/src/components/JobDetail.jsx
  - frontend/src/components/JobDetail.test.js
  - frontend/src/components/MisclassificationMatrix.jsx
  - frontend/src/components/MisclassificationMatrix.test.js
  - tests/test_vacalibration_backend.R
findings:
  critical: 1
  warning: 10
  info: 10
  total: 21
status: issues_found
---

# Phase 01: Code Review Report

**Reviewed:** 2026-08-25T14:44:07Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Phase 01 lands four related changes: `donotcalib`-based zero-death cause exclusion (R1), the
retraction of the `ci_unreliable` false-precision claim (R2), and the `assemble_calibration_result()`
refactor (R3). I verified the core scientific claims against the installed `vacalibration` 2.2
source (`modular_vacalib_prior`): the `donotcalib` named-list shape matches the package's validator,
`lambda_calibpath` is length-K in `va_data` order with no ensemble entry, `result$calibrated` is
K (+1 for ensemble) in the same order as `dimnames(pcalib_postsumm)[[1]]`, and the full-size
misclassification matrix is preserved. `build_lambda_map()` / `build_calibrated_map()` index
correctly against those shapes. `donotcalib` entries are validated against `colnames()`, so the
package's own name check cannot fire. All 440 R tests and 103 frontend tests pass; eslint is clean
on the three touched components.

The defects are concentrated where the hidden-cause filtering meets the R→JSON boundary, and where
the R2 retraction changed one surface but not its siblings.

The one BLOCKER is reproducible and crashes the whole SPA: shrinking `cause_order` down to a single
surviving cause emits it as a bare JSON string, and `orderCauses()` calls `.filter` on it. The
project's own `unbox()` hazard was handled for `stalled_constituents` and `zero_count_causes` but
missed for `cause_order` — which only became length-variable *because of this phase*.

Beyond that: the summary CSV can carry a blanked interval alongside a note asserting the interval is
present; `buildCsmfTableRows()` never learned about `calibration_declined` so declined runs export
uncalibrated numbers labelled "Calibrated"; the misclassification panel lost its stall caveat for
ensemble jobs; the R3 refactor's own anti-duplication goal is contradicted by a verbatim 13-line
block copied into both callers; and one retraction guard test does not actually do the
case-insensitive matching its name claims.

## Critical Issues

### CR-01: A single surviving cause serialises `cause_order` as a bare string and crashes the whole Results view

**File:** `backend/jobs/utils.R:1286`, `frontend/src/utils/causeDisplay.js:36-41`,
`frontend/src/components/CSMFChart.js:17`

**Issue:** R1 introduced `cause_order <- cause_order[!(unlist(cause_order) %in% hidden_causes)]`.
Before this phase `build_cause_order()` always returned all 6 (neonate) / 9 (child) broad causes, so
`cause_order` was never shorter than 6 and always crossed the wire as a JSON array. It is now
length-variable. When 5 of 6 (or 8 of 9) broad causes have zero observed deaths — e.g. a small
upload where every record maps to `prematurity` — `cause_order` becomes a length-1 character vector,
and `toJSON(auto_unbox = TRUE)` emits it as a **bare string** (the `unbox()` hazard already
documented in this very file for `stalled_constituents` and `zero_count_causes`).

Reproduced against the real assembler:

```
$ Rscript -e 'source("jobs/utils.R"); ... assemble_calibration_result(..., hidden_causes = <5 causes>)'
{"algorithm":"eava",...,"cause_order":"prematurity","zero_count_causes":["ipre","pneumonia",...]}
```

`orderCauses()` guards only with `if (!causeOrder) return causes;` — a non-empty string is truthy —
then calls `causeOrder.filter(...)`. Reproduced in Node against the shipped module:

```
$ node -e "buildCsmfFacets({ cause_order:'prematurity', calibrated_csmf:{prematurity:1}, ... })"
THROWS: TypeError: causeOrder.filter is not a function
TABLE THROWS: causeOrder.filter is not a function
```

Both `buildCsmfFacets()` and `buildCsmfTableRows()` throw, and `reorderMatrixData()` in
`MisclassificationMatrix.jsx:8-17` has the identical shape. There is **no React error boundary
anywhere in `frontend/src`** (verified by grep for `ErrorBoundary|componentDidCatch|
getDerivedStateFromError` — zero hits), so the render error blanks the entire app, not just the tab.
This is exactly the failure mode the phase's own `zero_count_causes` disclosure was written to avoid.

Note this is *also* the "one cause remaining" edge case the plan called out, and it is the case where
`vacalibration()` returns `calibrated = FALSE` (declined) — i.e. the crash lands precisely on the run
the new `calibration_declined` banner exists to explain.

**Fix:** Normalise the wire shape on read (matching what `JobDetail.jsx:326-328` already does for
`zero_count_causes`), and harden the shared helper so no other caller can hit it:

```js
// frontend/src/utils/causeDisplay.js
export function orderCauses(causes, causeOrder) {
  const order = Array.isArray(causeOrder) ? causeOrder
    : typeof causeOrder === 'string' ? [causeOrder]
    : null;
  if (!order || order.length === 0) return causes;
  const ordered = order.filter(c => causes.includes(c));
  const remaining = causes.filter(c => !order.includes(c));
  return [...ordered, ...remaining];
}
```

Add a regression test in `CSMFChart.test.js` for `cause_order: 'prematurity'` (the unboxed shape) and
one in `tests/test_vacalibration_backend.R` section 30 asserting
`length(unlist(res$cause_order)) >= 1` survives `jsonlite::toJSON(..., auto_unbox = TRUE)` as an
array, or that the frontend contract tolerates the scalar.

## Warnings

### WR-01: A stalled run writes a blanked interval next to a note claiming the interval is present

**File:** `backend/jobs/utils.R:879-887`

**Issue:** `reason[]` is assigned for *every* cause when `stalled` is TRUE, so the later
`reason[is.na(reason) & drop_ci] <- "not calibrated; the interval is a point mass"` (line 886) can
never fire on a stalled run. But `drop_ci` (line 865) still blanks the bounds for point-mass causes.
Since `"other"` is always in `donotcalib` and therefore always a point mass, **every** stalled run
produces at least one row with `calibrated_lower = NA, calibrated_upper = NA` whose `interval_note`
reads "…the interval is the uncertainty of the uncalibrated estimate". Reproduced:

```
          cause uncalibrated calibrated_mean calibrated_lower calibrated_upper lambda  interval_note
pneumonia         0.3             0.3             0.29             0.31         0.99   no calibration was applied (lambda = 0.99); the interval is the uncertainty of the uncalibrated estimate
other             0.1             0.1               NA               NA         0.99   no calibration was applied (lambda = 0.99); the interval is the uncertainty of the uncalibrated estimate
```

This is the artifact that "outlives the page" per its own docstring, and it self-contradicts. The
test at `tests/test_vacalibration_backend.R:2440-2448` deliberately builds a `sd_stalled` fixture
whose second row (`other = 0.10/0.10/0.10`) is a point mass, but only ever asserts
`interval_note[[1]]` — the bug is inside the fixture and untested.

**Fix:** Compose the notes per row instead of overwriting:

```r
  stall_note <- if (stalled) paste0("no calibration was applied (lambda = ", lambda,
                   "); the interval is the uncertainty of the uncalibrated estimate")
                else if (declined) "vacalibration could not calibrate this dataset; the values are uncalibrated"
                else NA_character_
  reason <- rep(stall_note, length(causes))
  pm <- "not calibrated; the interval is a point mass"
  reason[drop_ci] <- if (is.na(stall_note)) pm else paste0(stall_note, "; ", pm)
```

Then assert on `sd_stalled$interval_note[[2]]` in the test.

### WR-02: `buildCsmfTableRows()` ignores `calibration_declined` — the table and its CSV export label uncalibrated numbers "Calibrated"

**File:** `frontend/src/components/CSMFChart.js:109-135` (specifically line 130),
`frontend/src/utils/export.js:168`

**Issue:** `makeGroup()` reads only `src.path_correction_stalled` and relabels the row when stalled.
It never reads `src.calibration_declined`, which the backend now sets on both the top-level result
and every `per_algorithm` entry (`utils.R:815`). A declined run — the case where `vacalibration()`
returned `calibrated = FALSE` and every value in `pcalib_postsumm` is a verbatim copy of
`p_uncalib` — is therefore printed in the CSMF Comparison table under the row type `"Calibrated"`,
and `exportConsolidatedCSMF()` writes that exact string into the downloadable CSV.

The chart facet (`JobDetail.jsx:437-441`) *does* handle it, and the summary banner
(`JobDetail.jsx:338-344`) does too — so the same run is disclosed on two surfaces and silently
mislabelled on the third. This is precisely the "a field missed here means it leaks into one surface
but not others" failure the phase brief warned about. Grep confirms no test anywhere asserts
`calibrationDeclined` behaviour in `buildCsmfTableRows`.

**Fix:**

```js
const declined = src.calibration_declined === true;
...
type: declined ? 'Calibrated (none applied — vacalibration could not calibrate this dataset)'
     : stalled ? 'Calibrated (none applied — interval is the uncalibrated estimate)'
     : 'Calibrated',
```

Mirror the chart's precedence (declined before stalled) and add a test for both orderings.

### WR-03: The misclassification panel lost its stall caveat for ensemble jobs

**File:** `frontend/src/components/JobDetail.jsx:354`, `frontend/src/components/MisclassificationMatrix.jsx:191-198`

**Issue:** The prop changed from
`ciUnreliable={results.ci_unreliable === true || results.path_correction_stalled === true}` to
`pathCorrectionStalled={results.path_correction_stalled === true}`.

`build_stall_fields()` never sets `path_correction_stalled` for the ensemble row (by design —
`build_lambda_map()` at `utils.R:701` does `setdiff(..., "ensemble")`, so the ensemble has no lambda
and `path_correction_stalled(NULL)` is FALSE). On an ensemble job the primary row *is* `"ensemble"`,
so `results.path_correction_stalled` is always FALSE and the panel now **never** shows the
"matrix is close to the identity" note — even when a constituent's λ is pinned at 0.99 and that
constituent's small multiple genuinely is a near-identity matrix. The old `ci_unreliable` disjunct
covered this case (backend set `ci_unreliable = stalled || length(culprits) > 0`).

The retraction correctly deleted the *false-precision claim*, but the panel's caveat is a statement
about the **matrix**, not about interval width, and it was still true. Stall detection was supposed
to be unchanged.

**Fix:** Pass the stalled-constituent information through as well, and key the note on either:

```jsx
<MisclassificationMatrix ...
  pathCorrectionStalled={results.path_correction_stalled === true}
  stalledConstituents={normalizeCauseList(results.stalled_constituents)} />
```

and in `MisclassificationMatrix.jsx` render the note when
`pathCorrectionStalled || stalledConstituents?.length`, naming the affected algorithms. Ideally the
note belongs on the per-algorithm `MatrixTable` (which knows which algorithm it is) rather than on
the shared header.

### WR-04: `processor.R`'s new comment claims a behaviour change the code cannot deliver

**File:** `backend/jobs/processor.R:214-219` (comment) vs `backend/jobs/processor.R:89`

**Issue:** The refactor comment states the change means "an independent (ensemble-off)
multi-algorithm pipeline run lists every algorithm instead of only the first (issue #83)". But line
89 still executes `algorithms <- algorithms[1]` whenever `ensemble_val` is FALSE, so by the time
`algo_names_pipeline <- unique(vapply(algorithms, normalize_algo_name, ...))` runs at line 219,
`algorithms` has already been truncated to one element. The pipeline path only ever runs and reports
one algorithm when ensemble is off — the #83 gap the comment claims to close is still open, and a
future reader will trust the comment.

**Fix:** Either delete the claim from the comment, or actually fix it — stop truncating and let the
loop run every algorithm, keeping `ensemble_val` FALSE:

```r
  if (ensemble_val) {
    add_log(job$id, paste("Pipeline ensemble: running openVA for", paste(algorithms, collapse=", ")))
  } else if (length(algorithms) > 1) {
    add_log(job$id, paste("Independent calibration: running openVA for",
                          paste(algorithms, collapse = ", "), "separately"))
  }
```

If the fix is deferred, log it in `deferred-items.md` and correct the comment now.

### WR-05: The R1 pre-call block is duplicated verbatim across both job paths — the exact duplication R3 removed

**File:** `backend/jobs/algorithms/vacalibration.R:186-197` and `backend/jobs/processor.R:173-184`
(plus `donotcalib = build_donotcalib(va_input)` at `vacalibration.R:210` / `processor.R:193`)

**Issue:** R3's docstring says the assembler exists "because fixes for #101 repeatedly landed in one
path only". R1 then re-introduced exactly that hazard on the *input* side: 12 identical lines
(zero-set computation, the per-algorithm log loop, `hidden_causes <- unobserved_causes(va_input)`)
are copy-pasted into both callers, and the `donotcalib` argument is passed in two places. A change
to the exclusion policy, the log wording, or the hidden-cause rule must now be made twice, with
nothing failing if it is made once. Section 29's caller guards check only that the *post*-call
primitives are gone; nothing guards the pre-call block.

**Fix:** Extract the mirror helper next to `assemble_calibration_result()`:

```r
# utils.R
prepare_calibration_exclusions <- function(va_input, job) {
  zero_sets <- zero_count_causes(va_input)
  for (algo in names(zero_sets)) {
    if (length(zero_sets[[algo]]) > 0) {
      add_log(job$id, paste0("Excluding from calibration for ", algo,
                             " (zero observed deaths): ", paste(zero_sets[[algo]], collapse = ", ")))
    }
  }
  list(donotcalib = build_donotcalib(va_input), hidden = unobserved_causes(va_input))
}
```

and add a section-29-style guard asserting neither caller inlines `zero_count_causes(` /
`unobserved_causes(`.

### WR-06: The R retraction guard is not case-insensitive despite its test name

**File:** `tests/test_vacalibration_backend.R:2514-2519`

**Issue:**

```r
test(sprintf("utils.R contains no retracted phrase (case-insensitive): %s", pat),
     !grepl(pat, utils_src_retraction, fixed = TRUE, ignore.case = TRUE))
```

R **ignores** `ignore.case` when `fixed = TRUE` and emits a warning. Verified:

```
$ Rscript -e 'print(grepl("Not Meaningful", "these are NOT MEANINGFUL", fixed=TRUE, ignore.case=TRUE))'
[1] FALSE
Warning message: argument 'ignore.case = TRUE' will be ignored
```

So the guard is case-sensitive: `"Not Meaningful"`, `"CI_UNRELIABLE"`, or `"Implausibly"` would all
pass. This is the single mechanism protecting the retraction from regressing into `utils.R` prose,
and it is weaker than it claims. (The frontend equivalent at `CSMFChart.test.js:495-511` is correct —
it lowercases the source and the patterns.)

**Fix:**

```r
test(sprintf("utils.R contains no retracted phrase (case-insensitive): %s", pat),
     !grepl(pat, utils_src_retraction, ignore.case = TRUE, fixed = FALSE, perl = FALSE))
```

or, simplest and consistent with the JS guard:
`!grepl(tolower(pat), tolower(utils_src_retraction), fixed = TRUE)`.

### WR-07: The plan's named edge cases have no tests, and the frontend tests cannot catch behavioural gaps

**File:** `tests/test_vacalibration_backend.R:2745-2980`, `frontend/src/components/JobDetail.test.js`

**Issue:** The plan called out four edge cases for the R1 helpers. Section 30 covers none of the
boundary ones:

- **all causes zero / one cause remaining** — untested; this is CR-01's trigger, and also the case
  where `vacalibration()` returns `calibrated = FALSE`.
- **empty `va_input`** — `unobserved_causes(list())` is guarded in code (`utils.R:746`) but never
  asserted; `build_donotcalib(list())` is neither guarded nor tested (it returns an unnamed empty
  list, which the package's `is.null(names(donotcalib))` check would reject with a bare `stop()`).
- **matrix with NULL `colnames`** — `zero_count_causes()` returns `NULL`, and `build_donotcalib()`
  then yields `character(0)`, which *silently re-enables calibration of `"other"`* — the precise
  failure the function's own docstring (`utils.R:750-756`) says must never happen.

Separately, `JobDetail.test.js` is 100% `expect(jobDetailSrc).toContain(...)` source-string greps —
29 assertions, zero renders. That is why WR-02 slipped through: the tests assert that the string
`'results.calibration_declined === true'` appears in the file, which proves nothing about whether the
comparison table honours it.

**Fix:** Add section-30 cases for `list()`, a NULL-colnames matrix, and a one-surviving-cause
assemble (asserting the JSON shape of `cause_order`). Add at least one `@testing-library/react`
render test for `CalibratedResults` covering the declined + zero-count disclosure paths.

### WR-08: `normalize_algo_name()` silently coerces any unknown algorithm to `"insilicova"`

**File:** `backend/jobs/algorithms/vacalibration.R:5-8`

**Issue:**

```r
switch(a, "interva" = "interva", "insilicova" = "insilicova", "eava" = "eava", "insilicova")
```

The trailing bare `"insilicova"` is `switch()`'s default. Any unrecognised value silently becomes
InSilicoVA — a wrong-science guess of exactly the kind `utils.R:390-405` forbids ("a parameter that
determines WHAT SCIENCE RAN is never guessed"). It is currently unreachable via the HTTP API because
`require_algorithms()` validates, but it is reachable by any direct caller, by a rerun of a legacy
job row, and it silently mis-selects the CHAMPS misclassification matrix if it ever fires.

**Fix:**

```r
normalize_algo_name <- function(algo) {
  a <- tolower(trimws(algo))
  if (!a %in% c("interva", "insilicova", "eava")) {
    stop(sprintf("Unsupported algorithm '%s'. Must be one of: InterVA, InSilicoVA, EAVA.", algo),
         call. = FALSE)
  }
  a
}
```

### WR-09: The refactor reordered the pipeline's log lines — "All results saved" now precedes the saving

**File:** `backend/jobs/processor.R:212` vs `backend/jobs/utils.R:1319`

**Issue:** R3 was a behaviour-preserving refactor, but the pipeline's log sequence changed. Before,
`calibration_summary.csv` and the misclassification CSVs were written inline *before*
`add_log("All results saved")`. Now `assemble_calibration_result()` writes them and logs
`"Results saved"` **after** line 212, so a pipeline job's log reads:

```
All results saved
Results saved
```

Confusing for the "keep log simple" requirement in `CLAUDE.md`, and it means "All results saved" is a
false statement at the moment it is emitted.

**Fix:** Move `add_log(job$id, "All results saved")` in `processor.R` to after the
`assemble_calibration_result()` call, or drop it and keep the assembler's single `"Results saved"`.

### WR-10: The `declined run` summary-CSV test uses a fixture the code can never produce

**File:** `tests/test_vacalibration_backend.R:2479-2495`

**Issue:** `sd_declined` is built with `ci_lower = list(pneumonia = 0.29, ...)` and
`ci_upper = list(pneumonia = 0.31, ...)`, then asserts `"declined run: bounds are kept"`. But in
`modular_vacalib_prior` the declined branch sets
`p_calib_postsumm = rbind(puncalib, puncalib, puncalib)` (verified in the installed 2.2 source), so a
real declined run has `lowcredI == upcredI == postmean` for **every** cause. `drop_ci` therefore
blanks all of them and the real CSV has no bounds at all. The assertion is vacuously true and gives
false confidence that declined runs export intervals.

**Fix:** Rebuild the fixture from `p_uncalib` (as `declined_result_30` at line 2841 correctly does)
and assert what actually happens: every bound blank, `interval_note` on every row.

## Info

### IN-01: `any_stalled()` is dead production code

**File:** `backend/jobs/utils.R:718`
**Issue:** Grep across `backend/`, `frontend/src`, and `tests/` shows the only callers are three
assertions in `tests/test_vacalibration_backend.R:2276-2281`. No production path uses it.
**Fix:** Delete the function and its tests, or document why it is retained.

### IN-02: Function name collides with a result field name

**File:** `backend/jobs/utils.R:738` (function) vs `backend/jobs/utils.R:1361` (result key)
**Issue:** `zero_count_causes()` is a helper returning the **per-algorithm** zero sets, while
`result_obj$zero_count_causes` holds the **global intersection** (`unobserved_causes()`). Same name,
different semantics, one file apart.
**Fix:** Rename the result field to `excluded_zero_death_causes` (and the frontend read), or rename
the helper to `zero_count_causes_by_algo()`.

### IN-03: `zero_count_causes()` is computed twice per run

**File:** `backend/jobs/algorithms/vacalibration.R:190` and `:210`; same in `processor.R:177`/`:193`
**Issue:** Once for the log loop, once inside `build_donotcalib()`. Harmless, but it means the logged
exclusions and the actual `donotcalib` are derived independently — they agree today only because the
function is pure.
**Fix:** Fold into the single helper proposed in WR-05 so the logged set is provably the passed set.

### IN-04: `exists()` without `inherits = FALSE` can pick up a global binding

**File:** `backend/jobs/algorithms/vacalibration.R:179-180`
**Issue:** `if (!exists("cause_display_names")) cause_display_names <- NULL` searches enclosing
environments up to `.GlobalEnv`. On the synchronous fallback path (`processor.R:22`/`:32`, when the
runner script is missing or `system2` fails) multiple jobs share one global environment, so a global
of that name would leak one job's display map into another.
**Fix:** `if (!exists("cause_display_names", inherits = FALSE)) cause_display_names <- NULL`, or
better, initialise both to `NULL` at the top of the function.

### IN-05: The misclassification caption applies the primary row's λ to every algorithm's matrix

**File:** `frontend/src/components/JobDetail.jsx:353`, `MisclassificationMatrix.jsx:186-190`
**Issue:** `lambda={results.lambda_calibpath}` is the **primary row's** λ, but the caption "mixed with
the identity matrix at the path-correction λ (λ = 0.41)" sits above *all* small multiples. In a
multi-algorithm run each algorithm has its own λ (`lambda_calibpath` is length K), so the figure
caption is factually wrong for every algorithm but the first. Pre-existing, but now more visible
since R1 makes multi-algorithm runs the common case.
**Fix:** Pass the whole `per_algorithm` λ map and render λ per `MatrixTable`, or drop the numeric
value from the shared caption.

### IN-06: `not_calibrated` footnote attributes dashboard-chosen exclusions to vacalibration

**File:** `frontend/src/components/MisclassificationMatrix.jsx:134-141`, `backend/jobs/utils.R:1215`
**Issue:** The footnote reads "vacalibration excludes these causes from calibration". After R1, a
cause with zero deaths for *one* algorithm (but not globally hidden) is excluded because **we** put
it in `donotcalib`, yet it appears in that list with the package's name on it.
**Fix:** Split the footnote into "excluded by vacalibration" and "excluded because no deaths were
observed for this algorithm", using the per-algorithm zero sets (which the backend already computes
but currently discards).

### IN-07: `function(c)` shadows base `c()` inside `build_summary_df()`

**File:** `backend/jobs/utils.R:861-862`
**Issue:** `vapply(causes, function(c) as.numeric(ci_lower[[c]]), numeric(1))` shadows the base
concatenation function inside the closure. Safe today because the body does not call `c()`, but it is
a landmine for the next edit.
**Fix:** Rename the parameter to `cause`.

### IN-08: A test fixture and comment preserve the retracted "contamination" framing

**File:** `frontend/src/components/CSMFChart.test.js:139-156`
**Issue:** The fixture sets `ensemble: { path_correction_stalled: true }` and the comment reads "The
ensemble posterior is built from the per-algorithm draws, so one stalled algorithm contaminates it".
The backend can never produce `path_correction_stalled = true` for the ensemble row
(`build_lambda_map()` excludes it), and the "contaminates it" framing is the retracted claim that
`utils.R:707-712` now explicitly disavows. The R2 retraction guard at line 503 does not catch it
because "contaminates" is not in the forbidden list.
**Fix:** Rewrite the fixture as `stalled_constituents: ['eava']` on the ensemble row (the shape the
backend actually emits) and correct the comment. Consider adding `contaminat` to
`FORBIDDEN_RETRACTION_PATTERNS`.

### IN-09: Test comment contradicts the implementation it guards

**File:** `frontend/src/components/CSMFChart.test.js:462-466`
**Issue:** "the backend already filters zero-death causes out of `calibrated_csmf`/`uncalibrated_csmf`
…, but `cause_order` is built from the ORIGINAL upload and may still list one." It may not —
`assemble_calibration_result()` (`utils.R:1286`) filters `cause_order` too. The defence-in-depth test
is worth keeping; the rationale is wrong and will mislead whoever next touches `cause_order`.
**Fix:** Reword to "defence in depth: `cause_order` is also filtered backend-side, but the view model
must not depend on that."

### IN-10: `calibration_summary.csv` silently covers only the primary row

**File:** `backend/jobs/utils.R:1310-1316`
**Issue:** The summary CSV is built from the primary row only (ensemble, or the *first* algorithm for
an independent multi-algorithm run) and carries no column naming which algorithm it describes. A
2-algorithm ensemble-off run produces a single `calibration_summary.csv` that silently represents
only `eava`. Pre-existing, but R1 makes independent multi-algorithm runs more common.
**Fix:** Add an `algorithm` column and emit one block per label from `per_algorithm`, or name the
file `calibration_summary_<label>.csv`.

---

_Reviewed: 2026-08-25T14:44:07Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
