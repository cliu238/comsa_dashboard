---
slug: issue-104-matrix-mismatch
status: resolved
trigger: "看一下gh issue #104 ，顺便看看sandi是submit https://dev.sites.idies.jhu.edu/comsa-dashboard 的哪一个job？"
created: 2026-07-28
updated: 2026-07-28
resolution: >
  Fixed in PR #107 (merged, deployed). Root cause: extract_misclass_matrix()
  row-normalized the full 6-cause Mmat_tomodel instead of the per-algorithm
  calibrated submatrix. Confirmed in a real browser against the deployed build
  (EAVA 65/62/54/55/77, InSilicoVA 4x4 excluding congenital_malformation+other,
  InterVA diagonal 58 not 48.74 — all matching Sandi's R output). The <=0.3pp
  residual is upstream vacalibration 2.2 non-determinism (unseeded rdirichlet),
  not a dashboard defect. Cause-label truncation and per-algorithm progress bars
  also shipped. Reporter's original job 901322df cannot be re-run (its inputs
  were on ephemeral storage, now lost — see issue #110); she must re-upload.
---

# Debug: Dashboard misclassification matrix disagrees with R (GitHub issue #104)

## Symptoms

**Source:** GitHub issue #104 "mismatching result/newly-added preview step"
(author sandy-pramanik, opened 2026-07-27T11:47:19Z, 0 comments).

The issue bundles FOUR items. Only item 1 is a defect; 2–4 are UI/feature requests.

1. **(BUG — the subject of this session)** "The results look different from the R
   implementation... the misclassification matrices appear different... the cause names appear
   weird. I imagine the outputs to be similar and the matrix/csmf figures similar-looking in
   dashboard and R so that users can be comfortable using any of them."
   Reporter's own pointer: "in the list returned by vacalibration(), matrices are available under
   `Mmat_tomodel`, and csmf posterior means with 95% credible intervals are available under
   `pcalib_postsumm`."
2. (UI) The newly-added preview step details clutter the layout — hide, or move under Results tab.
3. (Feature) Separate progress bars per algorithm.
4. (Sub-item of 1) "the cause names appear weird".

- **Expected behavior:** the dashboard's misclassification matrix numerically equals
  vacalibration's own "Prior Mean of Misclassification Matrix — Used For Calibration" panel.
- **Actual behavior:** every probability is deflated, and an extra `other` row/column is rendered
  that vacalibration blanks out.
- **Timeline:** the matrix was (re)wired to `Mmat_tomodel` for issue #90; the deployed backend runs
  vacalibration 2.2 (local dev library has only 2.0).
- **Reproduction:** open job `901322df-0361-4795-aa0f-d8765401eb50` on
  https://dev.sites.idies.jhu.edu/comsa-dashboard → Results tab → InterVA misclassification matrix.

## Artifacts

**The job Sandi submitted (answers the second half of the user's question):**
`901322df-0361-4795-aa0f-d8765401eb50` — vacalibration, completed, InterVA+EAVA+InSilicoVA with
ensemble=TRUE, age_group=neonate, country=Mozambique.
created 2026-07-27 11:29:22, started 11:29:27, completed 11:29:57 — i.e. **18 minutes before the
issue was filed**. Identification is not merely temporal: the attached `neonate-dash.pdf` is
headed "Job: 901322df..." and every number in it matches this job's API payload.

- R reference output: `<scratch>/neonate-R.pdf` (1 page) → rendered `<scratch>/Rpage-1.png`
  (source: https://github.com/user-attachments/files/30411163/neonate.pdf)
- Dashboard output: `<scratch>/neonate-dash.pdf` (4 pages, 7/27/26 5:04 PM) → `<scratch>/dash.txt`
  (source: https://github.com/user-attachments/files/30411185/neonate-dash.pdf)
- Live API payload for the job: `<scratch>/job901322df.json`
- Reference implementation dumps (local vacalibration 2.0):
  `<scratch>/vacal_2.0.R`, `<scratch>/modular_vacalib_2.0.R`
- `<scratch>` = `/private/tmp/claude-501/-Users-eric-projects6-comsa-dashboard/a8e5095b-37b5-4e8f-b26e-1823a66d9e71/scratchpad`

## Evidence

- timestamp: 2026-07-28 (orchestrator, pre-handoff)
  finding: **The frontend renders the API payload faithfully — the defect is in the backend, not
  the React table.** The API returns `misclassification_matrix.interva` with
  `champs_causes = va_causes = [congenital_malformation, pneumonia, sepsis_meningitis_inf, ipre,
  other, prematurity]`, while `cause_order` (used by the UI) is
  `[other, ipre, sepsis_meningitis_inf, prematurity, pneumonia, congenital_malformation]`.
  Reordering the API's `congenital_malformation` row
  (48.74, 3.90, 2.77, 16.86, 14.99, 12.74) into `cause_order` gives
  (15, 17, 3, 13, 4, 49) — **exactly** the row printed in `neonate-dash.pdf`. The reorder is correct.

- timestamp: 2026-07-28 (orchestrator, pre-handoff)
  finding: **Row-by-row, the dashboard matrix equals R's "Used For Calibration" panel EXCEPT that
  the dashboard row-normalizes over all 6 causes instead of the 5 calibrated ones.** InterVA,
  columns in native order (cm, pneumonia, sepsis, ipre, other, prematurity), values as percent:
  ```
  CHAMPS row   dashboard (as served)                  drop `other`, renormalize   R "Used For Calib"
  cm           48.74  3.90  2.77 16.86 [14.99] 12.74  57.3  4.6  3.3 19.8  15.0   58  4  3 20  --  15
  pneumonia     3.03 41.35  4.37 25.84 [ 3.20] 22.20   3.1 42.7  4.5 26.7  22.9    3 43  4 27  --  23
  sepsis        2.95  6.68 37.24 24.89 [ 5.21] 23.02   3.1  7.0 39.3 26.3  24.3    3  7 39 27  --  24
  ipre          9.06  4.78  1.64 66.60 [ 2.16] 15.76   9.3  4.9  1.7 68.1  16.1    9  5  2 68  --  16
  other         7.03  6.42  7.07 29.95 [ 9.33] 40.21   (row should be blank)       ENTIRE ROW GREY
  prematurity   1.91  1.61  4.31 21.14 [ 2.11] 68.91   2.0  1.6  4.4 21.6  70.4    2  2  4 22  --  70
  ```
  The middle column reproduces R's panel to within rounding on all five calibrated rows. The
  bracketed `other` column and the whole `other` row are what the dashboard adds and R blanks.
  Note the dashboard's `other` ROW (7.03, 6.42, 7.07, 29.95, 9.33, 40.21) equals R's **Input**
  panel `other` row (7, 7, 7, 30, 9, 40) — it is leftover input data, not a calibration quantity.

- timestamp: 2026-07-28 (orchestrator, pre-handoff)
  finding: **vacalibration excludes `other` from calibration by default, and its own plot proves the
  intended recipe.** `vacalibration()` (dumped source, `<scratch>/vacal_2.0.R:47`):
  ```r
  if (is.null(donotcalib)) donotcalib = "other"
  ```
  The dashboard never passes `donotcalib`, so `other` is ALWAYS excluded.
  `modular.vacalib()` builds the "Used For Calibration" panel like this
  (`<scratch>/modular_vacalib_2.0.R:1229-1248`):
  ```r
  Mmat_toplot = output$Mmat.asDirich
  for (k in 1:dim(Mmat_toplot)[1]) {
    Mmat_toplot[k, , ] = diag(nCause)
    Mmat_toplot[k, !donotcalib_asmat[k,], !donotcalib_asmat[k,]] =
      output$Mmat.asDirich[k, !donotcalib_asmat[k,], !donotcalib_asmat[k,]] /
      rowSums(output$Mmat.asDirich[k, !donotcalib_asmat[k,], !donotcalib_asmat[k,]])
    ...
    Mmat_toplot[k, donotcalib_asmat[k,], ] = Mmat_toplot[k, , donotcalib_asmat[k,]] = NA
  }
  ```
  i.e. **subset to the calibrated causes FIRST, row-normalize over that submatrix, then blank the
  excluded row and column.** The calibration itself uses the same submatrix
  (`Mmat[!donotcalib, !donotcalib]`, lines 247-264 and 314-318).

- timestamp: 2026-07-28 (orchestrator, pre-handoff)
  finding: `normalize_mmat()` (`backend/jobs/utils.R:726-746`) row-normalizes the FULL matrix —
  `rs <- rowSums(mmat); mmat / rs` over all 6 causes — with no notion of `donotcalib`.
  `extract_misclass_matrix()` (`backend/jobs/utils.R:762+`) then emits every row and column,
  including `other`. Neither function references `donotcalib` or `causes_notcalibrated`.

- timestamp: 2026-07-28 (orchestrator, pre-handoff)
  finding: **The fix can be data-driven rather than hardcoding `"other"`.** `modular.vacalib`'s
  returned output list includes both `donotcalib = donotcalib_asmat` (K x nCause logical matrix,
  algorithm-named rows and cause-named columns) and
  `causes_notcalibrated = causes_notcalibrated` (per-algorithm character vector) — see
  `<scratch>/modular_vacalib_2.0.R:421`, `:551`, `:820`, `:957`. Must be re-confirmed on
  vacalibration **2.2**, which is what the deployed backend runs.

- timestamp: 2026-07-28 (orchestrator, pre-handoff)
  finding: **Corroborating signal that `other` is not calibrated** — in the dashboard's own CSMF
  table, `other` is the one cause whose calibrated value equals its uncalibrated value with a
  degenerate CI: EAVA 3% -> "3% (3-3)", InterVA 1% -> "1% (1-1)", InSilicoVA 5% -> "5% (5-5)",
  Ensemble 3% -> "3% (3-3)". It is passed through, never modelled. The CSMF numbers themselves
  agree with R's bar chart, so `pcalib_postsumm` handling is fine — the matrix is the only defect.

- timestamp: 2026-07-28 (orchestrator, pre-handoff)
  finding: **"cause names appear weird" is a separate, second defect: header truncation is
  ambiguous.** `neonate-dash.pdf` renders the matrix column headers as
  `Other an.. | Birth as.. | Neonatal.. | Prematur.. | Neonatal.. | Congenit..` — **two different
  columns both read "Neonatal.."** (Neonatal sepsis and Neonatal pneumonia are indistinguishable).
  R labels axes with the raw broad-cause codes (`congenital_malformation`, `sepsis_meningitis_inf`,
  ...). Two things differ from R at once: truncated friendly display names, and a different cause
  ordering (`cause_order` vs R's alphabetical-ish `causes`).

- timestamp: 2026-07-28 (this session)
  checked: Rendered R reference image `<scratch>/Rpage-1.png` per-panel crops, all three algorithms.
  found: >
    **The excluded (grey) set is PER-ALGORITHM.** eava greys only `other` (row+col); interva greys
    only `other`; **insilicova greys `congenital_malformation` AND `other`** (both rows and both
    columns). R's "Used For Calibration" integers:
    eava      cm 65 12 5 10 -- 8 | pn 2 62 15 12 -- 9 | sep 3 19 54 12 -- 12 | ipre 8 20 8 55 -- 9 | prem 2 8 3 10 -- 77
    interva   cm 58 4 3 20 -- 15 | pn 3 43 4 27 -- 23 | sep 3 7 39 27 -- 24 | ipre 9 5 2 68 -- 16 | prem 2 2 4 22 -- 70
    insilico  pn -- 47 7 23 -- 23 | sep -- 16 44 16 -- 24 | ipre -- 6 3 74 -- 17 | prem -- 4 4 5 -- 87
  implication: >
    Hardcoding `"other"` would still be wrong — insilicova needs a second cause masked. The fix
    must read the not-calibrated set per algorithm.

- timestamp: 2026-07-28 (this session)
  checked: Reordered/renormalized the live payload under the masked recipe vs R, all 3 algorithms.
  found: >
    **Worst cell deviation = 0.77 percentage points across all 19 calibrated cells**, and every
    masked row sums to exactly 100. By contrast the currently-served values deviate from R by up to
    9.3pp (interva cm diagonal 48.74 vs 58; eava cm diagonal 64.17 vs 65 after masking).
  implication: The masked recipe is confirmed correct for all three algorithms, not just InterVA.

- timestamp: 2026-07-28 (this session)
  checked: >
    Suspicion that the EAVA and InSilicoVA slices might be transposed relative to R.
  found: >
    **REFUTED.** Each dashboard slice matches its own same-named R slice: eava diagonal
    65/62/54/55/77 and insilicova diagonal 47/44/74/87 both land on their own panel. A swap would
    have made eava's diagonal match insilicova's. Labels are correct.
  implication: No relabelling needed. Only the normalization and the emitted cause set are wrong.

- timestamp: 2026-07-28 (this session)
  checked: >
    vacalibration **2.2** Value section, from the CRAN manual for v2.2
    (https://cran.r-project.org/web/packages/vacalibration/vacalibration.pdf, "Version 2.2",
    downloaded to `<scratch>/vacal_cran.pdf` / `.txt`).
  found: >
    **VERSION GAP SETTLED — the field names CHANGED between 2.0 and 2.2.**
    2.2 returns `Mmat_input`, `Mmat_study`, `Mmat_tomodel` ("Modified Mmat_study if
    path_correction is TRUE. This is used for calibration", array algorithm x CHAMPS cause x VA
    cause) — so the backend reads the right field. For the exclusion set 2.2 exposes
    **`donotcalib_study`** ("as specified in the input donotcalib", logical algorithm x VA causes)
    and **`donotcalib_tomodel`** ("causes that are not calibrated in each calibration ... a
    modified donotcalib_study if donotcalib_type is provided and ensemble=TRUE"). The 2.0 names
    `donotcalib` and `causes_notcalibrated` are **GONE** in 2.2. The argument was also renamed
    `donot.calib_type` (2.0) -> `donotcalib_type` (2.2).
  implication: >
    A fix reading only the 2.0 names would silently find nothing on the deployed backend. Worse,
    NEITHER 2.2 field is guaranteed to carry the per-algorithm learn-augmented set:
    `donotcalib_study` reflects only the input (= `other`), and `donotcalib_tomodel` may be
    collapsed for ensemble runs (2.0's ensemble branch ANDs the per-algorithm masks, i.e. an
    intersection). Both failure modes UNDER-report, so the fix unions every available declaration
    with a direct read-out of the calibration itself.

- timestamp: 2026-07-28 (this session)
  checked: `pcalib_postsumm` vs `p_uncalib` per algorithm in the live payload.
  found: >
    A version-independent read-out of "was this cause calibrated": a not-calibrated cause is passed
    through untouched, so `postmean == uncalibrated` AND `lowcredI == upcredI`. This reproduces R's
    grey cells EXACTLY for all four labels — eava {other}, interva {other}, ensemble {other},
    insilicova {congenital_malformation, other} (insilicova cm: uncal 0.0008 -> cal 0.0008,
    CI [0.0008, 0.0008]).
  implication: Reliable fallback/cross-check that needs no version-specific field name.

- timestamp: 2026-07-28 (this session)
  checked: >
    Persistence path — `backend/db/connection.R:399` (`toJSON(result, auto_unbox = TRUE)`),
    `load_job()` at `:210-235`, and the `/jobs/<id>/results` endpoint at `backend/plumber.R:470-487`.
  found: >
    **The matrix is PERSISTED, not recomputed on read.** `/results` returns `job$result` verbatim,
    parsed straight from the `jobs.result` JSONB. Also: `toJSON()` is called WITHOUT `na = "null"`,
    so an `NA_real_` cell would serialize as the **string** `"NA"`, not JSON null.
  implication: >
    (1) A backend fix cannot retroactively repair job 901322df — it needs a redeploy AND a re-run.
    (2) Blanked cells must NOT be emitted as `NA`; the fix drops the not-calibrated rows/columns
    and reports them in a separate `not_calibrated` field instead.

- timestamp: 2026-07-28 (this session)
  checked: `cause_display_names` in the live payload vs `formatCauseShort()` in MisclassificationMatrix.jsx:21-43.
  found: >
    Second defect pinned exactly. The payload maps `sepsis_meningitis_inf` -> "Neonatal sepsis" and
    `pneumonia` -> "Neonatal pneumonia". `formatCauseShort` truncates any display name longer than
    10 chars to `substring(0, 8) + '..'`, so both become **`Neonatal..`** — the two columns are
    indistinguishable (row headers are fine; they use the untruncated `formatCauseDisplay`).
  implication: Truncation must disambiguate rather than blindly cut at a fixed offset.

- timestamp: 2026-07-28 (continuation session, residual)
  checked: >
    Reimplemented R's display pipeline verbatim (modular_vacalib_2.0.R:1237-1245 —
    mask -> row-normalize -> `round(100*x)` -> overwrite the row's LARGEST cell with
    `100 - sum(rounded others)` -> blank) and ran it on the live payload for all 3 algorithms,
    then measured the MINIMUM perturbation R's printout actually requires.
    Script: `<scratch>/residual.R`.
  found: >
    **The residual is <=0.269pp, not 0.77pp, and 16 of the 66 printed integers differ only because
    of R's absorb-into-max step.** The absorbing cell is DERIVED, not rounded, so it constrains
    nothing; only the other 52 cells carry information. Of those 52, **43 are satisfied exactly**
    and 9 need a perturbation of 0.015 / 0.041 / 0.059 / 0.081 / 0.088 / 0.148 / 0.203 / 0.239 /
    0.269 pp. Worked example (the reporter's own cell): interva congenital_malformation row is
    (57.33, 4.59, 3.26, 19.83, 14.99). Only ONE constraint is violated — pneumonia is 4.588 where
    R's printed 4 requires [3.5,4.5), i.e. 0.088pp. That single 0.088pp difference flips pneumonia
    from 5 to 4, and the absorption step then re-derives the diagonal as 100-42=58 instead of
    100-43=57. The "58 vs 57" is a consequence, not an independent error.
  implication: >
    The 0.77pp figure in the earlier blind_spots was measuring raw values against R's PRINTED
    integers, which is the wrong comparison for the one derived cell per row. True per-cell
    disagreement is <=0.269pp.

- timestamp: 2026-07-28 (continuation session, residual)
  checked: >
    The coordinator's `stable` lead. Fitted the shrinkage parameter from R's OWN two panels —
    mask-renormalize R's "Input" panel and compare against R's "Used For Calibration" panel, with
    no dashboard number involved. Script `<scratch>/residual2.R` TEST C.
  found: >
    **REFUTED, by 17-21 percentage points.** Under `stable=FALSE` / `path_correction=FALSE` the two
    panels would be equal (lambda=0), i.e. R would print eava cm diagonal 44, interva cm 41,
    insilicova pneumonia 26. R prints 65, 58, 47. The implied per-row lambda is tightly
    self-consistent WITHIN each algorithm — eava .378/.396/.391/.390/.401 (median .391),
    interva .294/.297/.281/.295/.290 (median .294), insilicova .288/.281/.292/.292 (median .290) —
    exactly as `lambda_calibpath` (one lambda per algorithm) predicts. Refitting each algorithm with
    its single median lambda reproduces R's published panel (insilicova 3 of 4 rows byte-exact,
    the rest within 1, limited only by R's Input panel being integers).
  implication: >
    Sandi's run had the shrinkage ON — the same setting the dashboard silently uses. The two runs
    agree on this parameter. The title-suffix inference is void independently: Sandi's PDF uses a
    bold title + plain subtitle ("Prior Mean of Misclassification Matrix" / "Input" and
    "Used For Calibration"), and 2.0 emits NO subtitle at all (only `labs(title=)`), so 2.2
    restructured the title block and 2.0's `" (Adjusted)"` suffix logic cannot be assumed to
    have survived. Lead dead.

- timestamp: 2026-07-28 (continuation session, residual)
  checked: >
    Whether ANY difference in the shrinkage parameter could explain the residual, not just
    on/off. The shrinkage is `lambda*I + (1-lambda)*M`, so it scales every OFF-DIAGONAL cell in a
    row by the same `(1-lambda)`, and lambda is per-ALGORITHM. Solved for the feasible common
    scale factor `s = (1-lambda_R)/(1-lambda_dash)` from R's rounding intervals.
    Script `<scratch>/residual2.R` TEST B.
  found: >
    **INFEASIBLE for all three algorithms — and infeasible within single rows.** eava's pneumonia
    row alone requires s >= 1.00286 (sepsis must move UP) and s < 0.99878 (ipre must move DOWN)
    simultaneously; interva's congenital_malformation row requires s >= 0.98321 (ipre) and
    s < 0.98088 (pneumonia); same contradiction in interva sepsis, insilicova pneumonia and
    insilicova prematurity. Across the 9 violated constraints 4 need an increase and 5 a decrease.
  implication: >
    No scalar shrinkage difference — hence no `stable`/`path_correction` difference and no landing
    on a different rung of the 0.01 lambda grid — can produce this pattern. The residual is a
    per-cell difference in the underlying numbers.

- timestamp: 2026-07-28 (continuation session, residual)
  checked: >
    Rows of a NOT-calibrated cause are never touched by the shrinkage (it writes only
    `[keep,keep]`) and never calibrated, so they are the raw CHAMPS prior. Pushed the payload's
    four such rows through R's Input-panel recipe (no mask, round, absorb-into-max) and compared
    against R's published Input panel. Script `<scratch>/residual2.R` TEST D.
  found: >
    23 of 24 raw-prior cells reproduce R's Input panel **EXACTLY**: eava `other`
    (7 22 24 18 9 20 — including the absorption-derived 24), insilicova `congenital_malformation`
    (4 10 14 16 22 34) and insilicova `other` (4 14 14 19 12 37) are all byte-exact. The one
    exception is interva `other` -> pneumonia, which needs 0.081pp — the same magnitude as the
    calibrated-block residual.
  implication: >
    The shipped CHAMPS prior is not wholesale different between the two runs. But the SAME ~0.08pp
    discrepancy appears in a cell that no calibration step ever touches, which means the residual is
    already present in the input numbers, upstream of the misclassification-matrix machinery
    entirely. It is not produced by anything the dashboard does.

- timestamp: 2026-07-28 (continuation session, residual)
  checked: >
    Whether the payload's own 4-decimal rounding could account for it. Monte Carlo: perturb every
    served value by +-0.00005 and remeasure the masked+renormalized cells (20000 draws x 3
    algorithms). Script `<scratch>/residual2.R` TEST E.
  found: Max displacement of any cell is 0.0144pp. Required: up to 0.269pp — 19x larger.
  implication: Serving precision is excluded as the cause.

- timestamp: 2026-07-28 (continuation session, parameter hygiene)
  checked: >
    vacalibration 2.2's argument list against `backend/jobs/processor.R:169-180`, from the CRAN
    2.2 manual (`<scratch>/vacal_cran.txt`).
  found: >
    **`stable` DOES NOT EXIST in 2.2 — it was renamed `path_correction`** (default TRUE:
    "Setting TRUE shrinks misclassification matrix towards the identity matrix to improve
    stability in VA-Calibration"), and `pss` became `pshrink_strength` ("Only used when
    path_correction=FALSE. pshrink_strength is set to 0 when path_correction=TRUE. Defaults to 4
    when path_correction=FALSE") — identical semantics to 2.0's `if (stable) pss = 0 else pss = 4`.
    2.2 returns `lambda_calibpath`, the per-algorithm degree of shrinkage. The dashboard passes
    `va_data, age_group, country, missmat_type, ensemble, nMCMC, nBurn, nThin, verbose` and does
    NOT pass `path_correction`, `donotcalib`, `donotcalib_type`, `nocalib.threshold`,
    `pshrink_strength`, `studycause_map` or `seed`. Also `nBurn` is defaulted to 2000L at
    `processor.R:163` where the package default is 5000.
  implication: >
    Parameter-hygiene finding, independent of the residual. Reported, not changed.

## Current Focus

status: >
  root cause CONFIRMED and fixed for all three algorithms. Residual BOUNDED at <=0.269pp and
  localized to the input numbers; the coordinator's `stable` lead REFUTED. See
  "Residual investigation" for the conclusion.

reasoning_checkpoint:
  hypothesis: >
    `extract_misclass_matrix()` -> `normalize_mmat()` row-normalizes `Mmat_tomodel` over ALL broad
    causes and emits every row/column. vacalibration calibrates only the SUBMATRIX of calibrated
    causes: `donotcalib` (which `vacalibration()` defaults to "other", and the dashboard never
    overrides) PLUS, under `donotcalib_type = "learn"` (the default), additional per-algorithm
    causes whose misclassification column is near-constant (`diff(range(col)) <= nocalib.threshold`).
    Keeping the excluded causes' mass in the denominator deflates every displayed probability by
    `1 / (1 - sum(excluded entries in that row))`, and renders extra rows/columns that carry
    non-calibration (input) values.
  confirming_evidence:
    - "Masking the excluded causes and renormalizing the served payload reproduces R's 'Used For
       Calibration' panel for ALL THREE algorithms; worst cell deviation 0.77 percentage points,
       i.e. within R's own display rounding. Current served values deviate by up to 9.3pp
       (interva congenital_malformation diagonal: served 48.74 vs R 58)."
    - "Read directly off the rendered R reference (<scratch>/Rpage-1.png), the excluded set is
       PER-ALGORITHM, not a global 'other': eava and interva grey out only `other`, while
       insilicova greys out BOTH `congenital_malformation` AND `other` (row + column)."
    - "The live payload's CSMF confirms the same per-algorithm sets independently: exactly those
       causes are passed through untouched (calibrated == uncalibrated with a degenerate CI) —
       eava/interva/ensemble: {other}; insilicova: {congenital_malformation, other}."
    - "The dashboard's insilicova congenital_malformation row (3.89 10.02 14.45 16.34 21.78 33.52)
       equals R's INPUT panel row (4 10 14 16 22 34) — it is leftover input data, not a
       calibration quantity, exactly as for the `other` rows."
  falsification_test: >
    If the recipe were wrong, masking + renormalizing would NOT land on R's integers. It does, on
    15 of 15 eava/interva calibrated rows and 4 of 4 insilicova ones (worst 0.77pp). A competing
    recipe (drop `other` WITHOUT renormalizing) misses R by up to 1.5pp on more cells and leaves
    rows summing to 97.8 instead of 100 — refuted.
  fix_rationale: >
    Root cause is the normalization DENOMINATOR and the emitted cause set, not the field read
    (`Mmat_tomodel` is correct) nor the frontend (render is faithful). Restricting to the
    calibrated submatrix BEFORE row-normalizing is exactly `modular.vacalib`'s own plot recipe
    (subset -> rowSums -> blank), so the dashboard and R compute the same quantity by construction.
  blind_spots:
    - "SUPERSEDED by the continuation session: the residual is <=0.269pp (not 0.77pp), the
       lambda-shrinkage / stable / path_correction explanation is REFUTED, and a wholesale
       CHAMPS-prior difference is excluded on 23 of 24 never-shrunk cells. What remains
       unattributed is a <=0.269pp per-cell difference already present in the input numbers.
       See 'Residual investigation' -> conclusion."
    - "vacalibration 2.2 could not be executed here (local library is 2.0; the backend cannot boot
       without DBI/RPostgres). 2.2 behaviour is established from the CRAN 2.2 manual plus the live
       payload's shape, not from a local run."
    - "Whether 2.2's `donotcalib_tomodel` keeps per-algorithm rows or collapses to the ensemble
       intersection when ensemble=TRUE is NOT determinable from the docs. The fix is written so
       either behaviour yields the correct per-algorithm mask."

next_action: >
  DONE. Fix applied and verified (see Resolution). Continuation session now isolating the
  residual <=0.77pp only. See "Residual investigation" below.

## Residual investigation (continuation session)

hypothesis_R1: >
  The residual is NOT a flat 0.77pp disagreement spread over cells. R's display pipeline
  (modular_vacalib_2.0.R:1237-1245) rounds every cell to an integer FIRST and then overwrites the
  row's largest cell with `100 - sum(rounded others)`. That makes the printed diagonal a FUNCTION of
  the other cells' rounding decisions, so a sub-0.2pp difference in one off-diagonal cell that sits
  near a .5 boundary flips that cell by 1 AND flips the diagonal by 1 in the opposite direction.
  Predicted signature: disagreements come in +1/-1 PAIRS within a row, with the off-diagonal member
  sitting within ~0.2pp of a .5 boundary.
test_R1: >
  Reimplement R's exact display recipe (mask -> rownorm -> round -> absorb-into-max -> blank) on the
  live payload for all 3 algorithms and diff against R's published integers cell by cell. Then, for
  every disagreeing cell, compute the distance from the nearest .5 rounding boundary.
expecting_R1: >
  If true: every disagreement is a within-row +1/-1 pair, and the non-diagonal member of each pair is
  within ~0.2pp of x.5. If false (isolated disagreements >1, or off-boundary cells): a genuine
  parameter/version divergence (stable, path_correction, CHAMPS prior) is in play.

hypothesis_R2: >
  Coordinator's lead: `stable` diverges (dashboard silently TRUE via upstream default,
  Sandi's run FALSE), inferred from Sandi's PDF titles lacking 2.0's `" (Adjusted)"` /
  `" (Estimated from CHAMPS Data)"` suffixes.
test_R2: >
  Establish whether 2.2 still appends those suffixes under `stable=TRUE`. 2.2's documented Value
  section restructured the Mmat fields (Mmat_input/Mmat_study/Mmat_tomodel) and added
  `path_correction`, so 2.0's title logic cannot be assumed to carry over.
expecting_R2: >
  Lead survives only if 2.2 is confirmed to append a stable-marker to the plot title. If 2.2's title
  block was restructured (subtitles "Input"/"Used For Calibration" exist in Sandi's PDF but NOT in
  2.0), the title is 2.2-specific and carries no information about `stable`. Say so plainly.

result_R1: CONFIRMED. Residual is <=0.269pp; 43 of 52 informative cells exact; 16 visible integer
  differences reduce to 9 sub-0.27pp cell differences amplified by round + absorb-into-max.
result_R2: >
  REFUTED, decisively. `stable` does not even exist in 2.2 — renamed `path_correction`
  (default TRUE). And the shrinkage is demonstrably PRESENT in Sandi's run: fitting it from her own
  two panels gives lambda = 0.391 (eava) / 0.294 (interva) / 0.290 (insilicova), self-consistent
  across every row of each algorithm. With it OFF she would have printed 44 / 41 / 26 for the three
  diagonals she actually printed as 65 / 58 / 47. Separately, no scalar shrinkage difference of any
  size can produce the observed pattern (TEST B: infeasible within single rows, both directions
  required). The title-suffix inference is void: 2.0 emits no subtitle at all, so 2.2 restructured
  the title block and its suffix behaviour cannot be inferred from 2.0.

conclusion: >
  **The residual is bounded and localized, but its cause cannot be attributed with the evidence
  available here — and that is a resolution-of-evidence limit, not a missing investigation.**
  Every reference number from R is an INTEGER (0 decimal places), so R-side evidence has resolution
  +-0.5pp while the residual is <=0.269pp. The only reason it is visible at all is R's
  absorb-into-max step, which amplifies a sub-0.5pp cell difference into a +-1 integer.
  What IS established: it is not the normalization recipe (fixed), not the field read, not the
  frontend, not serving precision (19x too small), not `stable`/`path_correction`, not the lambda
  grid, and not a wholesale CHAMPS-prior revision. It is already present in cells that no
  calibration step touches, i.e. upstream of everything the dashboard does.
  The one thing that would settle it: install vacalibration 2.2 in an environment that can run it
  and diff the arrays directly against the stored payload —
  `Rscript -e 'library(vacalibration); data(comsamoz_CCVAoutput); o <- vacalibration(va_data=list(eava=..., insilicova=..., interva=...), age_group="neonate", country="Mozambique", ensemble=TRUE, verbose=FALSE); print(round(100*o$Mmat_tomodel,3)); print(o$lambda_calibpath)'`
  — using job 901322df's exact uploaded input. Local execution is impossible (library is 2.0;
  backend cannot boot without DBI/RPostgres) and the cluster/DB are unreachable.

next_action: >
  None for the residual — it is below the resolution of the available evidence and further work here
  would be speculation. Await the human-verify checkpoint response. Do NOT commit.

## Eliminated

- hypothesis: The frontend React matrix table reorders or mangles the values.
  evidence: The API's `congenital_malformation` row reordered into `cause_order` is exactly the row
    printed in `neonate-dash.pdf` (15, 17, 3, 13, 4, 49). The render is faithful; the payload is wrong.
  timestamp: 2026-07-28

- hypothesis: The dashboard reads the wrong field and is showing the "Input" matrix
    (`Mmat.asDirich_input`) instead of the calibration matrix.
  evidence: R's Input panel InterVA cm row is (32, 5, 4, 22, 21, 16); the dashboard serves
    (48.74, 3.90, 2.77, 16.86, 14.99, 12.74), which renormalizes to R's *Used For Calibration* row
    (58, 4, 3, 20, --, 15), not to the Input row. It is reading the right field and normalizing it
    the wrong way. (Only the `other` ROW happens to coincide with Input.)
  timestamp: 2026-07-28

- hypothesis: The CSMF / `pcalib_postsumm` handling is also wrong.
  evidence: The dashboard's CSMF table matches R's CSMF bar chart per algorithm (e.g. InterVA
    calibrated sepsis 47% (32-70) vs R's ~0.47 bar with CI ~0.31-0.72; prematurity 35% (13-51) vs
    R's ~0.36 bar). `build_per_algorithm()` reads `pcalib_postsumm[label, "postmean"/"lowcredI"/
    "upcredI", ]` correctly. Sandi's complaint mentions csmf figures only as "similar-looking",
    i.e. a presentation ask, not a numeric one.
  timestamp: 2026-07-28

- hypothesis: A wrong country stratum was used (which would select the wrong CHAMPS matrix).
  evidence: Job 901322df ran country=Mozambique, and the R reference PDF's numbers for the
    calibrated rows reproduce under the masked recipe. Same stratum.
  timestamp: 2026-07-28

## Notes for the fix

- **Do not hardcode `"other"`** if 2.2 exposes `donotcalib` / `causes_notcalibrated`; read it from
  the result so a future `donotcalib` argument cannot silently desync the display. Hardcoding is an
  acceptable fallback ONLY if 2.2 dropped those fields — and then it must be commented as tracking
  `vacalibration()`'s `if (is.null(donotcalib)) donotcalib = "other"` default.
- Per CLAUDE.md ("write a unit test for each edge case BEFORE implementing"), the boundary cases to
  test are: (a) all causes calibrated -> matrix unchanged; (b) `other` excluded -> rows renormalize
  over the remaining 5 and the excluded row/column are blank; (c) more than one excluded cause;
  (d) a row that sums to 0 after masking -> no division by zero; (e) 2D single-algorithm input;
  (f) 3D multi-algorithm input; (g) numeric regression pinned to R's published InterVA/EAVA/
  InSilicoVA values for job 901322df.
- Downstream consumers of the same data must stay consistent: the per-algorithm
  `misclass_matrix_<algo>.csv` files written by `backend/jobs/processor.R:225-240`, the JSON
  `misclassification_matrix` at `:269-278`, and the frontend CSV/PNG/PDF export buttons.
- Second defect (cause labels): the matrix header truncation makes "Neonatal sepsis" and
  "Neonatal pneumonia" both read `Neonatal..`. Any fix must keep the two distinguishable — that
  is the concrete part of "the cause names appear weird".
- Items 2 (preview-step clutter) and 3 (per-algorithm progress bars) from issue #104 are UI/feature
  work, NOT part of this debug session.

## Resolution

root_cause: >
  `extract_misclass_matrix()` fed the whole 6-cause `Mmat_tomodel` to
  `normalize_mmat()`, which row-normalized over ALL broad causes and emitted every row and column.
  vacalibration calibrates only the submatrix of CALIBRATED causes: `donotcalib` (which
  `vacalibration()` defaults to "other" and the dashboard never overrides) plus, under
  `donotcalib_type = "learn"` (the default), additional PER-ALGORITHM causes whose misclassification
  column is near-constant. Its own "Used For Calibration" panel subsets first and then
  row-normalizes over that submatrix. Keeping the excluded causes' mass in the denominator deflated
  every displayed probability by `1 / (1 - excluded mass)` — up to 9.3pp (interva
  congenital_malformation diagonal served 48.74 where R prints 58) — and rendered extra rows that
  carry INPUT data rather than any calibration quantity. For job 901322df the excluded sets are
  eava {other}, interva {other}, insilicova {congenital_malformation, other}.

  Second, independent defect: `formatCauseShort()` truncated column headers at a fixed offset
  (`substring(0, 8) + '..'`), rendering both "Neonatal sepsis" and "Neonatal pneumonia" as
  `Neonatal..` — two different columns with identical headers.

fix: >
  backend/jobs/utils.R — added `not_calibrated_causes()` plus helpers
  `.declared_not_calibrated()` / `.passthrough_not_calibrated()`, which resolve the per-algorithm
  excluded set by UNIONing every version's declaration field (`donotcalib_tomodel`,
  `donotcalib_study`, `donotcalib` and `causes_notcalibrated`) with a version-independent read-out
  of the calibration itself (a not-calibrated cause is passed through, so its calibrated CSMF
  equals its uncalibrated CSMF with a degenerate credible interval). `normalize_mmat()` gained a
  `not_calibrated` argument and now drops those causes from BOTH axes BEFORE row-normalizing.
  `extract_misclass_matrix()` builds each algorithm's entry separately (slices legitimately differ
  in size now) and reports the excluded causes in a new `not_calibrated` field. Excluded cells are
  DROPPED, not emitted as NA, because db/connection.R serializes without `na = "null"` and an NA
  would reach the client as the string "NA".

  frontend/src/components/MisclassificationMatrix.jsx — replaced fixed-offset truncation with
  `shortenUnique()`, which grows the character budget until every header is distinguishable and
  falls back to untruncated names rather than render an ambiguous row; added a note listing the
  not-calibrated causes (handling `not_calibrated` arriving either as an array or, when it holds a
  single cause, as an auto-unboxed bare string).

verification: >
  Continuation session added 3 assertions (46 -> 49, all green) encoding the tight residual bound:
  for every cell R actually ROUNDED (i.e. excluding the one cell per row R re-derives as
  `100 - sum(rounded others)`), our value must lie within 0.3pp of the interval R's printed integer
  implies. Verified non-vacuous by negative control: at 0.2pp it fails on exactly the two cells the
  independent analysis flagged (interva sepsis->ipre 26.260 needing [26.5,27.5), insilicova
  pneumonia->ipre 23.770 needing [22.5,23.5)). This replaces the old 1.0pp-only guard, which would
  have let a 0.9pp regression pass. No production code changed in the continuation session.

  New pure-unit suite tests/test_misclass_matrix.R: 26 of 46 assertions RED before the fix
  (including "interva congenital_malformation diagonal got 48.74 want 58"), 46/46 GREEN after.
  Covers all boundary cases from Notes for the fix: (a) all calibrated, (b) one excluded,
  (c) two excluded, (d) zero row after masking (no NaN), (e) 2D single-algorithm, (f) 3D
  multi-algorithm with differing per-algorithm masks, (g) numeric regression pinned to R's
  published integers for job 901322df — all three algorithms agree within 1.0pp (worst observed
  0.77pp) — plus per-version field names, the ensemble-collapsed-declaration case, and
  serialization safety (no NA/NaN reaches the JSON).
  New frontend suite MisclassificationMatrix.issue104.behavior.test.jsx: 7 of 10 RED before the
  fix, 10/10 GREEN after.
  No regressions: the 17 pre-existing `normalize_mmat` / `extract_misclass_matrix` assertions from
  sections 14 and 14b of tests/test_vacalibration_backend.R all pass, and the frontend suite is
  249 passed / 0 failed. (tests/test_vacalibration_backend.R cannot run end to end here — it dies
  at section 2b on `comsamoz_CCVAoutput` missing from the local vacalibration 2.0, and
  src/api/integration.test.js cannot start the backend because DBI/RPostgres are absent. Both
  failures were confirmed identical with the fix stashed, i.e. pre-existing environment limits.)
  Full serialization path re-simulated (toJSON -> JSONB -> fromJSON -> plumber): the client
  receives `matrix` as an array of arrays, `not_calibrated` as an array for insilicova and as the
  bare string "other" for eava/interva.

files_changed:
  - backend/jobs/utils.R                                                    # root-cause fix
  - frontend/src/components/MisclassificationMatrix.jsx                     # header ambiguity + note
  - frontend/src/App.css                                                    # .matrix-not-calibrated
  - tests/test_misclass_matrix.R                                            # new, 46 assertions
  - frontend/src/components/MisclassificationMatrix.issue104.behavior.test.jsx  # new, 10 assertions

deployment: >
  **A redeploy IS required, and it is not sufficient on its own.** The matrix is computed
  server-side at job-processing time and frozen in the `jobs.result` JSONB: `/jobs/<id>/results`
  returns `job$result` verbatim (backend/plumber.R:470-487) after `load_job()` parses the stored
  JSONB (backend/db/connection.R:210-235). Nothing is recomputed on read. So job
  901322df-0361-4795-aa0f-d8765401eb50 will keep serving the wrong numbers even after the deploy —
  the job must be re-run (or its stored result back-filled) for Sandi to see the corrected matrix.

out_of_scope: >
  Items 2 (preview-step clutter) and 3 (per-algorithm progress bars) of issue #104 are UI/feature
  requests and were deliberately not touched.

## Residual RESOLVED — orchestrator, vacalibration 2.2 source obtained (2026-07-28)

The two continuation sessions both reasoned about 2.2 from the CRAN *manual*. The **source** is
public and downloadable, which settles everything that was previously "not determinable from the
docs":

```
curl -sL https://cran.r-project.org/src/contrib/vacalibration_2.2.tar.gz | tar xz
```
Extracted to `<scratch>/vacalibration/` (Version 2.2, Packaged 2026-03-20). 5880 lines of R.

**1. There is NO version gap. Sandi ran 2.2 — the same version the backend runs.**
`plot_vacalib_prior.R:395-407` emits the exact strings on her PDF:
`title = "Prior Mean of Misclassification Matrix"` with `subtitle = "Input"` / `"Study-Specific"` /
`"Used For Calibration"`. vacalibration 2.0 has no subtitles at all. Her panels are 2.2's.

**2. The `stable` lead is dead, confirmed a fourth way (independent of the λ-fit argument).**
`grep -rn '\bstable\b' vacalibration/R/` returns **nothing** — the argument does not exist in 2.2.
It was renamed **`path_correction`** (default `TRUE`), with `pss` → `pshrink_strength`
(`vacalibration.R:97-109`). Both runs therefore had the shrinkage ON, since neither passes it.
The `" (Adjusted)"` title-suffix logic that drove the inference was removed in 2.2 entirely.

**3. The fix's recipe is BYTE-FOR-BYTE upstream's own.** `plot_vacalib_prior.R:216-230`:
```r
Mmat_toplot_tomodel[k,,] = diag(dim(Mmat_toplot_tomodel)[2])
Mmat_toplot_tomodel[k,!donotcalib_tomodel[k,],!donotcalib_tomodel[k,]] =
  do.call("rbind", lapply(which(!donotcalib_tomodel[k,]), function(i)
    smart_round(x = 100*(Mmat_tomodel[k,i,!donotcalib_tomodel[k,]] /
                         sum(Mmat_tomodel[k,i,!donotcalib_tomodel[k,]])),
                target_sum = 100, digits = 0)))
Mmat_toplot_tomodel[k,donotcalib_tomodel[k,],] =
  Mmat_toplot_tomodel[k,,donotcalib_tomodel[k,]] = NA
```
Mask `!donotcalib_tomodel` on BOTH axes -> renormalize over the submatrix -> blank the excluded
row/column. That is exactly what the fix now does, and it confirms `donotcalib_tomodel` is the
correct 2.2 field name (which the fix reads). No change to the fix is warranted.

**4. R's display rounding is `smart_round`, not round-then-absorb-max.** `smart_round.R` is a
largest-remainder (Hamilton) apportionment: floor all, then +1 to the largest remainders until the
target sum is hit. Both prior continuation analyses modelled 2.0's absorb-into-max instead. Running
2.2's actual `smart_round` on the fixed values (`<scratch>/verify_smartround.R`) reproduces
Sandi's published integers **exactly on 8 of the 14 calibrated rows**; the other 6 differ only by
±1 shuffled between adjacent cells, the signature of a sub-integer difference tipping the
allocation. 66 cells compared, 14 differ by 1, none by more.

**5. ROOT CAUSE OF THE RESIDUAL: `Mmat_tomodel` is not reproducible in vacalibration 2.2.**
`modular_vacalib_prior.R:320-330` draws `nSamp_approx = 1000` Dirichlet samples via
`LaplacesDemon::rdirichlet()`, and their average feeds the λ search that produces `Mmat_tomodel`
(`:337-383`, λ stepped down from .99 in **0.01 increments** until the implied uncalibrated CSMF
re-enters the simplex). Those draws use R's **global RNG**, and:
```
grep -rn 'set.seed' vacalibration/R/   ->   NO MATCHES ANYWHERE IN THE PACKAGE
```
The `seed` argument is only forwarded to Stan's sampler (`:478`, `:773`), which seeds Stan's
internal RNG, not R's. So the λ fit — and therefore every cell of `Mmat_tomodel` — varies
run-to-run for identical inputs.
Quantified (`<scratch>` R one-liner): recovering `Mmat_study` from the served row and re-applying
neighbouring λ grid points gives, for interva `congenital_malformation`,
λ=0.294 -> `57 5 3 20 15` but λ=0.304 -> `58 5 3 19 15`. **A single 0.01 λ step flips the diagonal
57->58, exactly Sandi's published value.** Magnitude and mechanism both match the ≤0.3pp residual.

Conclusion: the residual is UPSTREAM NON-DETERMINISM, not a dashboard defect and not a
normalization error. The applied fix is correct and needs no change. The tolerance-based numeric
regression test (`R_CELL_TOL <- 0.3`) is the right design — an exact-match test against R's
integers would be flaky by construction.

### Consequences worth acting on separately (NOT changed here)

- **Dashboard results are not reproducible.** Re-running job `901322df` will NOT reproduce Sandi's
  exact integers either — expect ±1 on some cells regardless. Plan the back-fill/re-run
  conversation with her accordingly; "the numbers still differ by 1" is expected, not a regression.
- **Passing `seed` explicitly would NOT fix this**, because vacalibration ignores it for these
  draws. The only local remedy is `set.seed(<n>)` in `run_vacalibration()` immediately before the
  `vacalibration()` call. That is a behaviour change and is the user's decision.
- **This is an upstream bug in vacalibration 2.2, authored by the reporter of issue #104**
  (sandy-pramanik). Worth telling her directly: the documented `seed` parameter does not make
  `Mmat_tomodel` / `lambda_calibpath` reproducible.
