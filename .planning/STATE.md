---
gsd_state_version: "1.0"
milestone: v1.0
current_phase: "02.1"
current_plan: 3
status: verifying
stopped_at: Completed 02.1-02-PLAN.md
last_updated: "2026-09-12T22:04:39.720Z"
last_activity: 2026-09-12
state_head: d477e5af5e472f253c7e051336014555c3b3f274
progress:
  total_phases: 4
  completed_phases: 2
  total_plans: 11
  completed_plans: 10
milestone_name: milestone
current_phase_name: Adopt vacalibration 2.3.1
---

# State

**Project:** COMSA Dashboard (brownfield, GSD-initialized 2026-08-18)
**Current phase:** 02.1
**Status:** Phase complete — ready for verification
**Last Activity:** 2026-09-12
**Config:** coarse granularity, parallel plans, balanced models, plan-check + verifier on,
per-phase research off (the codebase is already mapped and the domain question was settled
with the package author).

## Current Position

Current Plan: 3
Total Plans in Phase: 3

## Context carried in at initialization

Issue #101 was diagnosed over several rounds with @sandy-pramanik. What was settled:

- A broad cause with **zero** deaths sits on the simplex boundary, so path correction
  fails on its first iteration and λ returns at its ceiling — meaning **no calibration was
  applied**. Ceiling is 0.99 on the default `missmat_type="prior"` path and 1.01 on
  `"fixed"` (which starts at 1 with no cap and is reachable from the UI).

- The package author confirmed a stalled run's intervals **equal** no-calibration
  intervals; they are not falsely narrow. Verified here against multinomial sampling error
  (per-cause ratios 0.98–1.02). PRs #115/#119/#121 shipped the opposite claim — Phase 1
  retracts it.

- Zero-count causes should be excluded, but **how** matters: shrinking the input cause set
  also shrinks the misclassification matrix and un-calibrates `malaria` (column range
  0.116 → 0.068, crossing the 0.1 threshold). The author's position is that malaria should
  stay calibrated, so exclusion must not shrink the matrix.

- λ is **not reproducible** — the package draws 1000 unseeded Dirichlet samples in the
  search, and its `seed` argument only reaches `rstan::sampling` afterwards. Never quote a
  single λ as a constant; the 7-cause arm returns 0.13/0.14/0.15 across repeats.

- `path_correction = FALSE` is **not** an acceptable fix — the author reports a posterior
  projection problem, which is what motivated path correction.

## Merged so far on #101 (dashboard side)

| PR | What |
|---|---|
| #115 | Surfaced `lambda_calibpath`; suppressed the intervals (framing later found wrong) |
| #119 | Split `path_correction_stalled` from `ci_unreliable`; fixed the ensemble's false "not calibrated" claim |
| #120 | Stopped captioning the λ-mixed prior as empirical sensitivity (#116) |
| #121 | `calibration_summary.csv` stopped presenting stalled bounds as 95% CIs (#117) |
| #122 | Added `cmake`; restored the k8s deploy after a 2-day outage |

## Quick Tasks Completed

| Date | Task | Outcome |
|---|---|---|
| 2026-08-26 | `260826-fps-fix-issue-130` — CSMF table false precision (#130) | `pct()` made adaptive: >=1% renders exactly as before, sub-1% keeps two decimals, sub-0.01% renders `<0.01`. The issue's `0% (0-0)` now reads `0.35% (0-0.49)`. The CSV export inherited the fix with no code change. |

## vacalibration 2.3.1 (2026-09-12)

Author released 2.3.1 on GitHub (`498df45`); CRAN still 2.2. Its widened `learn`
rule (exclude causes with uncalibrated CSMF < 1 % or > 99 %) natively covers Phase 1's
zero-count `donotcalib` exclusion with the same full-matrix mechanism, and its
`cause_map()` now accepts broad causes directly. It does NOT ship the promised
`exclude_zero_causes` argument or a λ-stall flag. Adoption is forced: StanHeaders
2.39.1 (CRAN 2026-09-02) breaks 2.2's Stan compile, so the Phase 2 snapshot pin is the
only thing keeping the image building. Full analysis:
`.planning/notes/vacalibration-2-3-1-vs-phase-1.md`.

## Performance Metrics

| Plan | Duration | Tasks | Files |
|------|----------|-------|-------|
| Phase 02.1 P01 | 15min | 2 tasks | 3 files |
| Phase 02.1 P02 | 20min | 3 tasks | 3 files |

## Decisions

- [Phase 02.1]: Pinned vacalibration to GitHub commit 498df45 (2.3.1) via remotes::install_github with upgrade='never', keeping CRAN snapshot at 2026-08-01 for everything else — CRAN still carries 2.2, whose Stan models don't compile against StanHeaders 2.39.1 (2026-09-02); the SHA pin is reversible once CRAN carries 2.3.1

## Session

**Last session:** 2026-09-12T22:04:39.668Z
**Stopped at:** Completed 02.1-02-PLAN.md
**Resume file:** None
