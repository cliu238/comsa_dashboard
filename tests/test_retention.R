#!/usr/bin/env Rscript
# Data retention purge tests (issue #114) -- backend/db/retention.R
#
# Deliberately dependency-free: base R only, no jsonlite, no DBI, no network.
# backend/db/connection.R cannot be sourced here (it opens with
# library(RPostgres) / library(pool), neither available on this machine or in
# CI) so this suite:
#   - sources backend/db/retention.R directly (it makes no library() call of
#     its own, so dbGetQuery()/later::later() resolve lazily at call time) and
#     exercises its pure functions (retention_purge_sql, job_disk_paths,
#     remove_job_disk) behaviourally;
#   - asserts the wiring into backend/db/connection.R, and retention.R's own
#     error/scheduling posture, from a comment-stripped SOURCE view rather
#     than by running it.
#
# The real DB-side DELETE is NOT exercised here -- it is verified post-deploy
# on dev (D-12), the same way Phases 1 and 02.1 verified their DB-touching
# changes, because that needs a live Postgres this suite deliberately does not
# require.

.test_count <- 0; .pass_count <- 0; .fail_count <- 0; .fail_msgs <- character()
test <- function(name, expr) {
  .test_count <<- .test_count + 1
  ok <- tryCatch(isTRUE(expr), error = function(e) {
    .fail_msgs <<- c(.fail_msgs, sprintf("  FAIL: %s -- error: %s", name, conditionMessage(e))); FALSE })
  if (ok) { .pass_count <<- .pass_count + 1; cat(sprintf("  PASS: %s\n", name)) }
  else { .fail_count <<- .fail_count + 1
    if (!any(grepl(name, .fail_msgs, fixed = TRUE)))
      .fail_msgs <<- c(.fail_msgs, sprintf("  FAIL: %s -- returned FALSE", name))
    cat(sprintf("  FAIL: %s\n", name)) }
}
section <- function(t) cat(sprintf("\n=== %s ===\n", t))

# --- Locate sources (dual entry point: project root or tests/) -------------
retention_path <- if (file.exists("backend/db/retention.R")) "backend/db/retention.R" else "../backend/db/retention.R"
connection_path <- if (file.exists("backend/db/connection.R")) "backend/db/connection.R" else "../backend/db/connection.R"

# Absolutize BEFORE any setwd() below, so Section 2's tempdir detour cannot
# break relative resolution. mustWork = FALSE lets this succeed even before
# retention.R exists (the RED case).
retention_abs  <- normalizePath(retention_path, mustWork = FALSE)
connection_abs <- normalizePath(connection_path, mustWork = FALSE)

# Load retention.R's functions into this env. Wrapped so a missing file (RED)
# or a load error is a named, caught failure -- never a script-ending crash --
# and every downstream test() call (which wraps its own expr in tryCatch) can
# still run and fail cleanly on "object not found" rather than aborting.
.retention_loaded <- tryCatch({ source(retention_abs); TRUE }, error = function(e) {
  message("NOTE: could not source backend/db/retention.R: ", conditionMessage(e)); FALSE })

# Comment-stripped source views, same idiom as tests/test_dockerfile_pinning.R
# (`code <- lines[!grepl("^\\s*#", lines)]`) -- header prose can never satisfy
# a source-level assertion built on this view.
connection_lines <- readLines(connection_abs)
connection_code <- connection_lines[!grepl("^\\s*#", connection_lines)]
retention_lines <- tryCatch(readLines(retention_abs), error = function(e) character(0))
retention_code <- retention_lines[!grepl("^\\s*#", retention_lines)]

sql  <- tryCatch(retention_purge_sql(), error = function(e) NA_character_)
sql7 <- tryCatch(retention_purge_sql(7), error = function(e) NA_character_)
count_delete <- function(s) if (is.na(s)) 0 else lengths(regmatches(s, gregexpr("DELETE", s, fixed = TRUE)))

# =============================================================================
section("1. The predicate that is actually executed (retention_purge_sql())")
# =============================================================================

test("backend/db/retention.R exists and loads without error", isTRUE(.retention_loaded))

test("RETENTION_DAYS is 90",
     exists("RETENTION_DAYS") && identical(RETENTION_DAYS, 90))

test("retention_purge_sql() is the default-argument entry point (RETENTION_DAYS reaches it with no args)",
     !is.na(sql) && grepl("INTERVAL '90 days'", sql, fixed = TRUE))

test("the statement contains exactly one DELETE, targeting the jobs table",
     !is.na(sql) && count_delete(sql) == 1 && grepl("DELETE FROM jobs", sql, fixed = TRUE))

test("age expression is COALESCE(completed_at, created_at) (D-01: a never-completed job ages from creation)",
     !is.na(sql) && grepl("COALESCE(completed_at, created_at)", sql, fixed = TRUE))

test("comparison is strict < (not <=) against NOW() -- a job exactly at the boundary is NOT purged (D-01)",
     !is.na(sql) && grepl("< NOW() - INTERVAL", sql, fixed = TRUE) && !grepl("<=", sql, fixed = TRUE))

test("retention_purge_sql(7) renders INTERVAL '7 days'",
     !is.na(sql7) && grepl("INTERVAL '7 days'", sql7, fixed = TRUE))

test("retention_purge_sql(7) contains no '90' anywhere -- the window is interpolated, never repeated",
     !is.na(sql7) && !grepl("90", sql7, fixed = TRUE))

test("the statement carries no second condition (no ' AND ')",
     !is.na(sql) && !grepl(" AND ", sql, fixed = TRUE))

test("the statement has no status/user_id/demo predicate -- one window for every job (D-01, D-03)",
     !is.na(sql) &&
       !grepl("status", sql, fixed = TRUE) &&
       !grepl("user_id", sql, fixed = TRUE) &&
       !grepl("demo_id", sql, fixed = TRUE) &&
       !grepl("use_sample_data", sql, fixed = TRUE))

test("the statement ends with RETURNING id (D-04, D-07: purged ids drive the log line and disk removal)",
     !is.na(sql) && grepl("RETURNING id", sql, fixed = TRUE) && grepl("RETURNING id$", trimws(sql)))

test("the comment-stripped retention source has no DELETE against the cascading child tables (D-02: the cascade is the mechanism)",
     !any(grepl("DELETE FROM job_logs", retention_code, fixed = TRUE)) &&
       !any(grepl("DELETE FROM job_files", retention_code, fixed = TRUE)) &&
       !any(grepl("DELETE FROM job_input_files", retention_code, fixed = TRUE)))

test("the comment-stripped retention source reads no environment variable (no dry-run/per-env override)",
     !any(grepl("Sys.getenv(", retention_code, fixed = TRUE)))

# =============================================================================
section("2. Per-job disk removal (remove_job_disk / job_disk_paths), run inside a tempdir")
# =============================================================================

test("job_disk_paths() returns exactly three paths, in uploads / outputs / metadata order",
     isTRUE(.retention_loaded) &&
       identical(job_disk_paths("abc", "data/jobs/abc.json"),
                 c(file.path("data", "uploads", "abc"),
                   file.path("data", "outputs", "abc"),
                   "data/jobs/abc.json")))

.old_wd <- getwd()
.disk_tmp <- tempfile("retention_test_")
dir.create(.disk_tmp)
setwd(.disk_tmp)
on.exit(setwd(.old_wd), add = TRUE)

make_job_files <- function(id) {
  dir.create(file.path("data", "uploads", id), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path("data", "outputs", id), recursive = TRUE, showWarnings = FALSE)
  dir.create("data/jobs", recursive = TRUE, showWarnings = FALSE)
  writeLines("upload", file.path("data", "uploads", id, "input.csv"))
  writeLines("output", file.path("data", "outputs", id, "result.csv"))
  writeLines("{}", file.path("data", "jobs", paste0(id, ".json")))
}
job_meta_path <- function(id) file.path("data", "jobs", paste0(id, ".json"))
job_present <- function(id) {
  file.exists(file.path("data", "uploads", id)) ||
    file.exists(file.path("data", "outputs", id)) ||
    file.exists(job_meta_path(id))
}

id_all <- "job-all-present"
id_sibling <- "job-sibling"
make_job_files(id_all)
make_job_files(id_sibling)

test("with all three paths present, remove_job_disk() removes all three",
     isTRUE(.retention_loaded) && {
       remove_job_disk(id_all, metadata_path = job_meta_path(id_all))
       !job_present(id_all)
     })

test("a second job's paths survive untouched",
     isTRUE(.retention_loaded) &&
       file.exists(file.path("data", "uploads", id_sibling)) &&
       file.exists(file.path("data", "outputs", id_sibling)) &&
       file.exists(job_meta_path(id_sibling)))

id_one <- "job-only-uploads"
dir.create(file.path("data", "uploads", id_one), recursive = TRUE, showWarnings = FALSE)
writeLines("upload", file.path("data", "uploads", id_one, "input.csv"))

test("with only one path present, remove_job_disk() removes that one and returns normally",
     isTRUE(.retention_loaded) && {
       remove_job_disk(id_one, metadata_path = job_meta_path(id_one))
       !file.exists(file.path("data", "uploads", id_one))
     })

id_none <- "job-none-present"
.before_none <- sort(list.files("data", recursive = TRUE))
test("with none present, remove_job_disk() returns normally and creates nothing",
     isTRUE(.retention_loaded) && {
       remove_job_disk(id_none, metadata_path = job_meta_path(id_none))
       identical(sort(list.files("data", recursive = TRUE)), .before_none)
     })

# The DoS-prevention case: a naive file.path() join would make an empty id
# address the shared parent directory (data/uploads, data/outputs, data/jobs)
# and wipe every job's uploads in one call. This is the one assertion that
# proves the guard, not just assumes it.
id_sentinel <- "job-empty-id-sentinel"
make_job_files(id_sentinel)
.before_empty <- sort(list.files("data", recursive = TRUE))
test("called with an empty job id, remove_job_disk() removes nothing at all -- data/uploads, data/outputs and data/jobs (and their contents) survive intact",
     isTRUE(.retention_loaded) && {
       remove_job_disk("", metadata_path = "data/jobs/ignored-should-not-be-touched.json")
       dir.exists("data/uploads") && dir.exists("data/outputs") && dir.exists("data/jobs") &&
         identical(sort(list.files("data", recursive = TRUE)), .before_empty)
     })

setwd(.old_wd)

# =============================================================================
section("3. Wiring: the worker guard and self-rescheduling (source-level)")
# =============================================================================

idx <- function(pattern, code) grep(pattern, code, fixed = TRUE)

worker_idxs   <- idx('Sys.getenv("COMSA_WORKER")', connection_code)
purge_idxs    <- idx('purge_expired_jobs()', connection_code)
schedule_idxs <- idx('schedule_purge()', connection_code)
return_idxs   <- idx('return(.db_pool)', connection_code)
cleanup_idxs  <- idx('cleanup_orphaned_jobs()', connection_code)

test("connection.R sources db/retention.R",
     length(idx('source("db/retention.R")', connection_code)) >= 1)

test("connection.R contains exactly one COMSA_WORKER test -- the purge shares cleanup_orphaned_jobs()'s guard",
     length(worker_idxs) == 1)

test("purge_expired_jobs() is called exactly once in connection.R",
     length(purge_idxs) == 1)

test("schedule_purge() is called exactly once in connection.R",
     length(schedule_idxs) == 1)

test("cleanup_orphaned_jobs() is still called inside the guard -- the purge is added beside it, not in place of it",
     length(cleanup_idxs) >= 1)

.guard_line  <- if (length(worker_idxs) == 1) worker_idxs[1] else NA_integer_
.return_line <- if (length(return_idxs) >= 1) min(return_idxs) else NA_integer_

test("purge_expired_jobs() sits after the COMSA_WORKER guard line and before return(.db_pool)",
     length(purge_idxs) == 1 && !is.na(.guard_line) && !is.na(.return_line) &&
       purge_idxs[1] > .guard_line && purge_idxs[1] < .return_line)

test("schedule_purge() sits after the COMSA_WORKER guard line and before return(.db_pool)",
     length(schedule_idxs) == 1 && !is.na(.guard_line) && !is.na(.return_line) &&
       schedule_idxs[1] > .guard_line && schedule_idxs[1] < .return_line)

test("cleanup_orphaned_jobs() sits after the guard line and before return(.db_pool) too",
     length(cleanup_idxs) >= 1 && !is.na(.guard_line) && !is.na(.return_line) &&
       min(cleanup_idxs) > .guard_line && min(cleanup_idxs) < .return_line)

test("in retention.R, purge_expired_jobs's body uses tryCatch with a message() error handler (D-08: a purge failure is logged, never raised)",
     any(grepl("tryCatch(", retention_code, fixed = TRUE)) &&
       any(grepl("error = function(e)", retention_code, fixed = TRUE)) &&
       any(grepl("message(", retention_code, fixed = TRUE)))

test("the purge's log line reports both the count and the ids (a count placeholder plus a collapse paste, D-04)",
     any(grepl("sprintf(", retention_code, fixed = TRUE)) &&
       any(grepl('collapse = ", "', retention_code, fixed = TRUE)))

.schedule_def_idx <- grep("schedule_purge <- function", retention_code, fixed = TRUE)
.later_idxs       <- grep("later::later(", retention_code, fixed = TRUE)
.schedule_ref_idxs <- grep("schedule_purge(", retention_code, fixed = TRUE)

test("schedule_purge re-arms itself: later::later( appears after schedule_purge's own definition line",
     length(.schedule_def_idx) == 1 && length(.later_idxs) >= 1 &&
       any(.later_idxs > .schedule_def_idx[1]))

test("schedule_purge is referenced again at or after that point (the re-arm calls itself, not a one-shot)",
     length(.schedule_def_idx) == 1 && length(.schedule_ref_idxs) >= 2)

test("the comment-stripped retention source names no external scheduler (no Sys.sleep, system(, cron, CronJob)",
     !any(grepl("Sys.sleep(", retention_code, fixed = TRUE)) &&
       !any(grepl("system(", retention_code, fixed = TRUE)) &&
       !any(grepl("cron", retention_code, ignore.case = TRUE)) &&
       !any(grepl("CronJob", retention_code, fixed = TRUE)))

# =============================================================================
# Summary
# =============================================================================
cat(sprintf("\n%s\n", strrep("=", 70)))
cat(sprintf("Total: %d  Passed: %d  Failed: %d\n", .test_count, .pass_count, .fail_count))
if (.fail_count > 0) { cat("\nFailures:\n"); for (m in .fail_msgs) cat(m, "\n"); quit(status = 1) }
cat("All retention purge tests passed.\n")
quit(status = 0)
