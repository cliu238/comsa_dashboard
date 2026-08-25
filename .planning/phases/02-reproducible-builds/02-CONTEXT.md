# Phase 2: Reproducible builds - Context

**Gathered:** 2026-08-25
**Status:** Ready for planning
**Mode:** Smart discuss (autonomous) — grey areas proposed in batch, user accepted all recommendations

<domain>
## Phase Boundary

An unchanged commit builds the same image regardless of when it is built, so upstream
package releases cannot break deploys or be misattributed to unrelated commits.

Scope is `backend/Dockerfile` and the build/verification path around it. Tracked in issue #123.

**In scope:** pinning the CRAN source, pinning the base image, adding the missing explicit
`sodium` install, proving reproducibility, and removing the stale Dockerfile template copy.

**Out of scope:** `frontend/Dockerfile` (npm already has `package-lock.json`), the `check-changes`
path-filter problem from the #122 outage (separate concern — a green deploy that skipped the
backend build), and any change to application behaviour.
</domain>

<decisions>
## Implementation Decisions

### Locked — CRAN pinning mechanism

Pin an **explicit dated Posit snapshot** in the Dockerfile:
`https://p3m.dev/cran/__linux__/noble/2026-08-01`

**A cheaper-looking option was investigated and rejected on evidence.** `rocker/r-ver` ships with
its own date-locked snapshot as the default `repos`, and the Dockerfile currently overrides it on
every `install.packages()` call with `repos='https://cloud.r-project.org'`. Simply deleting those
four overrides looked like the minimal fix. It does not work: the image's built-in snapshot is
`https://p3m.dev/cran/__linux__/noble/2025-04-10`, and **both `vacalibration` and `EAVA` are ABSENT
from it** (verified by running `available.packages()` inside the pinned image). Dropping the
override would fail the build outright, not merely install older versions.

**Why 2026-08-01:** it is the most recent snapshot verified to carry every required package, and
its versions are identical to today's CRAN for everything load-bearing — so pinning introduces no
version jump relative to what is deployed now.

Verified contents of the 2026-08-01 snapshot (queried directly, not assumed):

| Package | 2026-08-01 snapshot | CRAN today |
|---|---|---|
| vacalibration | 2.2 | 2.2 |
| EAVA | 1.0.0 | 1.0.0 |
| openVA | 1.2.0 | 1.2.0 |
| RcppParallel | 6.2.0 | 6.2.0 |
| sodium | 1.4.0 | 1.4.0 |
| plumber | 1.3.3 | — |
| jose | 2.0.0 | — |
| pool | 1.0.5 | — |
| knitr | 1.51 | — |
| rstan | 2.32.7 | — |
| RPostgres | 1.4.10 | — |
| rJava | 1.0-18 | — |
| uuid | 1.2-2 | — |
| future | 1.75.0 | — |
| jsonlite | 2.0.0 | — |

The snapshot date must live in exactly one place (an `ENV`), not be repeated per `install.packages()`
call — four copies of a constant is how the current `repos=` override became four copies of a bug.

### Locked — base image pinning

`FROM rocker/r-ver:4.4@sha256:3dae5d2eeddf74f10e0a81fb6b7ae350295e288000304f438b844b2c1e00fe2c`

This is the **multi-arch index digest** resolved from the registry on 2026-08-25, not a
single-architecture digest — the CI runner is amd64 and local development is arm64, so both must
keep resolving. The image is R 4.4.3 (confirmed by running it).

Keep a human-readable comment next to the digest recording the tag and R version, since a bare
sha256 tells a future reader nothing.

### Locked — the stale template copy

Delete `.claude/skills/comsa-k8s-deploy/assets/dockerfiles/Dockerfile.backend` and point the skill
at `backend/Dockerfile` instead.

Two copies is the root cause, not a thing to be managed. The copy is already badly drifted — it is
missing `pool`, `jose`, `knitr`, `options(warn=2)`, and the entire Stan model recompilation step.
Project memory already records that rebuilding from this template reintroduces fixed bugs. Per
CLAUDE.md ("delete or archive legacy files when creating new versions"), deletion beats a sync check.

Check whether `Dockerfile.frontend` under the same directory has the same problem and treat it
consistently.

### Locked — proving criterion 4

Write an installed-package manifest into the image at build time (from `installed.packages()`),
and add a CI step that can rebuild and diff it.

A one-off manual comparison was rejected: project memory records that local builds are arm64 while
the runner is amd64, so a local double-build proves nothing about the artifact that actually ships.
The manifest also pays for itself during incident response — it makes "what versions are actually
in the running image" a file lookup rather than an archaeology exercise.

### Locked — the missing `sodium` install

Add `sodium` to an explicit `install.packages()` call.

`backend/auth/passwords.R` calls `library(sodium)` and `sodium::password_store()` /
`password_verify()`, but `sodium` appears in **no** `install.packages()` list — only the system
library `libsodium-dev` is installed via apt. It currently arrives transitively. If that transitive
edge disappears upstream, authentication breaks **at runtime**, while the build stays green.

### Claude's Discretion

- Exact Dockerfile layer ordering and how the snapshot `ENV` is threaded into each install call.
- Manifest file format and path inside the image.
- Where the CI diff step lives in `.github/workflows/deploy.yml` and whether it is advisory or blocking.
- Whether to also pin `frontend/Dockerfile`'s base image (nice-to-have; npm lockfile already covers its packages).
</decisions>

<code_context>
## Existing Code Insights

**`backend/Dockerfile`** — `FROM rocker/r-ver:4.4` (floating tag). Four separate
`install.packages()` calls, each hardcoding `repos='https://cloud.r-project.org'`:

1. `plumber, jsonlite, uuid, future, RPostgres, pool, jose`
2. `rJava` (after `R CMD javareconf`)
3. `openVA, EAVA, vacalibration, knitr`
4. A long `rstan` step that recompiles vacalibration's Stan models from source and overwrites the
   bundled `.rds` files — this is slow and must not be disturbed.

Application code is `COPY`'d late. Project memory: a failure *before* the COPY cannot have been
caused by a source change — that layer boundary is the attribution test.

**`.github/workflows/deploy.yml`** — `runs-on: ubuntu-latest` (amd64), builds `./backend/Dockerfile`
with `context: .`. Has a `check-changes` path-filter job; a frontend-only PR skips the backend image
and still reports success. All three of `check-changes` / `build-and-push` / `deploy` must be
`success` for a deploy to have actually happened.

**Existing apt layer already installs** `cmake` (added in #122 for RcppParallel) plus
`libsodium-dev`, `default-jdk`, and the usual `-dev` headers. Pinning must not remove these.

**No `renv.lock` and no `DESCRIPTION`** — there is no existing R dependency manifest to build on.

**Codebase maps exist** at `.planning/codebase/` (STACK.md, ARCHITECTURE.md, CONCERNS.md,
CONVENTIONS.md, INTEGRATIONS.md, STRUCTURE.md, TESTING.md) — read rather than re-derive.
</code_context>

<specifics>
## Specific Ideas

- The 8-day-old #122 outage is the motivating incident: `RcppParallel` began requiring `cmake` in a
  release published between 2026-07-28 and 2026-08-12, no backend deploy ran for 16 days, and the
  breakage surfaced on a PR that had touched only `.R` files. The snapshot pin is what prevents a
  rerun of that.
- Do not treat "green deploy" as proof. Verify per-job, and confirm the `deploy` job actually ran
  rather than being `skipped`.
- A local `docker build` is not a verdict — the Mac is arm64, the runner is amd64.
</specifics>

<deferred>
## Deferred Ideas

- The `check-changes` path filter that lets a frontend-only PR report success while the backend
  image is broken. Real, and from the same #122 post-mortem, but it is a CI-correctness problem
  rather than a build-reproducibility one.
- `frontend/Dockerfile` base-image pinning — low value while `package-lock.json` covers the
  packages; fold in only if it is nearly free.
- Any scheme for periodically advancing the snapshot date (a pinned build eventually becomes a
  stale build). Worth an issue once pinning exists; out of scope here.
</deferred>
