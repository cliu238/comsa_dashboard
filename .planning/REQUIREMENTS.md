# Requirements

Scope is bounded by what is actually open and verified. Nothing here is speculative.

## R1 — Align the vacalibration input with the package's methodology (issue #101)

**Source:** @sandy-pramanik's reply 2026-08-17, points 1 and 2, plus his relayed answer
that `malaria` should remain calibrated.

Today `build_broad_matrix()` pads the input to **all** broad causes for the age group
(9 for child, 6 for neonate), including causes with zero observed deaths. A cause with a
CSMF of exactly 0 sits on the boundary of the probability simplex, so the path-correction
line search fails on its first iteration, returns λ at its ceiling, and **no calibration
is applied at all**. On the issue's own sample file this is the entire defect.

The package author's position: calibration should use only the causes observed in the
user's data, and absent causes should not appear in results or figures.

**Constraint discovered while measuring (this is why the naive fix is wrong):**
the package slices the CHAMPS misclassification matrix to whatever cause names it
receives, and then decides per-cause whether calibration is reliable from that slice.
Passing only the 7 observed causes shrinks `malaria`'s column range from 0.116 to 0.068,
crossing the 0.1 threshold, so **malaria stops being calibrated** — contradicting the
author's answer. Measured outcomes on the issue's file:

| approach | λ | `other_infections` | `malaria` |
|---|---|---|---|
| pass only observed causes | 0.14 | 30% → 52.4% | **not calibrated** |
| pass all names, exclude zero causes from calibration | 0.39 | 30% → 45.3% | calibrated |

**Acceptance:**
- Zero-count causes are excluded from calibration without shrinking the misclassification
  matrix, so per-cause reliability decisions are made on the full CHAMPS evidence.
- Zero-count causes do not appear in the chart, the comparison table, the misclassification
  panel, or any exported artifact.
- Dropping them does not distort percentages (verified: they receive exactly 0, and the
  remaining causes already sum to 1.000000).
- The set of causes the package declined to calibrate is surfaced to the user, not hidden.
- The issue's sample file calibrates instead of returning a no-op.

## R2 — Retract the false-precision framing (issue #101, author's point 4)

**This is our own error, shipped in PRs #115, #119 and #121.**

Those changes suppress the credible intervals of a stalled run and label them
"not meaningful" / "implausibly tight", on the reasoning that they were ~7× narrower than
the same input run with `path_correction = FALSE`.

That comparison used the wrong baseline. `path_correction = FALSE` is a *different
calibration* that propagates misclassification uncertainty; a stalled run applied **no**
calibration, so it correctly carries only sampling error. Verified against the multinomial
sampling error of the uncalibrated proportions — per-cause ratios 0.98–1.02 across every
calibrated cause. The intervals are right; the label was wrong.

**Acceptance:**
- The intervals are shown again in the chart, the comparison table, and
  `calibration_summary.csv`.
- They are labelled as the uncertainty of an **uncalibrated** estimate, stating that no
  calibration was applied — not as absent, and not as unreliable.
- λ continues to be reported, and stall detection is unchanged (it still correctly
  identifies "no calibration happened").
- No wording anywhere claims these intervals are meaningless or falsely narrow.

## R3 — Remove the structural cause of one-sided fixes

`backend/jobs/algorithms/vacalibration.R:206-296` and `backend/jobs/processor.R:189-270`
are near-verbatim duplicates. Fixes for #101 landed in one path only, twice.

**Acceptance:** the shared result-assembly logic exists once, both job paths use it, and a
test fails if either path stops using it.

## Out of scope

- Replying to the package author — explicitly excluded by the user.
- Anything requiring his forthcoming `exclude_zero_causes` argument. Our fix must work
  against the currently released CRAN version 2.2 and degrade gracefully when his default
  arrives.
- Issues #123 (dependency pinning), #114 (retention policy), #62, #49.
