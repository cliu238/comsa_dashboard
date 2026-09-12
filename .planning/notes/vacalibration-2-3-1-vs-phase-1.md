---
title: vacalibration 2.3.1 vs Phase 1 — what is duplicated, what is forced
date: 2026-09-12
context: Package author emailed that vacalibration 2.3.1 is on GitHub (new cause_map, CRAN submission pending). Researched whether Phase 1 (issue #101) duplicated it and whether adoption is optional. Feeds Phase 02.1 planning.
---

# vacalibration 2.3.1 vs Phase 1

All claims below were checked against primary sources on 2026-09-12:
the package repo at commit `498df45` (github.com/sandy-pramanik/vacalibration, `main`),
the diff against the CRAN 2.2 commit `0264505`, the CRAN index pages for
vacalibration and StanHeaders, and a local compile against the image's pinned rstan.

## What 2.3.1 changes relative to CRAN 2.2

| Change | Detail | Source |
|---|---|---|
| `cause_map()` accepts broad causes directly | Two-column input whose second column is entirely broad-cause names is turned straight into the 0/1 matrix; absent broad causes are padded as zero columns in canonical order. `cause`/`cause1` are standardised, tibbles no longer error on the class test, and the child diarrhea list gains the spelling `diarrhea`. | `R/cause_map.R` diff |
| `learn` rule widened | With `donotcalib_type = "learn"` (the default), causes whose **uncalibrated CSMF is < 0.01 or > 0.99** are added to the do-not-calibrate mask, in addition to the misclassification-variance screen. NEWS states results may differ from 2.2. | `R/modular_vacalib_prior.R` line 252, `R/modular_vacalib_fixed.R` line 234, `NEWS.md` |
| Stan models on new array syntax | Required because StanHeaders >= 2.33 fails to compile the 2.2 models. Declares `rstan (>= 2.26)`. | `inst/stan/seqcalib.stan`, `seqcalib_mmat.stan`, `DESCRIPTION` |
| Dead function removed | `get_stan_seqcalib_q()` referenced a model file that does not exist. | `R/model_utils.R` |

**Not in 2.3.1** despite the author's issue #101 comment of 2026-08-17 (points 5):
no `exclude_zero_causes` argument, and no flag or warning when the λ path-correction
search fails. Verified by grep over every `R/*.R` file at `498df45`.

## Phase 1 line by line

| Phase 1 deliverable | Covered by 2.3.1? | After upgrade |
|---|---|---|
| R1: exclude zero-death causes via `donotcalib` without shrinking the matrix | **Yes, same mechanism.** The new learn rule adds CSMF-0 causes to `donotcalib_tomodel`, a per-cause mask over the full matrix; malaria's reliability screen still sees the full CHAMPS matrix. | Our explicit `donotcalib` is unioned with the learn set, so it stays correct but becomes redundant. Keep (it is the only place the exclusion is logged) or delete; either is safe. |
| R1: hide zero-death causes from chart, table, matrix, exports | No. The package still returns rows for them (zero-padded input keeps all 9/6 causes). | Keep. |
| R1: surface the causes the package declined to calibrate | No, but our `calibrated` map already reads the package's own decision, so the new sub-1% exclusions are disclosed with no code change. | Keep; verify on a dataset with a 0-1% cause. |
| R2: retract the false-precision framing | Dashboard-side only. | Keep. |
| R3: single result-assembly path | Dashboard-side only. | Keep. |
| Pre-existing `build_broad_matrix()` / `is_broad_format()` | **Yes.** The author now implements the same broad-input path inside `cause_map()`. | Keep ours: it also normalises spaces, hyphens and case; the package only lowercases. |
| Stall detection (`path_correction_stalled`, λ at ceiling) | No. | Keep. |
| `safe_cause_map()` dummy padding | No. An unrecognised specific cause still renames to NA and crashes with "non-conformable arguments". | Keep. |

Net: the duplicated part is the exclusion mechanism and the broad-matrix builder,
roughly half of plan 01-01. Phase 1's requirements explicitly targeted CRAN 2.2 with
graceful degradation when the author's version arrived; this is that moment.

## Why adoption is forced, not optional

- CRAN published **StanHeaders 2.39.1 on 2026-09-02**. vacalibration 2.2's Stan models
  do not compile against it (per the package NEWS; our Dockerfile compiles those models
  at build time).
- The image is unaffected today only because Phase 2 pinned the CRAN snapshot to
  **2026-08-01** (manifest: StanHeaders 2.32.10, rstan 2.32.7).
- Consequence: the snapshot date cannot move past 2026-09-02 until vacalibration is on
  2.3 or later. Every future openVA, rstan or security bump is blocked behind this.

## Feasibility proof

Local R has rstan 2.32.7 + StanHeaders 2.32.10, identical to the image manifest.
Both 2.3.1 Stan files pass `rstan::stanc()`, and `seqcalib.stan` compiles fully with
`rstan::stan_model()` in 22 s. So the snapshot can stay at 2026-08-01 and only
vacalibration moves.

## Behaviour changes to expect after upgrade

- Any dataset with a cause between 0 % and 1 % of deaths calibrates differently (that
  cause is no longer calibrated). Issue #101's sample file has a minimum cause share of
  5.6 %, so its R1 acceptance numbers do not change.
- `tests/test_vacalibration_backend.R` section 12c (already logged as flaky in Phase 1
  deferred items because the learn rule can exclude an extra cause) will fail more
  deterministically and needs its assertion revisited.
- `backend/package-manifest.csv` must change `vacalibration,2.2` to `2.3.1`, otherwise
  the Phase 2 manifest diff in `deploy.yml` fails.
- `knitr` remains a runtime need (Suggests only) unless verified otherwise on 2.3.1.

## Decisions taken (user may veto)

1. **Install from GitHub pinned to commit `498df45` now; do not wait for CRAN.** CRAN is
   still 2.2 and the author gave no date. A SHA pin satisfies Phase 2's reproducibility
   rule. Switch back to the CRAN snapshot once 2.3.1 is published there
   (see seed `switch-vacalibration-pin-to-cran`).
2. **Schedule as Phase 02.1, ahead of data retention.** User asked for it to be
   prioritised.

## Open question

The author's email said the new `cause_map` was "among the items I shared today in the
meeting". Whether the meeting raised other dashboard-facing items (new country
matrices, output-field changes, UI asks) is unknown and would widen Phase 02.1's
scope. Until answered, Phase 02.1 is scoped as a pure upgrade plus adaptation.
