---
phase: 02-reproducible-builds
plan: 02
subsystem: infra
tags: [github-actions, ci, docker, reproducible-builds, deploy]

# Dependency graph
requires:
  - phase: 02-reproducible-builds (plan 01)
    provides: "backend/Dockerfile writes /opt/package-manifest.csv (Package,Version CSV, LC_COLLATE=C, quote=FALSE) before COPY"
provides:
  - "workflow_dispatch force_backend_rebuild boolean input (default false), wired to no-cache and to the backend build step's if: condition"
  - "id: build-backend on the backend docker/build-push-action@v5 step, exposing outputs.digest for downstream verification"
  - "Verify backend package manifest (issue #123) step: pulls the built image by digest, extracts /opt/package-manifest.csv, validates its shape, diffs it against backend/package-manifest.csv (advisory if absent, blocking if present), writes a summary"
  - "backend-package-manifest artifact upload on always(), so the manifest survives a failed diff"
affects: [02-04]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Digest-pinned re-verification: never re-pull a just-built image by mutable tag; use the build step's outputs.digest so verification can't race a concurrent push"
    - "Advisory-then-blocking gate: a check that no-ops loudly (exit 0 + loud summary notice) until its golden file exists, then becomes a hard gate (exit 1) once committed — avoids a bootstrap deadlock where a golden file can only be produced by a passing gate"

key-files:
  created: []
  modified:
    - .github/workflows/deploy.yml

key-decisions:
  - "Inserted the two new steps between the backend build step and 'Extract metadata for frontend', so the verification runs immediately after the image it verifies is pushed, and before any frontend-related work"
  - "Guarded manifest extraction with three explicit shape checks (non-empty, header exactly 'Package,Version', >100 data rows) before touching backend/package-manifest.csv at all, per the plan's T-02-09 vacuous-pass mitigation"
  - "docker run for extraction uses --rm, no volume mounts, no -e, and a single `cat` command — GITHUB_TOKEN is never exposed to the freshly built image (T-02-08)"
  - "Did not touch check-changes, the frontend build step, the deploy job's if:, or the permissions block — confirmed via diff against the wave-1 base commit that only the on: block and the backend build step region changed"

requirements-completed: ["#123"]

# Metrics
duration: ~20min
completed: 2026-08-25
---

# Phase 02 Plan 02: Wire manifest verification into deploy.yml Summary

**Adds a digest-pinned package-manifest extraction, shape-validated diff, and always-on artifact upload to `.github/workflows/deploy.yml`, plus an opt-in `force_backend_rebuild` cache-free rebuild switch — none of it has been observed running in CI.**

## Performance

- **Duration:** ~20 min
- **Completed:** 2026-08-25
- **Tasks:** 2/2
- **Files modified:** 1

## Accomplishments
- `workflow_dispatch` now accepts a boolean `force_backend_rebuild` input (default `false`). On a `push` event `inputs.force_backend_rebuild` evaluates to null/falsy, so ordinary push behavior is byte-for-byte unchanged in effect (only the `if:` and `with:` expressions grew a new clause).
- The backend `docker/build-push-action@v5` step gained `id: build-backend` and now also fires when `inputs.force_backend_rebuild` is true, with `no-cache: ${{ inputs.force_backend_rebuild || false }}`.
- A new `Verify backend package manifest (issue #123)` step: pulls `${REGISTRY}/${BACKEND_IMAGE_NAME}@${{ steps.build-backend.outputs.digest }}` (digest, never `:latest`), runs `docker run --rm ... cat /opt/package-manifest.csv > actual-package-manifest.csv` with no mounts/env/network flags, validates the extraction (non-empty, header exactly `Package,Version`, >100 data rows) before trusting it, writes a version table for 15 load-bearing packages to `$GITHUB_STEP_SUMMARY`, then either notices loudly that no golden manifest exists yet (exit 0, bootstrap case) or diffs against `backend/package-manifest.csv` and fails the step (exit 1) with the diff and likely cause in the summary.
- A new `Upload backend package manifest` step publishes `actual-package-manifest.csv` as artifact `backend-package-manifest` on `always() && steps.build-backend.outcome == 'success'`, so the evidence is downloadable even when the diff step failed.
- `deploy` job's `if: always() && needs.build-and-push.result != 'failure'` was left untouched — a failing manifest diff fails `build-and-push`, which this existing condition already treats as blocking.

## Task Commits

Each task was committed atomically:

1. **Task 1: Add an on-demand cache-free backend rebuild switch** - `1c9b2bc` (feat)
2. **Task 2: Extract, diff and publish the built image's package manifest** - `b011a0a` (feat)

## Files Created/Modified
- `.github/workflows/deploy.yml` - `workflow_dispatch.inputs.force_backend_rebuild`; `id: build-backend` + widened `if:` + `no-cache:` on the backend build step; new `Verify backend package manifest (issue #123)` and `Upload backend package manifest` steps inserted before `Extract metadata for frontend`

## Decisions Made
- Followed the plan's exact placement, guard conditions, and shape-validation thresholds (>100 rows) rather than inventing new ones.
- Kept the manifest summary to a fixed 15-package table (the load-bearing set named in the plan) rather than dumping the full ~200+ row CSV into `$GITHUB_STEP_SUMMARY`, per CLAUDE.md's "keep log simple."
- Confirmed via `git diff <wave-1-base> HEAD -- .github/workflows/deploy.yml` that every changed line falls inside the `on:` block or the backend-build-step region; `check-changes`, the frontend build step, `deploy`, and the job `permissions` blocks have zero diff lines.

## Deviations from Plan

None - plan executed exactly as written. Both tasks' automated verify one-liners and all listed acceptance-criteria one-liners were run and printed `ok` / matched expected values.

## Issues Encountered

None. One process note: this agent's worktree HEAD was initially based on the wrong commit (an earlier wave-1 worktree tip rather than the merged `0d4852b3` wave-1 merge commit) at startup; the mandated pre-execution HEAD/base assertion caught this before any file edit and corrected it via `git reset --hard` while the working tree was still clean, per the `<worktree_branch_check>` protocol.

## Verification Performed (static only)

- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/deploy.yml'))"` — parses cleanly.
- Both task-level automated verify one-liners from `02-02-PLAN.md` — printed `ok`.
- All acceptance-criteria one-liners from both tasks (workflow_dispatch shape, frontend no-cache unchanged, deploy/permissions/path-filter unchanged, `:latest` occurrence count unchanged pre/post, `Package,Version` present, step ordering `build-backend < verify-manifest < meta-frontend`, exactly 4 steps in `build-and-push` carry an `if:`) — all printed `ok` or matched expected values.
- `git diff --numstat` and a full `git diff` review confirmed the changes are additive/localized: Task 1 touched 13 lines (1 deletion, replaced by a wider `if:`), Task 2 added 76 lines with zero deletions.
- `git diff --diff-filter=D` after each commit — no unexpected file deletions.

## Verification NOT Performed (explicitly deferred to plan 02-04)

**None of the new workflow steps have been run.** This agent can statically validate and lint the YAML but cannot push to GitHub, trigger `workflow_dispatch`, or observe an Actions run. Specifically, none of the following has been observed:
- The backend image has not been built by this workflow with the new `id: build-backend`, so `outputs.digest` has never actually been populated or referenced.
- `docker pull`/`docker run --rm ... cat /opt/package-manifest.csv` has not been executed against a real pushed image — the extraction command's behavior against the true manifest shape (header, row count) is inferred from `backend/Dockerfile`'s `write.csv` call (confirmed by reading the file, not assumed) but not exercised.
- The advisory bootstrap path (`backend/package-manifest.csv` absent) has not been exercised — that file does not exist in this repo yet (confirmed: plan 02-04 owns freezing it from a real CI artifact).
- The blocking diff path, the `$GITHUB_STEP_SUMMARY` rendering, and the `backend-package-manifest` artifact upload have never run in CI.
- `force_backend_rebuild=true` has never been dispatched; the cache-free rebuild path is unverified beyond YAML structure.

Plan 02-04 is explicitly the plan that owns obtaining this live proof.

## User Setup Required

None - no external service configuration required. No secrets, permissions, or network egress were added; the container run in the new step is `--rm`, no mounts, no `-e`, no `GITHUB_TOKEN`.

## Next Phase Readiness
- `deploy.yml` is ready for plan 02-04 to trigger a real `workflow_dispatch` run (or a normal push touching `backend/**`), download the `backend-package-manifest` artifact from that run, and commit it as `backend/package-manifest.csv` — at which point the diff step becomes blocking for all future builds.
- Plan 02-03 (parallel, `.claude/skills/comsa-k8s-deploy/**` and `tests/test_dockerfile_pinning.R`) was not touched by this plan; file-set boundaries were respected throughout.
- No blockers identified.

---
*Phase: 02-reproducible-builds*
*Completed: 2026-08-25*

## Self-Check: PASSED

- FOUND: .github/workflows/deploy.yml
- FOUND: .planning/phases/02-reproducible-builds/02-02-SUMMARY.md
- FOUND commit: 1c9b2bc (feat: on-demand cache-free backend rebuild switch)
- FOUND commit: b011a0a (feat: extract, diff and publish backend package manifest)
