---
status: passed
phase: 01-issue-101-calibration-correctness
source: [01-VERIFICATION.md]
started: 2026-08-25
updated: 2026-08-25
---

## Current Test

[none — all items resolved]

## Tests

### 1. Render a genuinely stalled run through the full UI stack

expected: A stalled facet states "No calibration was applied", the credible
intervals are drawn as whiskers in the CSMF chart, the comparison table prints
lower–upper bounds, and no wording anywhere calls an interval omitted,
unreliable, meaningless, implausibly tight or falsely narrow. A point-mass
interval (lower == upper) is still not drawn and still not printed.

result: PASSED (2026-08-25, driven through Chromium via Playwright against the
real backend on :8000 and Postgres; 3 consecutive runs, identical outcome, zero
browser console errors)

how the stall was obtained: the R1 fix removed the stall from every dataset
shipped in the repo — a 96-combination sweep (6 sample CSVs x 8 countries x
missmat_type prior/fixed) returned lambda 0.00–0.59 with ZERO stalls, which is
itself confirmation that R1 works. A stall was therefore constructed:
`sample_insilicova_neonate.csv` with the `prematurity` broad cause thinned to
ONE death. Zero deaths would be excluded by R1's `donotcalib`; one death keeps
the cause in the calibrated set while still making lambda = 0.99 infeasible on
the line search's first iteration. Verified to stall 30/30 (10 repeats x
Mozambique / Sierra Leone / Kenya) — the stall does not inherit lambda's
non-determinism, because infeasibility at the ceiling does not depend on the
Dirichlet draw.

observed, submitted as InSilicoVA / neonate / Mozambique / Propagate (Mmatprior):

- chart caveat: "No calibration was applied: path correction could only use
  lambda = 0.99. The bars equal the uncalibrated estimate, and the credible
  interval shown is that estimate's own uncertainty (sampling error only)."
- 4 whiskers drawn (`.csmf-whisker`), one per calibrated cause; legend shows
  "95% CI".
- comparison table row "Calibrated (none applied — interval is the uncalibrated
  estimate)" printed bounds for 4 causes: 36% (33–39), 40% (37–43), 0% (0–0),
  16% (14–19).
- the 2 point-mass causes (Other and unspecified neonatal CoD 7%, Congenital
  malformation 0%) printed NO bounds and drew NO whisker. `calibration_summary.csv`
  confirms both as `NA,NA` with the distinct point-mass `interval_note` (WR-01).
- misclassification panel carried the near-identity caveat (WR-03) and named
  the causes vacalibration itself declined (criterion 5).
- all six retracted phrasings absent: omitted / unreliable / meaningless /
  implausibl* / falsely narrow / not meaningful.

## Summary

total: 1
passed: 1
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps

None blocking. One cosmetic finding logged to deferred-items.md: the comparison
table rounds to integer percent, so `prematurity`'s real interval
(0 – 0.0049, per `calibration_summary.csv`) prints as "0% (0–0)" — which reads
as a point mass even though the whisker is correctly drawn. The backend data and
the chart are both right; only the table's display precision is misleading.
