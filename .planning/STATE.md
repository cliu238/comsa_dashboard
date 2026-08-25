---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
current_phase: 02
status: executing
last_updated: "2026-08-25T17:03:06.308Z"
last_activity: 2026-08-25
progress:
  total_phases: 3
  completed_phases: 1
  total_plans: 8
  completed_plans: 7
  percent: 88
---

# State

**Project:** COMSA Dashboard (brownfield, GSD-initialized 2026-08-18)
**Current phase:** 02
**Status:** Executing Phase 02
**Last Activity:** 2026-08-25
**Config:** coarse granularity, parallel plans, balanced models, plan-check + verifier on,
per-phase research off (the codebase is already mapped and the domain question was settled
with the package author).

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

_None yet._
