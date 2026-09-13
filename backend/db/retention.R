# Data retention purge (issue #114)
#
# Deletes jobs past the retention window and the pod-local files that go with
# them. No library() call of its own -- dbGetQuery() and later::later()
# resolve at call time, which is what keeps this file dependency-free and
# testable in isolation (see tests/test_retention.R; backend/db/connection.R
# cannot be sourced the same way because it opens with library(RPostgres)).

# The single source of the retention window (D-01). Change this one constant
# to change the policy -- every caller interpolates from here, never repeats
# the number.
RETENTION_DAYS <- 90

# Re-arm interval for the in-process scheduler (D-05): 24 hours, in seconds.
.purge_interval_secs <- 24 * 60 * 60

# Returns the exact DELETE statement purge_expired_jobs() executes. Comparing
# against NOW() happens in SQL, not R, because the jobs.created_at/completed_at
# columns are naive TIMESTAMPs written by the same server's NOW() -- comparing
# them against NOW() in one server call keeps both sides of the comparison on
# one clock, whereas an R-side cutoff would depend on the pod's own TZ.
# Whole-row delete only: the existing ON DELETE CASCADE on job_logs, job_files
# and job_input_files does the rest (D-02) -- a per-table DELETE here would be
# both redundant and a second place to get the window wrong. No second
# condition: one window applies to every job, status and owner, demo runs
# included (D-01, D-03).
retention_purge_sql <- function(days = RETENTION_DAYS) {
  sprintf(
    "DELETE FROM jobs WHERE COALESCE(completed_at, created_at) < NOW() - INTERVAL '%d days' RETURNING id",
    as.integer(days)
  )
}

# The three pod-local paths for one job, in uploads / outputs / metadata
# order. Durable state lives only in Postgres; these are ephemeral pod disk
# paths that mirror a subset of it (uploads, outputs, job metadata JSON).
job_disk_paths <- function(job_id, metadata_path) {
  c(
    file.path("data", "uploads", job_id),
    file.path("data", "outputs", job_id),
    metadata_path
  )
}

# Remove a purged job's on-disk footprint. unlink() already treats a missing
# path as a no-op, which is exactly D-07's rule, so no existence checks are
# added here. The job_id guard is the one that matters: an empty job_id would
# otherwise make file.path("data", "uploads", "") address the shared parent
# directory "data/uploads" itself, and unlink(recursive = TRUE) on that would
# wipe every job's uploads in one call -- irreversible, so it is tested, not
# assumed (tests/test_retention.R).
#
# metadata_path's default is lazily evaluated: production gets
# connection.R's single definition of get_job_metadata_path(), and tests
# supply the path explicitly so the default is never forced (and never needs
# connection.R's DB-only dependencies to be loaded).
remove_job_disk <- function(job_id, metadata_path = get_job_metadata_path(job_id)) {
  if (!nzchar(job_id)) return(invisible(FALSE))
  unlink(job_disk_paths(job_id, metadata_path), recursive = TRUE)
  invisible(TRUE)
}

# Purge every job past the retention window. Mirrors cleanup_orphaned_jobs()'s
# exact posture (backend/db/connection.R): tryCatch-wrapped so a purge failure
# can never prevent the server from starting or serving (D-08); the next
# scheduled tick retries. One auditable log line reports both the count and
# the deleted ids (D-04), and stays silent when nothing expired.
purge_expired_jobs <- function() {
  tryCatch({
    conn <- .db_pool
    result <- dbGetQuery(conn, retention_purge_sql())
    if (nrow(result) > 0) {
      for (id in result$id) {
        remove_job_disk(id)
      }
      message(sprintf("Purged %d job(s) older than %d days: %s",
        nrow(result), RETENTION_DAYS, paste(result$id, collapse = ", ")))
    }
  }, error = function(e) {
    message("Warning: Failed to purge expired jobs: ", conditionMessage(e))
  })
}

# Re-arm the purge every 24 hours. httpuv's service loop (httpuv::service(),
# driven from within the plumber server's own run loop) drains later's global
# queue between requests, which is the only reason an in-process tick fires at
# all -- a per-job worker process has no such run loop, which is a second
# reason the COMSA_WORKER guard at the call site matters. The re-arm sits
# after purge_expired_jobs(), which swallows its own errors, so a failed purge
# still schedules the next tick (D-08).
schedule_purge <- function(delay = .purge_interval_secs) {
  tryCatch({
    later::later(function() {
      purge_expired_jobs()
      schedule_purge(delay)
    }, delay = delay)
  }, error = function(e) {
    message("Warning: Failed to schedule next purge: ", conditionMessage(e))
  })
}
