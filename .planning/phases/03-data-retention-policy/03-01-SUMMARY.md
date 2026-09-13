---
phase: 03-data-retention-policy
plan: 01
subsystem: database
tags: [r, plumber, postgresql, later, data-retention, tdd, dockerfile-pinning]

# Dependency graph
requires:
  - phase: 02-reproducible-builds
    provides: "tests/test_dockerfile_pinning.R's comment-stripped source-assertion idiom and the sodium-as-explicit-dependency pattern, reused verbatim for later"
provides:
  - "backend/db/retention.R: RETENTION_DAYS=90, retention_purge_sql(), job_disk_paths(), remove_job_disk(), purge_expired_jobs(), schedule_purge()"
  - "The purge wired into backend/db/connection.R's get_db_pool(), inside the existing COMSA_WORKER guard, beside cleanup_orphaned_jobs()"
  - "tests/test_retention.R: 32 dependency-free assertions covering every D-11 edge case, written and seen to fail (RED) before the implementation existed"
  - "later made an explicit backend/Dockerfile dependency with a byte-identical package-manifest.csv, and tests/test_retention.R registered by name in .github/workflows/test.yml"
affects: ["03-02", "03-03", "deploy/k8s-dev", "README.md", "frontend job-list notice"]

# Actuals (#2632)
actuals:
  tokens: 5926
  tasks: 2
  commits: 4

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Startup-once + 24h-self-reschedule maintenance task, guarded by the existing COMSA_WORKER != \"1\" check and tryCatch/message() error posture (mirrors cleanup_orphaned_jobs())"
    - "Pure SQL-generator function (retention_purge_sql()) whose output string is both the executed statement and the thing dependency-free tests assert against -- no parallel reimplementation of the predicate"
    - "Comment-stripped source-assertion tests (code <- lines[!grepl(\"^\\\\s*#\", lines)]) for wiring/guard properties that cannot be exercised behaviourally without a live Postgres"

key-files:
  created:
    - backend/db/retention.R
    - tests/test_retention.R
  modified:
    - backend/db/connection.R
    - backend/Dockerfile
    - tests/test_dockerfile_pinning.R
    - .github/workflows/test.yml

key-decisions:
  - "Age comparison (NOW() - INTERVAL '90 days') happens in SQL on the DB server, not R, since jobs.created_at/completed_at are naive TIMESTAMPs written by the DB's own NOW() -- an R-side cutoff would depend on the pod's TZ"
  - "remove_job_disk()'s empty-job-id guard returns before calling unlink() at all, rather than existence-checking afterward -- a naive file.path(\"data\", \"uploads\", \"\") would address the shared parent directory and unlink(recursive=TRUE) would wipe every job's uploads in one call"
  - "purge_expired_jobs() iterates result$id and calls remove_job_disk(id) with the default (lazily-evaluated) metadata_path, so production always reads connection.R's single get_job_metadata_path() definition, while tests supply the path explicitly and never force that default"

patterns-established:
  - "A second main-server-only maintenance task lives beside cleanup_orphaned_jobs() in the same COMSA_WORKER guard rather than introducing a second guard -- the precedent for any future startup/periodic task"

requirements-completed: ["#114", "D-01", "D-02", "D-03", "D-04", "D-05", "D-06", "D-07", "D-08", "D-11"]

coverage:
  - id: D1
    description: "A job past its 90-day window is deleted end to end: one age-predicated DELETE against jobs (cascading to logs/files), the matching pod-local uploads/outputs/metadata removal, wired into main-server pool init and re-armed every 24h, with an auditable log line and a failure posture that cannot take the server down"
    requirement: "#114"
    verification:
      - kind: unit
        ref: "Rscript tests/test_retention.R"
        status: pass
    human_judgment: false
  - id: D2
    description: "later is an explicit image dependency with a byte-identical package manifest, and the new retention suite runs by name in CI"
    requirement: "D-06"
    verification:
      - kind: unit
        ref: "Rscript tests/test_dockerfile_pinning.R"
        status: pass
      - kind: other
        ref: "set -e sweep: test_dockerfile_pinning.R, test_misclass_matrix.R, test_auth_visibility.R, test_cors.R, test_input_persistence.R, test_retention.R"
        status: pass
    human_judgment: false

# Metrics
duration: 35min
completed: 2026-09-13
status: complete
---

# Phase 3 Plan 1: Data retention purge Summary

**A 90-day COALESCE(completed_at, created_at)-aged `DELETE FROM jobs ... RETURNING id` purges every job through the existing cascade, removes its three pod-local paths, runs at pool init and every 24h via `later::later()` behind the existing `COMSA_WORKER` guard — proven by 32 dependency-free assertions written RED first.**

## Performance

- **Duration:** 35 min
- **Started:** 2026-09-13T04:45:00Z
- **Completed:** 2026-09-13T05:21:00Z
- **Tasks:** 2 completed
- **Files modified:** 6 (2 created, 4 modified)

## Accomplishments

- `backend/db/retention.R`: `RETENTION_DAYS <- 90` (the single source of the window), `retention_purge_sql()` returning the exact executed `DELETE FROM jobs WHERE COALESCE(completed_at, created_at) < NOW() - INTERVAL '90 days' RETURNING id`, `job_disk_paths()`/`remove_job_disk()` for the three pod-local paths (empty-id guarded), `purge_expired_jobs()` (tryCatch-wrapped, logs count + ids), `schedule_purge()` (self-re-arming 24h tick via `later::later()`)
- Wired into `backend/db/connection.R`'s `get_db_pool()`, inside the existing `COMSA_WORKER != "1"` guard, immediately beside `cleanup_orphaned_jobs()` — no second guard introduced
- `tests/test_retention.R`: 32 dependency-free (base-R-only) assertions covering the predicate's exact SQL shape, the disk-removal edge cases (all/one/none present, sibling survival, the empty-id DoS guard), and the source-level wiring/guard/reschedule properties — verified RED (26/32 failing, exit 1) before `backend/db/retention.R` existed, then GREEN (32/32 passing, exit 0)
- `later` added to `backend/Dockerfile`'s explicit `install.packages()` vector (the "sodium lesson") with `backend/package-manifest.csv` left byte-identical (already recorded `later,1.4.8` as a plumber transitive)
- `tests/test_dockerfile_pinning.R` extended with a "later is an explicit dependency" section (42/42 assertions passing)
- `.github/workflows/test.yml` backend job now runs `tests/test_retention.R` as a named step, "Data retention purge (issue #114)"

## Task Commits

Each task was committed atomically (Task 1 is `type="tracer" tdd="true"`, producing the full RED→GREEN cycle plus one inline test-bug fix found during GREEN verification):

1. **Task 1 — RED: failing retention purge tests** - `142863e` (test)
2. **Task 1 — test-bug fix: schedule_purge self-reference assertion** - `42b8d76` (test) — see Deviations
3. **Task 1 — GREEN: implement the purge and wire it in** - `80c88fa` (feat)
4. **Task 2: later explicit dependency + CI registration** - `a6eb9e3` (chore)

**Plan metadata:** committed alongside this SUMMARY.

## Files Created/Modified

- `backend/db/retention.R` — the purge mechanism (new)
- `tests/test_retention.R` — dependency-free test suite, 32 assertions (new)
- `backend/db/connection.R` — sources `db/retention.R`; calls `purge_expired_jobs()` and `schedule_purge()` inside the existing worker guard
- `backend/Dockerfile` — `'later'` added to the explicit `install.packages()` vector, with an explanatory comment mirroring the sodium lesson
- `tests/test_dockerfile_pinning.R` — new "later is an explicit dependency" section (explicit-install + manifest assertions)
- `.github/workflows/test.yml` — new named backend step running `tests/test_retention.R`

## Decisions Made

- SQL-side age comparison (not R-side) to keep both sides of the comparison on the DB server's own clock, avoiding pod-TZ drift.
- `remove_job_disk()`'s empty-id guard is a pre-check (`if (!nzchar(job_id)) return(invisible(FALSE))`), not a post-hoc existence check, because the destructive call (`unlink(recursive = TRUE)`) must never be reached with an id-less path.
- `purge_expired_jobs()` calls `remove_job_disk(id)` with its default `metadata_path` argument (lazily evaluated against `get_job_metadata_path()`), keeping `retention.R` itself free of any dependency on `connection.R`'s definitions at load time.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed an incorrect test assertion authored during RED, found during GREEN verification**
- **Found during:** Task 1, verifying GREEN after writing `backend/db/retention.R`
- **Issue:** The RED-phase test `"schedule_purge is referenced again at or after that point"` asserted `length(.schedule_ref_idxs) >= 2` (two literal `"schedule_purge("` matches in the comment-stripped source). The function's own definition line (`schedule_purge <- function(delay = ...)`) never matches that fixed substring — the ` <- function` text breaks it — so only the one recursive call inside `later::later()` can ever match. Correct, achievable production code produces exactly one match, positioned after the definition line; the `>= 2` threshold could never be satisfied by any correct implementation.
- **Fix:** Relaxed the assertion to `length(.schedule_ref_idxs) >= 1 && any(.schedule_ref_idxs > .schedule_def_idx[1])` — at least one reference to `schedule_purge(` positioned after its own definition line, which is exactly what D-05's "referenced again at or after that point" requires.
- **Files modified:** `tests/test_retention.R`
- **Verification:** Re-ran `Rscript tests/test_retention.R` after the fix and after the GREEN implementation — 32/32 passing.
- **Commit:** `42b8d76` (separate `test(03-01)` commit, landed before the `feat(03-01)` GREEN commit, so `test(03-01)` → `feat(03-01)` ordering is intact)

---

**Total deviations:** 1 auto-fixed (1 bug, in the test's own assertion logic — not in the implementation). **Impact on plan:** None on scope or behavior; the production code was correct on the first GREEN attempt. The fix corrected an unsatisfiable test threshold before it could falsely block GREEN.

## Issues Encountered

None beyond the self-authored test-assertion bug documented above.

## User Setup Required

None — no external service configuration required. `later` is already present in the image transitively; this plan only makes that explicit, with no manifest change.

## Next Phase Readiness

- ROADMAP criterion 2 (source half) is done: expired job data is removed automatically, in-process, with no manual trigger.
- D-01 through D-08 and D-11 are all satisfied and pinned by the test suite.
- Ready for Wave 2 (03-02 / 03-03): the user-facing notice (D-09), README documentation (D-10), and post-deploy verification on dev (D-12) are explicitly out of this plan's scope and depend on this plan's artifacts (`RETENTION_DAYS`, the purge behavior) being in place — which they now are.
- No blockers. `backend/plumber.R`, `backend/migrations/`, and `backend/package-manifest.csv` are all confirmed unchanged by this plan.

---
*Phase: 03-data-retention-policy*
*Completed: 2026-09-13*

## Self-Check: PASSED

All created/modified files confirmed present on disk (`backend/db/retention.R`, `tests/test_retention.R`,
`backend/db/connection.R`, `backend/Dockerfile`, `tests/test_dockerfile_pinning.R`,
`.github/workflows/test.yml`, this SUMMARY). All 4 commits (`142863e`, `42b8d76`, `80c88fa`, `a6eb9e3`)
confirmed present in `git log`. All task `<acceptance_criteria>` and the plan-level `<verification>`
re-run and passing (see commands and output above).
