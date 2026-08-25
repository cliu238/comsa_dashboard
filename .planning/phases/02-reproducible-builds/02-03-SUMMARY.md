---
phase: 02-reproducible-builds
plan: 03
subsystem: infra
tags: [docker, dockerfile, ci, skill-assets, reproducible-builds]

# Dependency graph
requires:
  - phase: 02-reproducible-builds
    provides: "backend/Dockerfile pinned to a digest + dated CRAN snapshot (plan 02-01), and tests/test_dockerfile_pinning.R with 25 baseline assertions"
provides:
  - "comsa-k8s-deploy skill's assets/dockerfiles/ template copies deleted (both backend and frontend)"
  - "SKILL.md and references/deployment-guide.md repointed at backend/Dockerfile and frontend/Dockerfile as the single source of truth"
  - "SKILL.md v1.18 Version History entry recording the drift and removal"
  - "tests/test_dockerfile_pinning.R grown from 25 to 28 assertions: asserts the deleted template directory stays gone, exactly two tracked Dockerfiles exist, and no dangling reference to the deleted path remains"
affects: [02-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "git ls-files / git grep -l as the enumeration mechanism for 'exactly one file of this kind exists' CI assertions, run via git -C <repo-root> so the test works regardless of invocation cwd (project root or backend/)"

key-files:
  created: []
  modified:
    - .claude/skills/comsa-k8s-deploy/SKILL.md
    - .claude/skills/comsa-k8s-deploy/references/deployment-guide.md
    - tests/test_dockerfile_pinning.R
  deleted:
    - .claude/skills/comsa-k8s-deploy/assets/dockerfiles/Dockerfile.backend
    - .claude/skills/comsa-k8s-deploy/assets/dockerfiles/Dockerfile.frontend

key-decisions:
  - "Deleted both templates rather than syncing them, per CLAUDE.md ('delete or archive legacy files when creating new versions') and the phase's locked decision — verified independently that both were genuinely drifted before deleting, not on the plan's description alone"
  - "Wrote the v1.18 Version History drift list as one bullet per missing item (pool / jose / knitr / warn=2 / Stan / rm -rf dist) rather than a single prose paragraph, so the six-keyword documentation check (each on its own line) and the 'no literal assets/dockerfiles substring outside .planning/tests' check could both pass — grep -c counts matching lines, not occurrences, so keywords sharing a line under-count"
  - "Resolved the repo root via 'git rev-parse --show-toplevel' inside the new test section rather than relative-path guessing, so it works whether the test is invoked from the project root or backend/ (matching the existing dockerfile_path probing already in the file)"

requirements-completed: ["#123"]

# Metrics
duration: ~15min
completed: 2026-08-25
---

# Phase 02 Plan 03: Delete drifted Dockerfile templates from the k8s-deploy skill Summary

**Deleted both stale `Dockerfile.backend`/`Dockerfile.frontend` template copies carried inside the `comsa-k8s-deploy` skill, repointed `SKILL.md` and `deployment-guide.md` at the real `backend/Dockerfile`/`frontend/Dockerfile`, and grew `tests/test_dockerfile_pinning.R` from 25 to 28 assertions so a second copy or a dangling reference now fails CI.**

## Performance

- **Duration:** ~15 min
- **Completed:** 2026-08-25
- **Tasks:** 2/2
- **Files modified:** 3 modified, 2 deleted

## Accomplishments
- Verified the drift myself before deleting: the backend template was missing `pool`, `jose`, `knitr`, `options(warn=2)` on every install, the entire Stan model recompilation step (`seqcalib.stan`/`seqcalib_mmat.stan`), and the non-root user block (`groupadd`/`useradd`/`chown`/`USER appuser`); the frontend template was missing the `rm -rf dist/` cache-busting fix. All findings matched the plan's `<interfaces>` section exactly.
- Deleted `.claude/skills/comsa-k8s-deploy/assets/dockerfiles/Dockerfile.backend` and `Dockerfile.frontend` via `git rm`; the now-empty `assets/dockerfiles/` directory disappeared from the working tree automatically.
- `SKILL.md`: replaced the two `cp assets/dockerfiles/...` lines in Quick Setup step 1 with prose naming `backend/Dockerfile`/`frontend/Dockerfile` as the single source of truth; removed the `dockerfiles/` bullet from the Assets list; added a `### v1.18 - 2026-08-25` entry as the first Version History item recording what was removed, why, and the impact.
- `references/deployment-guide.md`: replaced the two `cp .claude/skills/.../assets/dockerfiles/...` lines with the equivalent statement.
- Confirmed via `git grep -n "assets/dockerfiles"` (own verification, not trusting the plan's line numbers) that only the 4 lines named in the plan referenced the deleted path anywhere outside `.planning/` — no other file needed touching.
- `tests/test_dockerfile_pinning.R`: appended a new `section("exactly one Dockerfile per service")` with 3 assertions, placed immediately before the existing summary/`quit()` block, reusing the file's `test()`/`section()` helpers. Measured the delta directly: `Total: 25` before my edit, `Total: 28` after — exactly +3 as the plan required.
- Proved the new section is load-bearing, not decorative: copied `backend/Dockerfile` back into a recreated `assets/dockerfiles/` directory, `git add -N`'d it, and reran the test — it failed with `exit=1` and FAIL lines for both the directory-absence assertion and the tracked-Dockerfile-set assertion (the third assertion, the dangling-reference check, correctly still passed since no doc referenced the path). Cleaned up with `git rm -f --cached` + `rm -rf`, confirmed the test returns to `exit=0`/`Failed: 0`, and confirmed `git status --porcelain` showed only the intended `tests/test_dockerfile_pinning.R` diff.
- Confirmed the test file remains base-R only (`grep -c 'requireNamespace\|library(' tests/test_dockerfile_pinning.R` → `0`), so it can still run in CI before "Install jsonlite".

## Task Commits

Each task was committed atomically:

1. **Task 1: Delete both templates and repoint the skill and the deployment guide** - `7854845` (docs)
2. **Task 2: Assert single-copy Dockerfiles from CI** - `2c8abb1` (test)

## Files Created/Modified
- `.claude/skills/comsa-k8s-deploy/assets/dockerfiles/Dockerfile.backend` - deleted (drifted, missing pool/jose/knitr/warn=2/Stan-recompile/non-root-user)
- `.claude/skills/comsa-k8s-deploy/assets/dockerfiles/Dockerfile.frontend` - deleted (drifted, missing `rm -rf dist/` cache-busting)
- `.claude/skills/comsa-k8s-deploy/SKILL.md` - Quick Setup and Assets list repointed at the repo's real Dockerfiles; new v1.18 Version History entry
- `.claude/skills/comsa-k8s-deploy/references/deployment-guide.md` - Initial Setup step 1 repointed at the repo's real Dockerfiles
- `tests/test_dockerfile_pinning.R` - new "exactly one Dockerfile per service" section (3 assertions): deleted template directory stays gone, `git ls-files` finds exactly `backend/Dockerfile` + `frontend/Dockerfile`, no tracked file outside `.planning/`/this test file still says `assets/dockerfiles`

## Decisions Made
- Followed the phase's locked decision to delete rather than sync the templates (CLAUDE.md: "delete or archive legacy files when creating new versions"), after independently confirming the drift rather than trusting the plan's description.
- Restructured the v1.18 Version History drift list into one bullet per missing item instead of flowing prose, purely to satisfy two competing automated checks: (a) at least 6 of `pool`/`jose`/`knitr`/`warn=2`/`Stan`/`rm -rf dist` on distinct matching lines, and (b) zero occurrences of the literal substring `assets/dockerfiles` outside `.planning/`/`tests/` (the entry describes the deleted location without using that exact path string).
- Used `git -C <repo_root> ls-files` / `git -C <repo_root> grep -l` (repo root resolved via `git rev-parse --show-toplevel`) rather than relative paths, so the new test section works identically whether invoked from the project root or from `backend/`, consistent with the existing `dockerfile_path` probing already in the file.

## Deviations from Plan

None affecting scope or files touched. One in-task adjustment: my first draft of the v1.18 Version History entry included the literal string `assets/dockerfiles` (naming the deleted files), which would have failed Task 1's own automated verify command (`git grep -l 'assets/dockerfiles' -- . ':!.planning' ':!tests'` must return nothing). Reworded the entry to describe the deleted location without the literal path string before committing — caught and fixed during Task 1's own verification, not a post-hoc deviation from committed work.

## Threat Flags

None. This plan closes threat register items T-02-10/11/12; T-02-13 (see below) was explicitly accepted, not mitigated.

## Out-of-Scope Observation (recorded per plan's `<output>` instruction)

`.claude/skills/comsa-k8s-deploy/assets/.github/workflows/deploy.yml` is a **third** drifted, copied-and-templated asset with the same duplication failure mode as the two Dockerfiles just deleted here. Confirmed by diffing it against the real `.github/workflows/deploy.yml`: the template still has `cache-from: type=gha` / `cache-to: type=gha,mode=max` (Docker layer caching), while the real workflow has been changed to `no-cache: true`. This phase's CONTEXT explicitly bounds scope to the Dockerfile copies (T-02-13 in the plan's threat model is `disposition: accept`), so it was left untouched. It does not undo any of this phase's pinning work (it copies a workflow, not a Dockerfile), but it is the same root-cause pattern and should be folded into a future cleanup.

## Test Results

`Rscript tests/test_dockerfile_pinning.R` — **Total: 28  Passed: 28  Failed: 0** (grew from the 25-assertion baseline recorded in `02-01-SUMMARY.md`, delta measured directly before and after editing, not assumed).

Negative-test proof (per Task 2 acceptance criteria): recreating `assets/dockerfiles/Dockerfile.backend` and staging it with `git add -N` produced `Total: 28  Passed: 26  Failed: 2`, `exit=1`, with FAIL lines for "the deleted assets/dockerfiles template directory does not exist" and "the only tracked Dockerfiles are backend/Dockerfile and frontend/Dockerfile". After `git rm -f --cached` + `rm -rf` cleanup, the test returned to `Failed: 0`/`exit=0` and `git status --porcelain` showed no stray files.

## Issues Encountered
None beyond the in-task wording fix documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- `backend/Dockerfile` is now the sole tracked Dockerfile for the backend, with no unpinned template a reader could accidentally `cp` over it, and `frontend/Dockerfile` is likewise the sole tracked frontend Dockerfile.
- `tests/test_dockerfile_pinning.R`'s `Total: 28` count is the number a future plan appending to this file should diff against.
- Recorded but explicitly out of scope: `.claude/skills/comsa-k8s-deploy/assets/.github/workflows/deploy.yml` is a third drifted copied asset (Docker cache settings), left untouched per this phase's CONTEXT — candidate for a later cleanup plan.
- No blockers identified. `.github/workflows/deploy.yml` was not touched by this plan (owned by the concurrent 02-02 executor).

---
*Phase: 02-reproducible-builds*
*Completed: 2026-08-25*

## Self-Check: PASSED

- FOUND: .claude/skills/comsa-k8s-deploy/SKILL.md
- FOUND (deleted as expected): .claude/skills/comsa-k8s-deploy/assets/dockerfiles/Dockerfile.backend no longer exists
- FOUND: tests/test_dockerfile_pinning.R
- FOUND commit: 7854845 (docs: delete drifted Dockerfile templates and repoint skill docs)
- FOUND commit: 2c8abb1 (test: assert exactly one Dockerfile per service in CI)
