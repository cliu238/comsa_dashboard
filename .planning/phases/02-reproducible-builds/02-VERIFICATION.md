---
phase: 02-reproducible-builds
verified: 2026-08-25T19:30:00Z
status: passed
score: 4/4 must-haves verified
overrides_applied: 0
human_verification_accepted:
  accepted_by: user
  accepted: "2026-08-25"
  rationale: "The one human_verification item (a real successful login exercising sodium::password_verify()) does not gate ROADMAP criterion 2, which is worded about the install mechanism and is fully verified from source: explicit install.packages(c(..., 'sodium')), a build-time stopifnot guard that fails the image build if sodium is absent, and sodium,1.4.0 recorded in backend/package-manifest.csv. Live evidence additionally shows the auth module loads in the deployed image (clean 401 rather than a 500). Tracked as a pending item in 02-HUMAN-UAT.md rather than blocking the phase."

human_verification:
  - test: "Log in with a real, existing account and a correct password against the deployed backend (or a local instance built from the pinned Dockerfile)."
    expected: "HTTP 200 with a JWT token, proving sodium::password_verify() (not just library(sodium)) executes correctly against the pinned sodium version."
    why_human: "The available live evidence (a 401 against a nonexistent email) only proves module load, not the hash-verification code path, because backend/plumber.R's is.null(user) || !verify_password(...) short-circuits before verify_password() runs for a nonexistent user. Does not block phase completion (roadmap criterion 2 is about install mechanism, fully verified from source) but is the one residual gap in end-to-end proof."
---

# Phase 2: Reproducible builds Verification Report

**Phase Goal:** An unchanged commit builds the same image regardless of when it is built, so upstream package releases cannot break deploys or be misattributed to unrelated commits.
**Verified:** 2026-08-25T19:30:00Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (roadmap Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | R package versions are pinned (dated snapshot repo or equivalent) | VERIFIED | `backend/Dockerfile` line 53: `ENV CRAN_SNAPSHOT=https://p3m.dev/cran/__linux__/noble/2026-08-01`, appended once to `Rprofile.site` (line 60). All four previous `repos='https://cloud.r-project.org'` overrides are gone; `cloud.r-project.org` does not appear anywhere in the file (grep confirms zero matches). `tests/test_dockerfile_pinning.R` asserts single-source-of-truth and passes (28/28, run independently, see below). |
| 2 | `sodium` is installed explicitly rather than arriving transitively via `plumber` | VERIFIED (with a noted runtime-proof gap, non-blocking) | `backend/Dockerfile` line 69: `install.packages(c('plumber', 'jsonlite', 'uuid', 'future', 'RPostgres', 'pool', 'jose', 'sodium'))` — sodium is now a peer, not a transitive dependent. A build-time `stopifnot('sodium' %in% pkgs$Package, ...)` (line 117) fails the build if it's ever missing. Golden manifest (`backend/package-manifest.csv`) records `sodium,1.4.0`. Independently confirmed via a real `library(sodium)` load path: `POST /api/auth/login` on the deployed pod returned a clean `401` (not 500) — `backend/auth/passwords.R` calls `library(sodium)` at source time, so a missing package would have crashed module load. Gap: the probe used a nonexistent email, which short-circuits `find_user_by_email` before `verify_password()` calls `sodium::password_verify()` (confirmed by reading `backend/plumber.R` lines 153-157: `is.null(user) || !verify_password(...)` short-circuits on the first clause). This proves `library(sodium)` resolves at load time but not that the hash-verification code path executed. The roadmap criterion is about **installation mechanism** ("installed explicitly ... rather than arriving transitively"), which is fully satisfied by source + build-time guard + committed manifest independent of this runtime nuance. Flagged as a human-verification item below for completeness, not as a blocker. |
| 3 | The base image tag is pinned to a digest or patch version | VERIFIED | `backend/Dockerfile` line 8: `FROM rocker/r-ver:4.4@sha256:3dae5d2eeddf74f10e0a81fb6b7ae350295e288000304f438b844b2c1e00fe2c` — a multi-arch index digest, not a floating tag. Comment documents resolution date and R version (4.4.3). |
| 4 | Building the same commit twice yields identical installed package versions | VERIFIED — independently reproduced, not just trusted from CI's own diff logic | See "Independent Data-Flow / Live-Evidence Verification" below. I downloaded the actual `backend-package-manifest` artifact from GitHub Actions run 32884818317 (a genuine `--no-cache` rebuild of commit `e979ffd`) and diffed it byte-for-byte against the committed `backend/package-manifest.csv` myself, outside the CI script's own logic. The two files are **identical** (135 lines, 0 diff). This closes the circularity concern about the CI diff step raised in the task brief. |

**Score:** 4/4 truths verified

### Independent Data-Flow / Live-Evidence Verification (issue (a) and (b) from task brief)

**Issue (a) — is criterion 4 genuinely proven or circular?**

Re-derived independently rather than trusting the SUMMARY's narrative:

1. Confirmed `backend/package-manifest.csv` is 135 lines / 134 packages and was committed at `e979ffd` (`git show e979ffd --stat`), predating run 32884818317.
2. Read `.github/workflows/deploy.yml` lines 120-191 directly. The advisory/blocking branch keys on `[ ! -f backend/package-manifest.csv ]` (line 167) — a plain file-existence test, not a flag or env var that could be stale. Since the file exists, execution falls through to the `diff -u backend/package-manifest.csv actual-package-manifest.csv > manifest.diff` branch (line 177), which is a real `diff -u`, not `|| true` or a discarded exit code. `if ! diff ...; then ... exit 1; fi` runs under `set -euo pipefail` (line 124) — a real difference triggers `exit 1` inside the `if` body, which is not itself subject to `set -e` suppression (an `if` condition's failure never triggers `set -e`, but the explicit `exit 1` inside the body does terminate the script). The step is not vacuously passable: it also independently guards against an empty/malformed/truncated capture (lines 131-144: non-empty check, header-exact-match check, >100-row check) before ever reaching the diff.
3. **Verified the chain empirically rather than trusting the reasoning alone**: downloaded the `backend-package-manifest` artifact GitHub Actions actually produced for run 32884818317 (the `--no-cache` dispatch) via `gh run download 32884818317 -n backend-package-manifest`, and ran `diff` against `backend/package-manifest.csv` myself in a scratch directory. Result: **0 differences, byte-identical, both 135 lines.** This is a verification independent of the CI script's own diff logic — even if the script had a bug, my own diff of the actual uploaded artifact against the actual committed file proves criterion 4 directly.
4. Also independently confirmed via `gh run view 97922741101 --log` that the backend build step's command line included `--no-cache` and that the step (`Verify backend package manifest`) concluded `success`, and via `gh run view 32884818317 --json jobs` that all three jobs (`check-changes`, `build-and-push`, `deploy`) concluded `success` with no `skipped` status — reading per-job, not the overall run conclusion, per the task's own caution.
5. A third run (32885706868, push event, SHA `e6df19a`) was also independently queried and confirmed `success` on all three jobs — an additional, unprompted regression check beyond the two runs the plan called for.

**Conclusion on (a):** Not circular. The blocking path is real, the diff mechanism is real, and I obtained and diffed the actual artifact myself, which is stronger evidence than validating the mechanism alone.

**Issue (b) — is criterion 2 fully met?**

Read `backend/plumber.R` (`/auth/login` handler) directly: `user <- find_user_by_email(email); if (is.null(user) || !verify_password(...))`. Confirmed the short-circuit: a nonexistent email means `is.null(user)` is `TRUE`, so `verify_password()` (and therefore `sodium::password_verify()`) is never called. The orchestrator's flagged concern is accurate — the login probe with invalid credentials proves `library(sodium)` resolves at load time, not that the hash-verification call path executed.

**Judgment:** The roadmap's criterion 2 wording — "`sodium` is installed explicitly rather than arriving transitively via `plumber`" — is a statement about the **install mechanism**, not about proving a specific runtime code path executes end-to-end. That mechanism is fully and directly verifiable from source (`install.packages()` call, `stopifnot()` guard, golden manifest entry) independent of any login test. I am treating criterion 2 as VERIFIED on that basis, but flagging the deeper runtime question ("does a real successful login exercise `sodium::password_verify()` correctly") as a human-verification item since it is a legitimate residual gap in end-to-end proof, even though it sits slightly outside this phase's literal success-criterion wording.

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `backend/Dockerfile` | digest-pinned base, single-source CRAN snapshot, explicit sodium, in-image manifest, cmake/libsodium-dev/Stan-step/late-COPY intact | VERIFIED | All elements present and in correct order (installs precede `COPY backend/ /app/` at line 125; manifest write at lines 113-119 precedes COPY). |
| `tests/test_dockerfile_pinning.R` | regression guard, 28 assertions (25 base + 3 from 02-03) | VERIFIED | Ran independently: `Rscript tests/test_dockerfile_pinning.R` → `Total: 28  Passed: 28  Failed: 0`. |
| `.github/workflows/test.yml` | runs the pinning guard on every PR/push | VERIFIED | Line 73-74: `Dockerfile pinning guard (issue #123)` step runs `Rscript tests/test_dockerfile_pinning.R` before "Install jsonlite", in the `backend` job (`pull_request` + `push: [master]` triggers). |
| `.github/workflows/deploy.yml` | force_backend_rebuild input, manifest extraction/diff, artifact upload | VERIFIED | `workflow_dispatch.inputs.force_backend_rebuild` (line 9), `id: build-backend` with `no-cache: ${{ inputs.force_backend_rebuild || false }}` (lines 73, 84), `Verify backend package manifest` step (lines 120-191), `Upload backend package manifest` on `always()` (lines 193-198). Live-run-verified, not just statically read. |
| `backend/package-manifest.csv` | golden manifest, 134 packages incl. sodium/vacalibration/EAVA/openVA/RcppParallel at pinned versions | VERIFIED | 135 lines (134 packages + header). Confirmed byte-identical to a live cache-free rebuild's extracted manifest (see above). Spot-checked: `vacalibration,2.2`; `EAVA,1.0.0`; `openVA,1.2.0`; `RcppParallel,6.2.0`; `sodium,1.4.0`; `plumber,1.3.3`; `jose,2.0.0`; `pool,1.0.5`; `knitr,1.51`; `rstan,2.32.7` — all match 02-CONTEXT.md's locked snapshot table exactly. |
| `.claude/skills/comsa-k8s-deploy/assets/dockerfiles/Dockerfile.backend` / `.frontend` | deleted | VERIFIED | `find` for `*dockerfile*` under the skill directory returns nothing; `git ls-files \| grep -i dockerfile` returns only `backend/Dockerfile`, `frontend/Dockerfile`, `tests/test_dockerfile_pinning.R`. |
| `.claude/skills/comsa-k8s-deploy/SKILL.md` | repointed at repo Dockerfiles, v1.18 entry | VERIFIED | Line 23 has `### v1.18 - 2026-08-25`; lines 201/237 name `backend/Dockerfile`/`frontend/Dockerfile` as the real files; no `cp assets/dockerfiles/...` instruction remains (grep for that pattern returns nothing). |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|----|--------|---------|
| `backend/Dockerfile` | `/usr/local/lib/R/etc/Rprofile.site` | single `RUN echo ... >> Rprofile.site` from `CRAN_SNAPSHOT` ENV | WIRED | Line 60, confirmed append (`>>`) not overwrite, guard-tested by `test_dockerfile_pinning.R`. |
| `backend/Dockerfile` | `/opt/package-manifest.csv` | `installed.packages()` write before `COPY` | WIRED | Lines 113-119, precedes `COPY backend/ /app/` at line 125. |
| `.github/workflows/test.yml` | `tests/test_dockerfile_pinning.R` | `Rscript` step in `backend` job | WIRED | Confirmed present, and the test passes when run. |
| `.github/workflows/deploy.yml` | `/opt/package-manifest.csv` in the built image | `docker pull`/`docker run` against `steps.build-backend.outputs.digest` | WIRED — confirmed live | Verified via a real CI run (32884818317): image pulled by digest (not `:latest`), manifest extracted, matched golden file. |
| `.github/workflows/deploy.yml` | `backend/package-manifest.csv` | `diff -u` | WIRED — confirmed live and blocking | Golden file exists → blocking path taken → step succeeded with a real, non-vacuous diff, confirmed by independently downloading and diffing the artifact myself. |
| `tests/test_dockerfile_pinning.R` | `git ls-files` | enumerating tracked Dockerfiles, asserting exactly `backend/Dockerfile` + `frontend/Dockerfile` | WIRED | Confirmed passing as part of the 28/28 run; negative-test proof documented in 02-03-SUMMARY.md (recreating a template file makes 2 of the 3 new assertions fail). |

### Behavioral Spot-Checks / Probe Execution

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Dockerfile pinning guard passes from source | `Rscript tests/test_dockerfile_pinning.R` | `Total: 28  Passed: 28  Failed: 0` | PASS (run independently by verifier) |
| CI actually rebuilt with no cache and diffed clean | `gh run view 32884818317 --json jobs`, `gh run view --job=97922741101 --log` | all 3 jobs `success`; `--no-cache` present on `docker buildx build` command line; `Verify backend package manifest` step `success` | PASS (independently re-queried, not trusted from orchestrator transcription) |
| Rebuilt manifest artifact matches committed golden manifest | `gh run download 32884818317 -n backend-package-manifest`; `diff` against `backend/package-manifest.csv` | 0 differences, 135 lines both sides | PASS (strongest available evidence — bypasses the CI script's own diff logic entirely) |
| Regression run (unrelated push) still passes | `gh run view 32885706868 --json jobs` | all 3 jobs `success`, SHA `e6df19a` | PASS |
| Deployed pod loaded the sodium-dependent auth module | `curl .../api/health`; `POST /api/auth/login` with bad creds | `200 {"status":["ok"]}`; `401` clean JSON (not 500) | PASS (load-time proof only, per caveat above) |

### Anti-Patterns Found

None. Scanned `backend/Dockerfile`, `.github/workflows/deploy.yml`, `.github/workflows/test.yml`, `tests/test_dockerfile_pinning.R`, `.claude/skills/comsa-k8s-deploy/SKILL.md`, `.claude/skills/comsa-k8s-deploy/references/deployment-guide.md`, and `backend/package-manifest.csv` for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER` — zero matches across all files.

One pre-existing, explicitly-documented, out-of-scope limitation is called out directly in `backend/Dockerfile`'s own comment (lines 17-23): the `apt-get` system-dependency layer is still unpinned (no snapshot.ubuntu.com pin), so a cache-free rebuild could in principle pick up different system libraries even though R package versions are pinned. This is documented as a known follow-up in the Dockerfile itself and was explicitly out of this phase's scope per `02-CONTEXT.md` ("Out of scope: ... any change to application behaviour" / the phase targeted the R/CRAN pinning class of failure that caused #122, not apt). Not treated as a gap against this phase's stated success criteria, which are R-package/base-image scoped, but noted for future-phase awareness.

A second pre-existing out-of-scope duplication, documented in `02-03-SUMMARY.md`, is `.claude/skills/comsa-k8s-deploy/assets/.github/workflows/deploy.yml` — a third drifted template asset (missing the `no-cache` change) with the same root-cause pattern as the two deleted Dockerfiles, explicitly accepted as out-of-scope (T-02-13) in the phase's threat model. Recorded here for visibility, not a gap.

### Requirements Coverage

No R-numbered requirement IDs are declared for this phase (`REQUIREMENTS.md` line 78: "Issues #123 (dependency pinning), #114 (retention policy), #62, #49" — tracked by GitHub issue, not requirement ID, consistent with the task's framing). All four plans declare `requirements: ["#123"]`. Verified against the roadmap's four Success Criteria directly (see Observable Truths table above) — all four SATISFIED.

### Human Verification Required

### 1. End-to-end successful login exercising `sodium::password_verify()`

**Test:** Log in with a real, existing account and a correct password against the deployed backend (or a local instance built from the pinned Dockerfile).
**Expected:** HTTP 200 with a JWT token, proving `sodium::password_verify()` (not just `library(sodium)`) executes correctly against the pinned `sodium` version.
**Why human:** The available live evidence (a 401 against a nonexistent email) only proves module load, not the hash-verification code path, because `backend/plumber.R`'s `is.null(user) || !verify_password(...)` short-circuits before `verify_password()` runs for a nonexistent user. This does not block phase completion since the roadmap criterion is about the install mechanism (which is fully verified from source), but it is the one residual gap in true end-to-end proof and is cheap for a human to close with one real login attempt.

### Gaps Summary

No blocking gaps. All four roadmap Success Criteria are verified from source, from an independently re-executed test suite (28/28), and from independently re-queried and independently-diffed live CI evidence — including downloading the actual cache-free-rebuild artifact and diffing it myself against the committed golden manifest, which resolves the potential circularity in the CI's own diff-gate reasoning. The one residual item (real successful login exercising `sodium::password_verify()`) is flagged for human verification as a matter of thoroughness, not as a phase-blocking gap, since it lies slightly outside the literal wording of success criterion 2.

---

_Verified: 2026-08-25T19:30:00Z_
_Verifier: Claude (gsd-verifier)_
