# Roadmap

Granularity: coarse. Brownfield — phases cover open, verified work only.

## Phases

- [x] **Phase 1: Issue 101 calibration correctness** - Align the vacalibration input with the package's methodology and retract our own false-precision framing
- [x] **Phase 2: Reproducible builds** - Pin R dependencies so upstream releases cannot break deploys (#123)
- [x] **Phase 02.1: Adopt vacalibration 2.3.1** - Move to the author's 2.3.1 (GitHub `498df45`) without moving the CRAN snapshot; retire what it now does natively (completed 2026-09-13)
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
- [x] 02-04: Prove it on the amd64 runner — per-job conclusions, commit the golden manifest, cache-free rebuild diff (wave 3, checkpoint)

### Phase 02.1: Adopt vacalibration 2.3.1 (INSERTED)

**Goal**: The backend runs vacalibration 2.3.1 (GitHub commit `498df45`) reproducibly on the existing 2026-08-01 CRAN snapshot, every test suite passes without skips, and the package's new sub-1% exclusion rule is disclosed to users the same way our own zero-count exclusion is.
**Depends on**: Phase 2 (snapshot pin and manifest diff are the reproducibility guard this phase relies on)
**Requirements**: `.planning/notes/vacalibration-2-3-1-vs-phase-1.md` (research, decisions, expected behaviour changes)
**Why now**: StanHeaders 2.39.1 reached CRAN on 2026-09-02 and vacalibration 2.2's Stan models do not compile against it. Only the Phase 2 snapshot pin keeps the image building; the snapshot cannot move until this phase lands.
**Success Criteria** (what must be TRUE):

  1. `backend/Dockerfile` installs vacalibration from GitHub pinned to commit `498df45` (not a branch), and `backend/package-manifest.csv` records `vacalibration,2.3.1`; the `deploy.yml` manifest diff passes.
  2. `CRAN_SNAPSHOT` is unchanged at 2026-08-01 and both Stan models compile at image build (verified locally on rstan 2.32.7 / StanHeaders 2.32.10).
  3. Issue #101's sample file (`frontend/public/sample_eava_child.csv`, Mozambique) still produces a real calibration with `malaria` calibrated; the R1 acceptance numbers are unchanged.
  4. A dataset with a cause between 0 % and 1 % of deaths shows that cause as "declined to calibrate" in the UI and exports, via the existing `calibrated` map, with no wording claiming it is a zero-count exclusion.
  5. Stall detection, display filtering of zero-count causes, and `safe_cause_map()` are kept; the explicit zero-count `donotcalib` is either kept with a comment stating it is now redundant with the package's learn rule, or removed with its tests, but not left unexplained.
  6. Test section 12c's learn-rule flakiness (Phase 1 deferred item) is resolved, not skipped.
  7. All test suites pass with zero skips.

**Plans**: 3/3 plans executed

Plans:
**Wave 1**

- [x] 02.1-01-PLAN.md — Pin vacalibration 2.3.1 at commit `498df45`, update the manifest, guard the pin in CI, and prove one real calibration end to end (wave 1)

**Wave 2** *(blocked on Wave 1 completion)*

- [x] 02.1-02-PLAN.md — Document the redundancy, log the package version, and make the suites assert the widened learn rule (wave 2)

**Wave 3** *(blocked on Wave 2 completion)*

- [x] 02.1-03-PLAN.md — Land it on master and verify the build, the manifest diff and the two acceptance jobs on dev (wave 3, has checkpoints)

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
| 2 | 4/4 | Complete | 2026-08-25 |
| 02.1 | 3/3 | Complete    | 2026-09-13 |
| 3 | 0/TBD | Not started | — |

## Deferred

- #62 (deployment testing sign-off) and #49 (intro video) — not engineering work on this codebase.
- The author's promised `exclude_zero_causes` argument and λ-stall flag: neither shipped in vacalibration 2.3.1 (verified against commit `498df45`, 2026-09-12). Stall detection and zero-count display filtering stay dashboard-owned; revisit only if a later release adds them.
