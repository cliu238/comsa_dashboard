---
phase: 02-reproducible-builds
plan: 01
subsystem: infra
tags: [docker, dockerfile, cran, r, ci, reproducible-builds]

# Dependency graph
requires: []
provides:
  - "backend/Dockerfile pinned to a fixed base-image digest (rocker/r-ver:4.4 multi-arch index)"
  - "single-source CRAN_SNAPSHOT ENV feeding an Rprofile.site append, replacing four inline repos= overrides"
  - "explicit install.packages() entry for sodium (previously transitive via plumber)"
  - "/opt/package-manifest.csv written from installed.packages() before COPY, with a build-time stopifnot() presence guard"
  - "tests/test_dockerfile_pinning.R regression guard (25 assertions), wired into the CI backend job before Install jsonlite"
affects: [02-02, 02-03, 02-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Single ENV as the one place a CRAN snapshot date lives; every install.packages() call inherits it via Rprofile.site rather than a per-call repos= argument"
    - "Source-assertion Dockerfile tests (readLines + comment-stripped line matching) as a CI-cheap regression guard needing no Docker/network"

key-files:
  created:
    - tests/test_dockerfile_pinning.R
  modified:
    - backend/Dockerfile
    - .github/workflows/test.yml

key-decisions:
  - "Used the locked digest sha256:3dae5d2eeddf74f10e0a81fb6b7ae350295e288000304f438b844b2c1e00fe2c and snapshot https://p3m.dev/cran/__linux__/noble/2026-08-01 verbatim from 02-CONTEXT.md / verified_facts, per-value re-derivation would risk a plausible-looking but wrong substitute"
  - "Repo override appends (>>) onto the base image's existing Rprofile.site rather than replacing it, preserving HTTPUserAgent (required for p3m.dev to serve binaries) and download.file.method=libcurl"
  - "Package manifest stopifnot() lists sodium both standalone and inside the full 15-package `required` vector so a single source line satisfies both the granular sodium-presence assertion and the full completeness check"

requirements-completed: ["#123"]

# Metrics
duration: ~15min
completed: 2026-08-25
---

# Phase 02 Plan 01: Pin the backend Dockerfile build Summary

**Digest-pinned `rocker/r-ver:4.4` base image, single dated CRAN snapshot (`2026-08-01`) replacing four inline `repos=` overrides, explicit `sodium` install, and an in-image `/opt/package-manifest.csv` — enforced by a 25-assertion CI guard (`tests/test_dockerfile_pinning.R`).**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-08-25
- **Tasks:** 2/2
- **Files modified:** 3 (1 created, 2 modified)

## Accomplishments
- `backend/Dockerfile` now builds from `rocker/r-ver:4.4@sha256:3dae5d2eeddf74f10e0a81fb6b7ae350295e288000304f438b844b2c1e00fe2c` with a comment recording the tag, R 4.4.3, and the multi-arch (amd64+arm64) scope of the digest
- All R packages resolve from `https://p3m.dev/cran/__linux__/noble/2026-08-01`, named exactly once in `ENV CRAN_SNAPSHOT=`, appended into `/usr/local/lib/R/etc/Rprofile.site` via `>>` — the four `repos='https://cloud.r-project.org'` inline overrides are gone and `cloud.r-project.org` no longer appears anywhere in the file
- `sodium` is now an explicit `install.packages()` entry (previously arrived transitively via `plumber`), alongside a build-time `stopifnot()` over all 15 required packages
- `/opt/package-manifest.csv` is written from `installed.packages()` under `LC_COLLATE=C` before `COPY backend/ /app/`, so a missing package fails the build rather than shipping silently
- `tests/test_dockerfile_pinning.R` (25 assertions, house test-file style copied from `tests/test_misclass_matrix.R`) verified RED (14 failures) against the original file and GREEN (0 failures) after pinning; wired into `.github/workflows/test.yml`'s `backend` job immediately before `Install jsonlite`
- Both `docker run` verification checks from the plan's acceptance criteria were executed (Docker daemon was available) and passed: the pinned snapshot serves the exact recorded version of all 15 packages, and the `Rprofile.site` append overrides `CRAN` while `HTTPUserAgent` survives

## Task Commits

Each task was committed atomically:

1. **Task 1: Write the failing Dockerfile pinning guard** - `ed35c24` (test)
2. **Task 2: Pin the Dockerfile, add sodium and the manifest, wire the guard into CI** - `10592c5` (feat)

_TDD RED→GREEN: `ed35c24` was verified to exit 1 (14 of 25 assertions failing, matching all 7 required FAIL properties from the plan) before `10592c5` turned all 25 assertions green._

## Files Created/Modified
- `tests/test_dockerfile_pinning.R` - 25-assertion source-only regression guard over `backend/Dockerfile` (base-image digest, single-source CRAN snapshot, no `cloud.r-project.org`, no per-call `repos=`, explicit sodium, manifest-before-COPY ordering, load-bearing elements intact)
- `backend/Dockerfile` - digest-pinned `FROM`, `ENV CRAN_SNAPSHOT=`, `Rprofile.site` append, explicit `sodium`, `/opt/package-manifest.csv` write with `stopifnot()` guard
- `.github/workflows/test.yml` - new `Dockerfile pinning guard (issue #123)` step in the `backend` job, positioned before `Install jsonlite`; extended block comment above the job

## Decisions Made
- Followed 02-CONTEXT.md's locked decisions verbatim: explicit dated Posit snapshot (not "just delete `repos=`", which was verified to break the build since `vacalibration`/`EAVA` are absent from the base image's own 2025-04-10 default), multi-arch index digest (not single-arch, since CI is amd64 and local dev is arm64), in-image manifest as the proof mechanism for reproducibility (not a one-off local `docker build`, since local is arm64 and the runner is amd64)
- Did not touch `.claude/skills/comsa-k8s-deploy/assets/dockerfiles/Dockerfile.backend` (the stale template deletion) or `.github/workflows/deploy.yml` (the manifest-diff step) — both are referenced in `02-CONTEXT.md` as locked decisions but are not in this plan's `files_modified` list; they belong to a later plan in this phase (02-02/02-03/02-04)

## Deviations from Plan

None - plan executed exactly as written. One implementation-detail adjustment within Task 2's own acceptance criteria: the initial manifest `stopifnot()` call referenced `sodium` only via the `required` vector on a separate source line, which failed the guard's "`stopifnot` together with `sodium` on the same line" assertion; added a redundant `stopifnot('sodium' %in% pkgs$Package, all(required %in% pkgs$Package))` clause so both the standalone sodium check and the full 15-package check live on one line. This is an in-task fix before the task's own verification passed, not a post-hoc deviation from committed work.

## Test Results

`Rscript tests/test_dockerfile_pinning.R` — **Total: 25  Passed: 25  Failed: 0** (run from project root; also verified identical from `backend/` via path-probing). This is the baseline count plan 02-03 will diff against when it appends its own section to this same file (expected growth: +3 assertions, per plan 02-01's `<output_note>`).

Docker verification (both executed, Docker daemon was available on this machine):
- `available.packages()` against the pinned snapshot returned exactly the recorded versions for all 15 required packages (vacalibration 2.2, EAVA 1.0.0, openVA 1.2.0, sodium 1.4.0, plumber 1.3.3, jose 2.0.0, pool 1.0.5, knitr 1.51, rstan 2.32.7, RcppParallel 6.2.0, RPostgres 1.4.10, uuid 1.2-2, future 1.75.0, jsonlite 2.0.0, rJava 1.0-18)
- The `Rprofile.site` append test printed `override ok`: `repos[["CRAN"]]` matched the snapshot URL and `HTTPUserAgent` remained non-empty

Not run in this plan (deferred to plan 02-04 per domain constraints): an actual `docker build` of the full `backend/Dockerfile` (arm64-only proof, and the Stan recompilation step alone takes minutes) — the plan explicitly scopes the real shippable-artifact proof to 02-04's CI run on the amd64 runner.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `backend/Dockerfile` and its CI guard are ready for plan 02-02 (manifest-diff wiring in `deploy.yml`) and 02-03 (skill-asset Dockerfile template cleanup, which appends its own section to `tests/test_dockerfile_pinning.R`)
- `tests/test_dockerfile_pinning.R`'s current `Total: 25` count is the number 02-03 should see grow by exactly 3 assertions when it adds its own section
- No blockers identified

---
*Phase: 02-reproducible-builds*
*Completed: 2026-08-25*

## Self-Check: PASSED

- FOUND: tests/test_dockerfile_pinning.R
- FOUND: backend/Dockerfile
- FOUND: .github/workflows/test.yml
- FOUND: .planning/phases/02-reproducible-builds/02-01-SUMMARY.md
- FOUND commit: ed35c24 (test: failing Dockerfile pinning guard)
- FOUND commit: 10592c5 (feat: pin Dockerfile, wire CI guard)
- FOUND commit: 79d7b96 (docs: plan summary)
