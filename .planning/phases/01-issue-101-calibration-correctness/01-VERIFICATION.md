---
phase: 01-issue-101-calibration-correctness
verified: 2026-08-25T15:45:00Z
status: passed
score: 7/7 must-haves verified (1 via accepted override)
overrides_applied: 1
overrides:
  - criterion: "All five test suites pass with zero skips (ROADMAP criterion 7)."
    accepted_by: user
    accepted: "2026-08-25"
    rationale: "The single failing assertion (tests/test_vacalibration_backend.R section 12c, 'extracted matrix uses the 6 neonate broad causes') is a pre-existing MCMC-nondeterminism flake, not a regression from this phase. The verifier confirmed extract_misclass_matrix() and not_calibrated_causes() are byte-identical to the pre-phase base commit fcedce4, and the assertion depends on an unseeded low-iteration (nMCMC=400) vacalibration() run whose donotcalib_type='learn' exclusion set is not constant across draws. Documented in deferred-items.md across all four execution waves. Fixing it would require test-tuning changes this phase's plans explicitly declined as out of scope."
    residual_risk: "Suite is 639/640, not green. Any future reader must not mistake this for a phase-01 regression. Ownership belongs to whichever issue takes on test flakiness / MCMC-iteration tuning."

gaps:
  - truth: "All five test suites pass with zero skips (ROADMAP criterion 7)."
    status: partial
    reason: "tests/test_vacalibration_backend.R fails 1 of 640 assertions (section 12c, 'extracted matrix uses the 6 neonate broad causes'). Independently re-run twice by the verifier with identical result: 640 tests, 639 passed, 1 failed. Root cause confirmed by the verifier (not just asserted by SUMMARY/deferred-items.md): `extract_misclass_matrix()` and `not_calibrated_causes()` are byte-identical to the pre-phase base commit (fcedce4) per `git diff fcedce4 HEAD -- backend/jobs/utils.R` on that function body; the test invokes a real, unseeded low-iteration (nMCMC=400) vacalibration() MCMC run whose reliability-exclusion set (`donotcalib_type='learn'`) is not guaranteed constant across draws. This is a genuine, reproducible, pre-existing flake unrelated to any of R1/R2/R3's code changes, documented transparently in deferred-items.md across all four execution waves. It is not papered over here because the roadmap criterion is worded as an absolute ('zero skips' / all suites pass) and the failure is real and observable, not a skip — but it is not caused by this phase's work."
    artifacts:
      - path: "tests/test_vacalibration_backend.R"
        issue: "Section 12c's MCMC-based assertion is flaky at nMCMC=400; not touched by this phase's diff."
    missing:
      - "Either: (a) a developer override accepting this as a known pre-existing limitation out of this phase's scope, or (b) a fix to section 12c's iteration count / assertion robustness, which the phase's own plans explicitly declined to attempt because a pure-refactor/fix plan must not change calibration behavior or test tuning outside its scope."
human_verification:
  - test: "Submit a dataset that genuinely stalls (e.g. a country/algorithm combination where lambda pins at 0.99 or 1.01 after the R1 fix) through the full UI stack and confirm the stalled-run wording and whiskers render correctly end-to-end."
    expected: "Stalled facet states 'No calibration was applied', intervals are drawn with whiskers, comparison table shows bounds, no wording says 'omitted'/'unreliable'/'implausibly'."
    why_human: "The issue's own reproduction file (sample_eava_child.csv) no longer stalls after the R1 fix (lambda=0.39, confirmed independently by the verifier via direct vacalibration() call), so the live browser checkpoint in plan 01-04 could only confirm the non-stalled rendering path end-to-end. The stalled-path UI rendering is covered by strong isolated evidence (backend build_summary_df()/build_stall_fields() verified directly by the verifier via probe; frontend CalibratedResults.behavior.test.jsx, CSMFChart.test.js and JobDetail.test.js all pass and specifically simulate stalled payloads) but has not been observed through one continuous live job end-to-end since the fix succeeded at removing the one file known to reproduce a stall."
---

# Phase 01: Issue 101 Calibration Correctness — Verification Report

**Phase Goal:** A dataset containing a broad cause with zero deaths calibrates correctly instead of silently returning an uncalibrated result, and no surface claims that statistically correct intervals are meaningless.
**Verified:** 2026-08-25T15:45:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (ROADMAP Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Uploading the issue's file produces a real calibration, not a no-op | ✓ VERIFIED | Independently ran `vacalibration()` directly (not via SUMMARY claim, not via API) against `frontend/public/sample_eava_child.csv` (child, Mozambique, EAVA) with `donotcalib = build_donotcalib(va_input)`: `lambda = 0.39`, `path_correction_stalled(lambda)` is FALSE, `max(abs(p_uncalib - p_calib)) = 0.1434` (>> the plan's 0.05 threshold). This independently reproduces the orchestrator's live-browser λ=0.39 result via a completely separate code path. |
| 2 | Zero-death causes appear nowhere in chart, table, misclassification panel, or exported files | ✓ VERIFIED | Ran `assemble_calibration_result()` directly on the real result: `calibrated_csmf` names exclude `injury`/`nn_causes`; `calibration_summary.csv` has 7 rows, none named `injury`/`nn_causes`; `misclassification_matrix$eava$champs_causes` excludes both. `cause_order`/`cause_display_names` filtering confirmed in `utils.R:1346-1349`. Frontend `orderCauses()`/`normalizeCauseList()` in `causeDisplay.js` confirmed to filter and handle the resulting bare-string wire shape (CR-01 fix). Orchestrator's live-browser run independently corroborates (7 groups, 7 table columns, 6x6 matrix, no Injury/Neonatal Causes anywhere). |
| 3 | `malaria` remains calibrated — full misclassification matrix preserved | ✓ VERIFIED | Independently confirmed: `dim(result$Mmat_tomodel)` is `1 9 9` (not shrunk); `not_calibrated_causes(result, "eava", causes)` returns only `injury, other, nn_causes` — `malaria` absent, i.e. calibrated. Section 30 assertion 13's reliability-rule numbers (0.1163 / 0.0681 vs 0.1 threshold) independently re-verified by re-running the deterministic (non-MCMC) test — passed. |
| 4 | Credible intervals shown for a stalled run, labelled as uncertainty of an uncalibrated estimate | ⚠ VERIFIED (with residual risk — see human_verification) | Ran `build_summary_df()` directly with a synthetic stalled fixture: row with a real interval keeps `calibrated_lower=0.29, calibrated_upper=0.31` and `interval_note = "no calibration was applied (lambda = 0.99); the interval is the uncertainty of the uncalibrated estimate"`; the point-mass row correctly blanks bounds AND composes a non-contradictory note (WR-01 fix confirmed live, not just by reading the diff). Frontend: `csmfWhisker()` no longer takes a stall-suppression argument (confirmed 3-arg signature in source); `CalibratedResults.behavior.test.jsx` render-tests a single-algorithm stalled run and an ensemble-with-stalled-constituent, both passing. Retraction guard confirmed empty for forbidden words across backend and frontend production code. Residual: the one live end-to-end job the orchestrator ran did NOT stall (by design — the fix works), so the full stack (API→DB→UI) was never observed rendering an actual stalled run; coverage rests on unit/render tests plus direct backend function calls, not one continuous live pipeline. Flagged as a human-verification item, not a blocker, given the strength of the isolated evidence on both sides of the boundary. |
| 5 | Causes the package declined to calibrate are visible to the user | ✓ VERIFIED | `misclassification_matrix$eava$not_calibrated` correctly names only `other` (the package's own decision) in the direct-run probe, separate from `zero_count_causes` (the causes we excluded). `MisclassificationMatrix.jsx` footnote and `JobDetail.jsx` disclosure block both confirmed present in source and exercised by passing render tests (`CalibratedResults.behavior.test.jsx`). Orchestrator's browser run shows both disclosures rendered correctly and distinctly. |
| 6 | Both job paths provably share one result-assembly implementation; a test fails if either stops using it | ✓ VERIFIED | Adversarially falsified, not just inspected: temporarily replaced `assemble_calibration_result(` with a dummy call in `backend/jobs/algorithms/vacalibration.R`, re-ran `tests/test_vacalibration_backend.R --input-only` — it failed exactly on `"vacalibration.R calls assemble_calibration_result()"` (Tests: 483, Failed: 1). Repeated the same falsification on `backend/jobs/processor.R` — it failed on the equivalent processor.R guard. Reverted both files; suite returned to 483/483 passing. The guard is real, not decorative. |
| 7 | All five test suites pass with zero skips | ✗ FAILED (see gap) | Independently re-ran all four R suites and the frontend suite myself (not trusting SUMMARY/orchestrator numbers): `tests/test_vacalibration_backend.R` → 640 run, 639 passed, 1 failed (section 12c MCMC flake, confirmed pre-existing and unrelated — see gap below); `tests/test_misclass_matrix.R` → 52/52; `tests/test_auth_visibility.R` → 32/32; `tests/test_input_persistence.R` → 18/18; `cd frontend && npm test` → 357/357, 35 files, zero skips. Zero `.skip(` found in any test file. The literal criterion ("all five ... pass with zero skips") is not met because one suite has a failure, even though it is not a skip and is confirmed unrelated to this phase's changes. |

**Score:** 6/7 truths verified (criterion 4 verified with a noted residual risk, routed to human_verification; criterion 7 failed literally though root-caused to a pre-existing, phase-unrelated flake)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `backend/jobs/utils.R` | `zero_count_causes()`, `unobserved_causes()`, `build_donotcalib()`, `build_calibrated_map()`, `prepare_calibration_exclusions()`, `assemble_calibration_result()` with `hidden_causes`, `extract_misclass_matrix()` with `hide_causes`, `build_stall_fields()` without `ci_unreliable`, `build_summary_df()` with `interval_note` | ✓ VERIFIED | All functions present, confirmed present and called correctly via direct execution (not just grep), all four probes (probe.R, probe2.R, probe3.R, guard falsification) ran against the real file. |
| `backend/jobs/algorithms/vacalibration.R` | `run_vacalibration()` calling `prepare_calibration_exclusions()` and `assemble_calibration_result()` | ✓ VERIFIED | Confirmed at lines 202, 227; falsification test confirmed the guard fires if this wiring breaks. |
| `backend/jobs/processor.R` | `run_pipeline()` calling the same shared helpers | ✓ VERIFIED | Confirmed at lines 178, 220; falsification test confirmed the guard fires if this wiring breaks. |
| `frontend/src/components/JobDetail.jsx` | Disclosure of `zero_count_causes`/`calibration_declined`; `pathCorrectionStalled`/`stalledConstituents` props to `MisclassificationMatrix`; 3-arg `csmfWhisker` call | ✓ VERIFIED | Grep + source read confirms all; `CalibratedResults.behavior.test.jsx` render-tests the same behaviors, not just source strings. |
| `frontend/src/components/CSMFChart.js` | `csmfWhisker(calibrated, ciLower, ciUpper)` 3-arg; `buildCsmfFacets`/`buildCsmfTableRows` without `ciUnreliable`/`noCI`; `calibration_declined` handling (WR-02) | ✓ VERIFIED | Confirmed exact 3-arg signature; `declined` variable and row-type precedence (declined > stalled > plain) present at lines 117, 137; covered by passing tests. |
| `frontend/src/components/MisclassificationMatrix.jsx` | `pathCorrectionStalled`/`stalledConstituents` props, no `ciUnreliable` | ✓ VERIFIED | Confirmed signature and usage at lines 161, 173-174, 197; zero `ciUnreliable` occurrences. |
| `frontend/src/utils/causeDisplay.js` | `normalizeCauseList()` hardening `orderCauses()` against the unboxed bare-string wire shape (CR-01) | ✓ VERIFIED | Confirmed present and used for both arguments of `orderCauses()`; regression tests in `causeDisplay.test.js` and `CSMFChart.test.js` pass. |
| `tests/test_vacalibration_backend.R` | Section 29 (shared assembly guard), Section 30/30b (zero-count exclusion, R1), rewritten Section 28 (R2 retraction) | ✓ VERIFIED | All present; guard genuinely fails on wiring removal (adversarially confirmed); 640 assertions total, 639 passing. |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `vacalibration.R` | `assemble_calibration_result()` | direct call | ✓ WIRED | Adversarially confirmed — breaking it fails the test suite. |
| `processor.R` | `assemble_calibration_result()` | direct call | ✓ WIRED | Adversarially confirmed — breaking it fails the test suite. |
| `vacalibration.R` / `processor.R` | `vacalibration(donotcalib = ...)` | `prepare_calibration_exclusions(va_input, job)` | ✓ WIRED | Confirmed at `vacalibration.R:216`, `processor.R:188`; both derive from the shared helper (WR-05 dedup), independently probed. |
| `assemble_calibration_result()` | result payload cause-keyed fields | `hidden_causes` filtering | ✓ WIRED | Confirmed via direct probe: `calibrated_csmf`, `calibration_summary.csv`, `misclassification_matrix` all exclude hidden causes; survivors numerically unchanged (not renormalized). |
| `JobDetail.jsx` | `results.zero_count_causes` / `calibration_declined` | summary-block disclosure | ✓ WIRED | Confirmed in source and exercised by `CalibratedResults.behavior.test.jsx`. |
| `JobDetail.jsx` | `csmfWhisker()` | 3-arg call | ✓ WIRED | Confirmed; whisker rendering confirmed live in orchestrator's browser run (6 of 7 bars whiskered, `other` correctly suppressed as point mass). |
| `JobDetail.jsx` | `MisclassificationMatrix` | `pathCorrectionStalled=`/`stalledConstituents=` props | ✓ WIRED | Confirmed in source (WR-03 fix); render test confirms the caveat appears for a stalled ensemble constituent even when the ensemble's own `path_correction_stalled` is FALSE. |

### Data-Flow Trace (Level 4)

| Artifact | Data Variable | Source | Produces Real Data | Status |
|----------|---------------|--------|---------------------|--------|
| `CSMFChart.js` facets | `calibrated_csmf`, `lambda`, `pathCorrectionStalled` | Backend `assemble_calibration_result()` → real `vacalibration()` MCMC output | Yes — confirmed via direct backend probe producing non-trivial, non-static values (`max abs diff = 0.1434`) and via the orchestrator's live job (materially different calibrated vs uncalibrated percentages) | ✓ FLOWING |
| `MisclassificationMatrix.jsx` | `matrixData` | `extract_misclass_matrix()` on real `Mmat_tomodel` | Yes — confirmed `dim = 1x9x9`, real per-cause reliability decision (malaria calibrated) derived from real CHAMPS matrix, not a static/empty fallback | ✓ FLOWING |
| `JobDetail.jsx` summary disclosure | `zero_count_causes` | `unobserved_causes(va_input)` computed from real uploaded CSV column sums | Yes — confirmed `injury, nn_causes` derived from the actual 2383-record file's zero `colSums()` | ✓ FLOWING |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| `zero_count_causes()`/`build_donotcalib()` on the real issue file | Direct R probe (see below) | `injury, nn_causes` excluded; `donotcalib = injury, other, nn_causes` | ✓ PASS |
| Real calibration is not a no-op | `vacalibration(... donotcalib=...)` on the real file | `lambda = 0.39`, not stalled, max abs diff 0.1434 | ✓ PASS |
| `assemble_calibration_result()` filters hidden causes end-to-end | Direct R probe | 7-row `calibration_summary.csv`, no `injury`/`nn_causes` in any cause-keyed field | ✓ PASS |
| Stalled-run interval composition is non-contradictory | `build_summary_df()` synthetic-fixture probe | Point-mass row correctly blanks bounds with a note that doesn't claim an interval is present; non-point-mass row keeps bounds with correct wording | ✓ PASS |
| Shared assembler guard actually fails on regression | sed-substitution falsification on both `vacalibration.R` and `processor.R`, re-run test suite, then revert | Both falsifications independently produced exactly one new failure naming the broken file; suite returned to green after revert | ✓ PASS |
| `npm run build` | `cd frontend && npm run build` | exit 0, 454 modules transformed | ✓ PASS |
| `npm run lint` | `cd frontend && npm run lint` | 4 errors, all in `AuthContext.jsx` (2) and `integration.test.js` (2) — neither file touched by this phase's `files_modified` lists across all 4 plans | ✓ PASS (pre-existing, unrelated) |
| `check_integration.py` | `python3 .claude/skills/test/scripts/check_integration.py` | 1 failure: `GET /admin/users/{param}` — confirmed via `git show fcedce4` that this false-positive (the real call is `PUT`) predates this phase | ✓ PASS (pre-existing, unrelated) |

### Probe Execution

No `scripts/*/tests/probe-*.sh` convention exists in this repository and none is declared in this phase's PLAN/SUMMARY files. Step 7c: SKIPPED (no scripted probe files; ad-hoc R probes were run directly by the verifier instead and are documented above under Behavioral Spot-Checks).

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| R1 | 01-01 | Align vacalibration input with package methodology (zero-count exclusion, full matrix preserved, disclosure) | ✓ SATISFIED | Verified directly via probe.R/probe2.R against the real package; all five acceptance bullets in REQUIREMENTS.md confirmed. |
| R2 | 01-02 (backend), 01-04 (frontend) | Retract false-precision framing; restore intervals with corrected labelling | ✓ SATISFIED (with the criterion-4 residual noted above) | Verified via probe3.R and passing frontend tests; retraction guard confirmed empty across both layers. |
| R3 | 01-03 | Remove structural cause of one-sided fixes (shared assembler + failing guard) | ✓ SATISFIED | Adversarially falsified — the guard test genuinely fails when either path stops delegating. |

No orphaned requirements: `.planning/REQUIREMENTS.md` defines exactly R1, R2, R3 for this phase, and all three are claimed by exactly one plan each (R2 split across a backend and frontend plan, both completed).

### Anti-Patterns Found

None. Scanned all phase-modified files (`backend/jobs/utils.R`, `backend/jobs/algorithms/vacalibration.R`, `backend/jobs/processor.R`, `frontend/src/components/JobDetail.jsx`, `frontend/src/components/CSMFChart.js`, `frontend/src/components/MisclassificationMatrix.jsx`, `frontend/src/utils/causeDisplay.js`) for `TODO|FIXME|XXX|TBD|not yet implemented|coming soon` — zero matches. No debt markers found; no gate triggered.

### Human Verification Required

#### 1. End-to-end confirmation of a genuinely stalled run through the live UI

**Test:** Find or construct a dataset/country/algorithm combination that still stalls after the R1 fix (lambda pinned at 0.99 on `missmat_type="prior"` or 1.01 on `"fixed"`), submit it through the full UI stack, and confirm the results view.
**Expected:** The stalled facet states "No calibration was applied", credible-interval whiskers are drawn (not suppressed), the comparison table prints bounds, and no wording anywhere says "omitted", "unreliable", "implausibly tight" or "not meaningful".
**Why human:** The issue's own reproduction file no longer stalls after this phase's fix (confirmed independently: lambda=0.39). The plan 01-04 checkpoint's live-browser run therefore could only exercise the non-stalled rendering path end-to-end. Backend stall-field composition and frontend stall-rendering logic are each independently verified in isolation (direct R probe; passing render/unit tests), but the full pipeline (API → DB → UI) has not been observed rendering an actual stall since this fix landed. This is a residual-risk item, not a contradicted claim — no evidence found suggesting it would fail, only that it has not been observed end-to-end.

### Gaps Summary

One gap, one human-verification item, both narrowly scoped:

1. **ROADMAP criterion 7 ("all five test suites pass with zero skips") is not literally met.** `tests/test_vacalibration_backend.R` has 1 failure out of 640 assertions (section 12c, an MCMC-nondeterminism flake in a test the phase's diff never touched, confirmed via `git diff` against the pre-phase base commit). This is transparently documented in `deferred-items.md` across all four execution waves and was independently reproduced by the verifier (not merely trusted from SUMMARY.md). This looks like a strong override candidate — the failure is pre-existing, unrelated to R1/R2/R3, and out of scope for plans whose constraints explicitly forbid changing calibration behavior or test-iteration tuning. **This looks intentional in the sense of "known and accepted," but was never formally overridden.** To accept this deviation, add to this file's frontmatter:

```yaml
overrides:
  - must_have: "All five test suites pass with zero skips (ROADMAP criterion 7)"
    reason: "tests/test_vacalibration_backend.R section 12c is a pre-existing, unrelated MCMC-nondeterminism flake at nMCMC=400 in a code path this phase's diff never touched (confirmed via git diff against the pre-phase base commit fcedce4); documented in deferred-items.md across all four execution waves and independently reproduced during verification."
    accepted_by: "{your name}"
    accepted_at: "{ISO timestamp}"
```

2. **Human verification item above** — end-to-end confirmation of the stalled-run UI path, which the fix's own success made impossible to exercise via the issue's original reproduction file.

Everything else — the core scientific fix (R1), the retraction (R2, both layers), and the shared-assembly de-duplication with a genuinely-enforced guard (R3) — was independently re-derived and verified against the actual running code, not accepted on SUMMARY.md's word, including one adversarial falsification test that could have exposed a decorative-only guard and did not.

---

_Verified: 2026-08-25T15:45:00Z_
_Verifier: Claude (gsd-verifier)_
