---
phase: 03-data-retention-policy
reviewed: 2026-09-13T18:17:16Z
depth: standard
files_reviewed: 10
files_reviewed_list:
  - .github/workflows/test.yml
  - README.md
  - backend/Dockerfile
  - backend/README.md
  - backend/db/connection.R
  - backend/db/retention.R
  - backend/migrations/003_input_file_storage.sql
  - frontend/src/components/JobList.jsx
  - tests/test_dockerfile_pinning.R
  - tests/test_retention.R
findings:
  critical: 0
  warning: 3
  info: 2
  total: 5
status: issues_found
---

# Phase 03: Code Review Report

**Reviewed:** 2026-09-13T18:17:16Z
**Depth:** standard
**Files Reviewed:** 10
**Status:** issues_found

## Summary

Reviewed the 90-day data retention purge (`backend/db/retention.R`), its wiring into
`get_db_pool()` (`backend/db/connection.R`), the accompanying dependency-free test
suite, the Dockerfile change that makes `later` an explicit dependency, and the
user-facing/documentation updates (JobList.jsx notice, README.md, backend/README.md).

Both test suites (`tests/test_retention.R`, `tests/test_dockerfile_pinning.R`) were
executed locally and pass in full (40/40 and 42/42). SQL construction in
`retention_purge_sql()` was probed directly with non-numeric input (`NA`, and a
`"7; DROP TABLE jobs"` injection attempt) — `as.integer()` coerces any non-numeric
value to `NA` before it ever reaches `sprintf()`, so no SQL injection is possible
through this path, and the worst case is a syntactically invalid statement that the
existing `tryCatch` in `purge_expired_jobs()` already absorbs. The `COMSA_WORKER`
guard was traced end-to-end: `backend/jobs/run_job.R` sets `COMSA_WORKER=1` in a
genuinely separate `Rscript` process before sourcing `processor.R`, so the purge
schedule cannot double-register inside a job worker. The empty-`job_id` guard in
`remove_job_disk()` was verified behaviorally by running the test suite's own
tempdir cases, and lazy default-argument evaluation (`metadata_path =
get_job_metadata_path(job_id)`) was confirmed to never force when `job_id` is
empty, matching the code comment's claim.

No critical/blocker issues were found — no injection vector, no credential
exposure, no path escape reachable from any DB-sourced (UUID-typed) `job_id`. Three
warnings and two info items were found, centered on: (1) `remove_job_disk()`
silently discarding `unlink()`'s failure status, verified by reproduction; (2) a
permanent, silent halt of the purge schedule if the re-arm call to `later::later()`
itself throws; and (3) the 90-day window being restated as independent hardcoded
text in three additional places rather than derived from the single `RETENTION_DAYS`
constant, with drift caught only by test-suite text-scraping rather than any
structural guarantee.

## Warnings

### WR-01: `remove_job_disk()` silently ignores `unlink()` failures — orphaned files can persist forever, undetected

**File:** `backend/db/retention.R:57-61`
**Issue:** `unlink(job_disk_paths(...), recursive = TRUE)`'s return value (0 = success,
1 = failure, per R docs) is discarded. Reproduced directly:

```
$ chmod 000 data/uploads/jobX   # dir contains a file
$ Rscript -e 'remove_job_disk("jobX", metadata_path = "data/jobs/jobX.json")'
remove_job_disk returned: TRUE
dir still exists: TRUE
raw unlink() status code: 1
```

Because `purge_expired_jobs()` has already committed the `DELETE FROM jobs ...
RETURNING id` before calling `remove_job_disk()` for each id, the database row —
the only thing that would let a future purge cycle retry this job's disk cleanup —
is gone by the time disk removal is attempted. If `unlink()` fails for any reason
(permission drift, a file still open/locked by a concurrent download stream, a
read-only mount), the pod-local files are never reclaimed and there is no log line,
metric, or retry path to surface it. This directly undermines the stated purpose of
the feature (disk space reclamation) with no way to detect the failure in
production.
**Fix:** Check and log the result, e.g.:
```r
remove_job_disk <- function(job_id, metadata_path = get_job_metadata_path(job_id)) {
  if (!nzchar(job_id)) return(invisible(FALSE))
  status <- unlink(job_disk_paths(job_id, metadata_path), recursive = TRUE)
  if (any(status != 0)) {
    message("Warning: failed to fully remove disk files for purged job ", job_id)
  }
  invisible(TRUE)
}
```

### WR-02: A failed re-arm in `schedule_purge()` silently and permanently stops the purge until the pod restarts

**File:** `backend/db/retention.R:91-100`
**Issue:** `schedule_purge()`'s own `later::later()` call is wrapped in a `tryCatch`
whose `error` handler only logs a `message()`. If this call throws (e.g., the
`later` package's internal queue is in a bad state), `schedule_purge()` is never
invoked again — the entire recurring purge silently stops firing for the remaining
lifetime of the process, with no distinguishable signal in the logs between "ran and
found 0 expired jobs" and "purge has been permanently disabled." Given this runs
once at startup and then only every 24 hours, such a failure could go unnoticed for
a long time (pods here appear to run for extended periods rather than restarting
frequently).
**Fix:** At minimum, make the failure louder/distinct from the steady-state
no-op case, e.g. `message("CRITICAL: retention purge scheduling failed and will NOT
retry until the next pod restart: ", conditionMessage(e))`, or track a
"next scheduled purge" timestamp status that can be exposed on `/health` so an
operator can notice the schedule has stalled.

### WR-03: The 90-day retention window is restated as independent literal text in three more places, with sync enforced only by test-suite text-scraping

**File:** `frontend/src/components/JobList.jsx:8`, `README.md` (`## Data retention`), `backend/README.md` (`## Data retention`)
**Issue:** `backend/db/retention.R`'s own header comment states "every caller
interpolates from here, never repeats the number" — true for the two R call sites,
but the frontend notice and both README files each hardcode the literal `90`/"90
days" independently. The only thing preventing these four numbers from silently
drifting apart is `tests/test_retention.R` section 4, which regex-extracts integers
out of `JobList.jsx` and `README.md` (not `backend/README.md`, which has no
corresponding assertion) and compares them to `RETENTION_DAYS`. This is a real,
working safety net today, but it is a test-time text-scrape over prose, not a
structural single source of truth — a future refactor of `README.md`'s heading
text, or any change to `backend/README.md`'s number, would not be caught by any
existing assertion.
**Fix:** Either (a) add the missing assertion for `backend/README.md` to
`tests/test_retention.R` for parity with `README.md`, or (b) have the frontend read
the window from an API field (e.g., extend `/health` or `/jobs` response) instead of
hardcoding it, removing the drift risk structurally rather than only detecting it.

## Info

### IN-01: `retention_purge_sql(days)` has no validation on its argument

**File:** `backend/db/retention.R:27-32`
**Issue:** `as.integer(days)` silently coerces any non-coercible value to `NA`
(confirmed: `retention_purge_sql("7; DROP TABLE jobs")` produces
`INTERVAL 'NA days'`, not an injected clause — so this is not exploitable today).
The failure mode is a SQL syntax error surfaced only once the query reaches
Postgres, caught generically by `purge_expired_jobs()`'s `tryCatch` as "Failed to
purge expired jobs: ...". Harmless while the only callers are the `RETENTION_DAYS`
constant and the test suite's literal `7`, but there is no defense at the R layer
if `days` is ever sourced from something less fixed.
**Fix:** Optional: `stopifnot(is.numeric(days), days > 0)` at the top of
`retention_purge_sql()` for a clearer failure mode, though not required given the
current call sites.

### IN-02: No exclusion for a job still `running` when it crosses the retention window

**File:** `backend/db/retention.R:22-26` (design decision, also asserted by `tests/test_retention.R:93-98`)
**Issue:** The purge predicate deliberately has no status condition (D-01/D-03,
confirmed intentional by both the code comment and a dedicated test). This means a
job that somehow stays in `running` status for more than `RETENTION_DAYS` (90) days
without the pod restarting — `cleanup_orphaned_jobs()` only reaps stuck `running`
jobs on startup, not while the pod stays up — would have its `jobs` row deleted
mid-flight. Any subsequent `add_log()` or `update_job_status()` call for that job id
would then fail on the `job_logs`/`jobs` foreign key, since the parent row is gone.
Given VA jobs complete in seconds-to-minutes in practice, this is very unlikely to
be hit, and the one-window-for-everyone design is clearly an intentional,
tested choice — flagging for awareness rather than as a required fix.
**Fix:** No action required unless a genuinely long-running job type is added later;
if so, consider excluding `status = 'running'` from the purge predicate at that
point.

---

_Reviewed: 2026-09-13T18:17:16Z_
_Reviewer: Claude (gsd-code-reviewer)_
_Depth: standard_
