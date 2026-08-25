---
phase: 01-issue-101-calibration-correctness
fixed_at: 2026-08-25T15:09:46Z
review_path: .planning/phases/01-issue-101-calibration-correctness/01-REVIEW.md
iteration: 1
findings_in_scope: 11
fixed: 11
skipped: 0
status: all_fixed
---

# Phase 01: Code Review Fix Report

**Fixed at:** 2026-08-25T15:09:46Z
**Source review:** `.planning/phases/01-issue-101-calibration-correctness/01-REVIEW.md`
**Iteration:** 1

**Summary:**
- Findings in scope: 11 (1 Critical + 10 Warning; the 10 Info findings were out of scope)
- Fixed: 11
- Skipped: 0

## Verification

| Check | Baseline | After fixes |
|---|---|---|
| `Rscript tests/test_vacalibration_backend.R` | 596/597 | **639/640** (same single documented failure) |
| `cd frontend && npm test` | 332/332, 34 files | **357/357, 35 files** |
| `cd frontend && npm run build` | exit 0 | **exit 0** |
| `cd frontend && npm run lint` | 4 pre-existing errors | **4 errors, unchanged** |

- The one R failure is the pre-existing section 12c case (`extracted matrix uses the 6
  neonate broad causes`) — vacalibration MCMC nondeterminism at `nMCMC = 400`, already
  logged in `deferred-items.md`. It reproduces identically before and after these fixes.
- 43 new R assertions and 25 new frontend assertions were added; none silently skip.
- The 4 lint errors are in files these fixes never touched: 2 × `no-undef` on `process` in
  `frontend/src/api/integration.test.js` and 2 in `frontend/src/auth/AuthContext.jsx`. (The
  briefed baseline attributed all 4 to `AuthContext.jsx`; the actual split is 2/2. The count
  and the files are unchanged by this work.) Exporting `CalibratedResults` from
  `JobDetail.jsx` did **not** introduce a `react-refresh/only-export-components` error —
  that rule only fires on non-component exports.

## Fixed Issues

### CR-01: A single surviving cause serialises `cause_order` as a bare string and crashes the Results view

**Files modified:** `frontend/src/utils/causeDisplay.js`, `frontend/src/utils/causeDisplay.test.js`,
`frontend/src/components/CSMFChart.test.js`, `tests/test_vacalibration_backend.R`
**Commit:** `bf3c5b2`
**Applied fix:** Added an exported `normalizeCauseList()` to `causeDisplay.js` and routed
**both** arguments of `orderCauses()` through it, so the shared helper is hardened for every
caller (`buildCsmfFacets`, `buildCsmfTableRows`, `reorderMatrixData`) rather than patched at
one call site. `if (!causeOrder)` is replaced by a type check, per the project rule for the
R→JSON boundary. Behaviour for existing shapes is byte-identical (an already-array argument
is returned by reference; an empty `causeOrder` array still yields the original order).

Sibling-field audit: `stalled_constituents`, `zero_count_causes`, `not_calibrated` and
`algorithm` were already type-checked. `cause_order` was the only newly-variable-length
field left exposed — R1 made it so by filtering hidden causes out of it.

Regression nets: `orderCauses('prematurity')`-style cases in `causeDisplay.test.js`; both
view-model builders against `cause_order: 'prematurity'` in `CSMFChart.test.js`; and a new
section-30 R test that pins the actual wire shape — a one-survivor `assemble_calibration_result()`
really does serialise `"cause_order":"malaria"` as a bare string, so the contract the frontend
must tolerate is now asserted on the producing side too.

### WR-01: A stalled run writes a blanked interval next to a note claiming the interval is present

**Files modified:** `backend/jobs/utils.R`, `tests/test_vacalibration_backend.R`
**Commit:** `2be6eb8`
**Applied fix:** `build_summary_df()` now composes `interval_note` from two independent
clauses — a run-level clause (stalled / declined) and a per-row interval clause — instead of
assigning the run-level string to every row and then only filling the gaps. A point-mass row
under a stall now reads `"no calibration was applied (lambda = 0.99); the interval is a point
mass, so no bounds are shown"` rather than promising an interval next to two blank cells.

I deviated slightly from the review's suggested snippet: concatenating the *whole* stall note
with the point-mass note would have produced `"...the interval is the uncertainty of the
uncalibrated estimate; ...the interval is a point mass"`, which is the same contradiction in
one sentence. Splitting the stall note at the semicolon avoids it while keeping the exact
wording every existing assertion greps for.

The point-mass suppression rule itself is untouched, and no retracted phrasing was
reintroduced (the case-insensitive guard from WR-06 now actually enforces that).

### WR-02: `buildCsmfTableRows()` ignores `calibration_declined`

**Files modified:** `frontend/src/components/CSMFChart.js`, `frontend/src/components/CSMFChart.test.js`
**Commit:** `8663e8f`
**Applied fix:** `makeGroup()` reads `src.calibration_declined === true` and relabels the row
`Calibrated (none applied — vacalibration could not calibrate this dataset)`, which
`exportConsolidatedCSMF()` then writes to the CSV. Declined takes precedence over stalled,
matching `build_stall_fields()`; a comment records that the two are mutually exclusive (a
declined run's λ is NA, a stalled run's is at the ceiling) so the ordering only decides an
impossible tie. Four new tests: declined relabelling, strict `=== true` (an unboxed non-flag
must not relabel), per-facet isolation, and declined ≠ stalled ≠ plain `Calibrated`.

### WR-03: The misclassification panel lost its stall caveat for ensemble jobs

**Files modified:** `frontend/src/components/MisclassificationMatrix.jsx`,
`frontend/src/components/JobDetail.jsx`, `frontend/src/components/CalibratedResults.behavior.test.jsx`
**Commit:** `f04c009`
**Applied fix:** The panel accepts a `stalledConstituents` prop and renders the near-identity
caveat when `pathCorrectionStalled === true || stalledConstituents.length > 0`, naming the
affected algorithms. `JobDetail.jsx` passes
`stalledConstituents={normalizeCauseList(results.stalled_constituents)}`. The caveat's text is
unchanged — it is a statement about the **matrix**, not about interval width, so it is not
part of the R2 retraction. Stall detection in the backend is untouched.

The local `asCauseList()` in `MisclassificationMatrix.jsx` was replaced by the shared
`normalizeCauseList()` (same three lines, one definition).

I did not move the note down onto each `MatrixTable` (the review's "ideally"): that is
entangled with IN-05 (per-algorithm λ in the caption), which is Info-tier and out of scope.

Verified by a new **render** test file, not a source grep: an ensemble fixture with
`path_correction_stalled: false, stalled_constituents: ['eava']` now renders the caveat naming
EAVA, in the array shape and in the unboxed bare-string shape.

### WR-04: `processor.R`'s comment claims a behaviour change the code cannot deliver

**Files modified:** `backend/jobs/processor.R`,
`.planning/phases/01-issue-101-calibration-correctness/deferred-items.md`
**Commit:** `70dcaaa`
**Applied fix:** Took the review's documented second option. The comment now states plainly
that `algorithms <- algorithms[1]` still truncates an ensemble-off pipeline run, so issue #83
remains open on this path, and points at `deferred-items.md`. A new deferred entry records the
exact line, the symptom, and why the real fix was not attempted here: removing the truncation
makes the pipeline run openVA (including InSilicoVA's 4000-iteration fit) once per algorithm
— a behaviour and runtime change that needs its own plan and an end-to-end run, not a one-line
edit in a review-fix pass.

### WR-05: The R1 pre-call block is duplicated verbatim across both job paths

**Files modified:** `backend/jobs/utils.R`, `backend/jobs/algorithms/vacalibration.R`,
`backend/jobs/processor.R`, `tests/test_vacalibration_backend.R`
**Commit:** `d594453`
**Applied fix:** Extracted `prepare_calibration_exclusions(va_input, job)` into `utils.R` next
to `build_donotcalib()`. It runs the zero-set log loop and returns
`list(donotcalib = ..., hidden = ...)`; both callers collapsed from 12 duplicated lines plus a
duplicated `donotcalib =` argument down to two lines and `exclusions$donotcalib`.

Section 29's guard was extended in **both** directions, as required: each caller must now call
`prepare_calibration_exclusions(`, and `zero_count_causes(`, `unobserved_causes(` and
`build_donotcalib(` were added to the "no longer inlines" list. Section 29's existing
assertions all still pass — the new helper lives in `utils.R` alongside
`assemble_calibration_result()`, so nothing re-inlines an assembly primitive.

Also added functional tests that capture `add_log()` and assert the exclusion really is logged
(threat T-01-01-06), that the returned `donotcalib`/`hidden` are exactly what the underlying
helpers produce, and that a run with no zero-count causes logs nothing yet still excludes
`"other"`.

### WR-06: The R retraction guard is not case-insensitive despite its test name

**Files modified:** `tests/test_vacalibration_backend.R`
**Commit:** `4b2c190`
**Applied fix:** Used the review's simplest option —
`!grepl(tolower(pat), tolower(utils_src_retraction), fixed = TRUE)` — matching the frontend
guard's shape. Added a self-check assertion that the comparison genuinely matches
`"Not Meaningful"` against `"these are NOT MEANINGFUL"`, so the guard's own case-insensitivity
is now tested rather than asserted in a test name.

### WR-07: The plan's named edge cases have no tests

**Files modified:** `backend/jobs/utils.R`, `tests/test_vacalibration_backend.R`,
`frontend/src/components/CalibratedResults.behavior.test.jsx`
**Commit:** `cf347da`
**Applied fix:** Two of the three named edge cases turned out to be latent defects, so they got
a fix plus a test rather than a test asserting broken behaviour:

- **NULL `colnames`** — `zero_count_causes()` returned `NULL`, which `build_donotcalib()` turned
  into `character(0)`, silently re-enabling calibration of `"other"` (the precise failure its
  own docstring forbids). It now fails loudly, naming the two producers that always set
  colnames.
- **Empty `va_input`** — `build_donotcalib(list())` returned an unnamed empty list that the
  package rejects with a bare `stop()` from inside `vacalibration()`. It now fails with a
  message that says what is wrong. `zero_count_causes(list())` / `unobserved_causes(list())`
  are asserted to stay non-erroring.
- **All causes zero-count** — `assemble_calibration_result()` died on
  `"arguments imply differing number of rows: 0, 1"` from a zero-row data.frame against a
  length-1 λ. It now stops with a message naming the actual problem. Unreachable through either
  job path (both reject an empty upload first), but it was the plan's named case.
- **One or fewer calibratable causes** — covered by the CR-01 commit's section-30 block
  (`cause_order` shape, cause-keyed fields, one-row summary CSV).

Added `frontend/src/components/CalibratedResults.behavior.test.jsx`, the first **render** test
for the calibrated results view (`JobDetail.jsx` now exports `CalibratedResults` for it). It
covers the declined banner, the zero-count disclosure in both wire shapes, the comparison
table's row labelling (the WR-02 defect, caught behaviourally this time), and a one-surviving-
cause + declined render that would have thrown before CR-01. `JobDetail.test.js`'s 29
source-grep assertions are left in place; this file is the behavioural counterpart the review
asked for.

### WR-08: `normalize_algo_name()` silently coerces any unknown algorithm to `"insilicova"`

**Files modified:** `backend/jobs/algorithms/vacalibration.R`, `tests/test_vacalibration_backend.R`
**Commit:** `a7611b1`
**Applied fix:** Replaced `switch()`'s bare default with an explicit membership check that
`stop()`s, naming the supported algorithms, and added `trimws()`. Guarded for
length-0/length-2/`NA` input as well (the `length(a) != 1` check short-circuits before `is.na()`
so no zero-length condition can reach `||`). New tests assert the three supported names still
normalize, whitespace is tolerated, and that `"openva"`, `"InterVA5"`, `""`, `NA` and
`character(0)` all raise instead of returning `"insilicova"`.

### WR-09: The refactor reordered the pipeline's log lines

**Files modified:** `backend/jobs/processor.R`, `tests/test_vacalibration_backend.R`
**Commit:** `5d483a6`
**Applied fix:** Dropped `add_log(job$id, "All results saved")` rather than moving it, per
CLAUDE.md's "keep log simple": `assemble_calibration_result()` already logs a single
`"Results saved"` after the summary CSV and misclassification CSVs are on disk, which covers
`causes.csv` too. A comment at the old site explains why nothing is logged there. Two guard
tests: `processor.R` must not contain `"All results saved"`, and `utils.R` must still emit the
single saved-line.

### WR-10: The `declined run` summary-CSV test uses a fixture the code can never produce

**Files modified:** `tests/test_vacalibration_backend.R`
**Commit:** `e37e5f5`
**Applied fix:** Rebuilt `sd_declined` from a single `uncalib_declined` list passed as
`uncalibrated`, `calibrated`, `ci_lower` and `ci_upper` — the shape
`p_calib_postsumm = rbind(puncalib, puncalib, puncalib)` actually produces. The vacuous
`"bounds are kept"` assertion is replaced by what really happens: every bound blank, the means
equal to the uncalibrated values, an `interval_note` on **every** row (not just the first),
and λ NA because a declined run never reached path correction.

## Notes for the developer

Two commits change runtime behaviour beyond the reported defect and are worth a human look
before the phase proceeds:

- **`a7611b1` (WR-08)** — `normalize_algo_name()` now raises on an unrecognized algorithm. This
  is unreachable through the HTTP API (`require_algorithms()` validates first), but a **rerun of
  a legacy job row** whose `algorithm` column holds something outside
  `{InterVA, InSilicoVA, EAVA}` will now fail loudly instead of quietly calibrating as
  InSilicoVA. That is the intended correction; confirm no such rows exist in the deployment if
  a silent-failure-to-loud-failure change would be disruptive.
- **`cf347da` (WR-07)** — three new `stop()` guards (NULL colnames, empty `va_input`, all causes
  zero-count). All three replace either a silent wrong answer or an unintelligible error, and
  all three are unreachable through the normal upload paths, but they are new failure modes.

`frontend/src/components/JobDetail.jsx` now exports `CalibratedResults` alongside its default
export, purely so the view can be rendered in isolation by the new behaviour test.

---

_Fixed: 2026-08-25T15:09:46Z_
_Fixer: Claude (gsd-code-fixer)_
_Iteration: 1_
