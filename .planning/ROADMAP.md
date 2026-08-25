# Roadmap

Granularity: coarse. Brownfield — phases cover open, verified work only.

## Phases

- [x] **Phase 1: Issue 101 calibration correctness** - Align the vacalibration input with the package's methodology and retract our own false-precision framing
- [ ] **Phase 2: Reproducible builds** - Pin R dependencies so upstream releases cannot break deploys (#123)
- [ ] **Phase 3: Data retention policy** - Define expiry for stored job data (#114)

## Phase Details

### Phase 1: Issue 101 calibration correctness
**Goal**: A dataset containing a broad cause with zero deaths calibrates correctly instead of silently returning an uncalibrated result, and no surface claims that statistically correct intervals are meaningless.
**Depends on**: Nothing (first phase)
**Requirements**: R1, R2, R3
**Success Criteria** (what must be TRUE):
  1. Uploading the issue's `sample_eava_1to59m.csv` (the repo copy of that dataset is `frontend/public/sample_eava_child.csv` — 2383 child records, `injury` and `nn_causes` at zero deaths, reproduces the stall on country Mozambique) produces a real calibration, not a no-op.
  2. Causes with zero observed deaths appear nowhere in the chart, comparison table, misclassification panel, or exported files.
  3. `malaria` remains calibrated on that file — excluding zero-count causes must not shrink the misclassification matrix and change per-cause reliability decisions.
  4. Credible intervals are shown for a stalled run, labelled as the uncertainty of an uncalibrated estimate rather than as unreliable or absent.
  5. The causes the package declined to calibrate are visible to the user.
  6. Both job paths provably share one result-assembly implementation — a test fails if either stops using it.
  7. All five test suites pass with zero skips.
**Plans**: 4 plans

Plans (execution order is by wave, not by number — 01-03 runs first so that R1 and R2 are each implemented once instead of twice):
- [x] 01-03: De-duplicate result assembly between the two job paths (wave 1, R3)
- [x] 01-01: Exclude zero-count causes from calibration via `donotcalib` without shrinking the misclassification matrix; filter them from every display and export surface (wave 2, R1)
- [x] 01-02: Restore the stalled-run credible intervals in `calibration_summary.csv`, delete `ci_unreliable`, and retract the false-precision wording in the backend (wave 3, R2)
- [x] 01-04: Restore and relabel the stalled-run intervals in the chart, the comparison table and the misclassification panel (wave 4, R2)

### Phase 2: Reproducible builds
**Goal**: An unchanged commit builds the same image regardless of when it is built, so upstream package releases cannot break deploys or be misattributed to unrelated commits.
**Depends on**: Nothing
**Requirements**: (tracked in issue #123)
**Success Criteria** (what must be TRUE):
  1. R package versions are pinned (dated snapshot repo or equivalent).
  2. `sodium` is installed explicitly rather than arriving transitively via `plumber`.
  3. The base image tag is pinned to a digest or patch version.
  4. Building the same commit twice yields identical installed package versions.
**Plans**: 4 plans

Plans (execution order is by wave, not by number):
- [x] 02-01: Pin the base-image digest and the dated CRAN snapshot, install `sodium` explicitly, emit an in-image package manifest, and guard all of it with `tests/test_dockerfile_pinning.R` (wave 1)
- [x] 02-02: Extract the manifest from the built image by digest and diff it against the committed one in `deploy.yml`; add an on-demand cache-free rebuild switch (wave 2)
- [x] 02-03: Delete the drifted Dockerfile templates in the `comsa-k8s-deploy` skill, repoint the skill and guide at the repository files, assert single-copy from CI (wave 2)
- [ ] 02-04: Prove it on the amd64 runner — per-job conclusions, commit the golden manifest, cache-free rebuild diff (wave 3, checkpoint)

### Phase 3: Data retention policy
**Goal**: Stored job data has a defined expiry, applied automatically.
**Depends on**: Nothing
**Requirements**: (tracked in issue #114)
**Success Criteria** (what must be TRUE):
  1. A retention window is documented and agreed.
  2. Expired job data is removed without manual intervention.
**Plans**: TBD

## Progress

| Phase | Plans Complete | Status | Completed |
|---|---|---|---|
| 1 | 4/4 | Complete | 2026-08-25 |
| 2 | 3/4 | In progress (02-04 needs the amd64 CI run) | — |
| 3 | 0/TBD | Not started | — |

## Deferred

- #62 (deployment testing sign-off) and #49 (intro video) — not engineering work on this codebase.
- Anything gated on the package author's forthcoming `exclude_zero_causes` release.
