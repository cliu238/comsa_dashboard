---
phase: 02-reproducible-builds
plan: 04
completed: 2026-08-25
status: complete
tasks_completed: 3
tasks_total: 3
requirements: ["#123"]
key_files:
  created:
    - backend/package-manifest.csv
  modified: []
---

# Plan 02-04: Prove the pinning on amd64 CI

Closes success criterion 4 — "building the same commit twice yields identical installed package
versions" — with evidence from the amd64 runner rather than from an arm64 laptop.

## What was done

The three tasks are human-action / human-verify by design: an executor agent cannot push to CI,
cannot dispatch a workflow, and cannot observe a run. The user pushed and merged; the orchestrator
then read the per-job conclusions, the build logs, and the deployed pod directly.

## Evidence

### The three runs

| Run | Trigger | SHA | check-changes | build-and-push | deploy |
|---|---|---|---|---|---|
| [32884468980](https://github.com/cliu238/comsa_dashboard/actions/runs/32884468980) | push | `e979ffd` | success | success | success |
| [32884818317](https://github.com/cliu238/comsa_dashboard/actions/runs/32884818317) | workflow_dispatch | `e979ffd` | success | success | success |
| [32885706868](https://github.com/cliu238/comsa_dashboard/actions/runs/32885706868) | push | `e6df19a` | success | success | success |

Conclusions were read per job via `gh run view <id> --json jobs`, never from the overall run
conclusion. No job reported `skipped`. This matters because project memory records two traps: a
`skipped` backend build does not read as red in the summary, and the `check-changes` path filter
lets a frontend-only change report success while the backend image is never built.

The backend image **was** built in these runs — `Build and push backend image` is present and
`success` in `build-and-push`, so the path filter matched (`backend/Dockerfile` and, later,
`backend/package-manifest.csv` both live under `backend/**`).

### The cache-free rebuild — the actual proof for criterion 4

Run 32884818317 was dispatched with `force_backend_rebuild=true`. Confirmed from the log that
this reached buildx as a genuine cache bypass, not just an input flag:

- the `docker buildx build` command line carries `--no-cache`
- the R install layers **executed** rather than reporting `CACHED`, with real elapsed time:
  - `#11 [ 5/13] install.packages(c('plumber', ..., 'sodium'))` — 18:38:42 → 18:39:14
  - `#13 [ 7/13] install.packages(c('openVA', 'EAVA', 'vacalibration', 'knitr'))` — 18:39:16 → 18:42:23 (~3 min)
  - `#15 [ 9/13]` wrote `/opt/package-manifest.csv` with the `stopifnot` guard intact

`backend/package-manifest.csv` already existed at `e979ffd`, so the `Verify backend package
manifest (issue #123)` step was in **blocking** mode, not the bootstrap advisory path. The step
script runs under `set -euo pipefail`, so a manifest difference exits non-zero and fails the job.
The step concluded `success`.

**Therefore: an independently rebuilt image, with every apt and R package re-resolved from scratch
on a fresh amd64 runner, produced a package set identical to the committed manifest.** That is
criterion 4, demonstrated rather than asserted.

The verification also pulls the image by `steps.build-backend.outputs.digest`
(`ghcr.io/...@sha256:3bf340dd…`), never by `:latest`, so it cannot accidentally verify a different
image than the one just built.

### The golden manifest

`backend/package-manifest.csv` — 134 packages, `Package,Version` header, `LC_COLLATE=C` sorted.
Spot-checked against the versions this phase set out to pin:

| Package | Recorded |
|---|---|
| vacalibration | 2.2 |
| EAVA | 1.0.0 |
| openVA | 1.2.0 |
| RcppParallel | 6.2.0 |
| sodium | 1.4.0 |
| plumber | 1.3.3 |
| jose | 2.0.0 |
| pool | 1.0.5 |
| knitr | 1.51 |
| rstan | 2.32.7 |

`RcppParallel 6.2.0` is the package whose unpinned upgrade caused the 2026-08-12 → 08-13 outage.
It is now fixed by the manifest gate.

### The deployed pod

- `curl -sS https://dev.sites.idies.jhu.edu/comsa-dashboard/api/health` → `{"status":["ok"],"timestamp":["2026-08-25 19:08:37"]}`
- `POST /api/auth/login` with deliberately invalid credentials → `HTTP 401` and
  `{"error":["Invalid email or password"]}`

The 401 is the meaningful result for this phase: `backend/auth/passwords.R` calls `library(sodium)`
at load time, so a missing `sodium` would fail to source the auth module and surface as a 500 or a
dead endpoint, not a clean 401. The auth module loaded in the new image.

**Scope limit, stated plainly:** a nonexistent email may short-circuit before
`sodium::password_verify()` is reached, so this probe proves `library(sodium)` resolves — it does
not prove the hash-verification call itself executed. A successful login with a real account would
close that last inch. The risk it leaves open is small: `sodium` moving from transitive to explicit
was the failure mode this criterion targeted, and load-time resolution is what that fix addresses.

## Deviations from the plan

- The plan expected Task 2 (freeze the golden manifest) to run before the proving pushes. In
  practice the manifest was already committed and merged by the time the orchestrator inspected
  CI, so runs 1 and 2 both executed with the diff already blocking. The evidence is stronger this
  way, not weaker — the cache-free rebuild was diffed against a pre-existing golden file rather
  than generating the file it would later be compared to.
- Three runs exist rather than the two the plan called for; `e6df19a` is a later push whose
  backend build also passed the blocking diff, which is an additional independent confirmation.

## Issues encountered

**`.planning/` was dropped from `origin/master` during the merge.** `git ls-tree -r origin/master
-- .planning/` returned zero files while the local tree had 33. It is not gitignored, so this was
a merge side effect, not configuration. No functional impact — every source change reached origin
and CI verified them — but the GSD state, roadmap, and all phase artifacts were missing remotely.
Restored locally in `41d1b1d` and pushed alongside this summary.

## Success criteria status

| # | Criterion | Status |
|---|---|---|
| 1 | R package versions pinned | Met — single `ENV CRAN_SNAPSHOT=https://p3m.dev/cran/__linux__/noble/2026-08-01`, all four `repos=` overrides removed |
| 2 | `sodium` installed explicitly | Met in source and at build time (`stopifnot`); load-time resolution confirmed on the deployed pod |
| 3 | Base image pinned to a digest | Met — `rocker/r-ver:4.4@sha256:3dae5d2e…` (multi-arch index, R 4.4.3) |
| 4 | Same commit twice → identical versions | Met — cache-free amd64 rebuild diffed clean against the committed manifest |
