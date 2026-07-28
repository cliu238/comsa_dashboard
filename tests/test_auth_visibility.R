#!/usr/bin/env Rscript
# Job enumeration scope (job_visibility) — backend/auth/middleware.R
#
# GET /jobs branched on `!is.null(req$user) && req$user$role != "admin"`, so a
# request with no Authorization header skipped the filter and took the ADMIN
# branch, returning every user's job list to any anonymous caller. Verified
# against the deployment before the fix: `curl` with no auth returned 224 jobs.
#
# Deliberately dependency-free — no DB, no vacalibration, no jose, no plumber — so this
# suite can run in CI (see .github/workflows/test.yml).

.test_count <- 0; .pass_count <- 0; .fail_count <- 0; .fail_msgs <- character()

test <- function(name, expr) {
  .test_count <<- .test_count + 1
  ok <- tryCatch(isTRUE(expr), error = function(e) {
    .fail_msgs <<- c(.fail_msgs, sprintf("  FAIL: %s -- error: %s", name, conditionMessage(e)))
    FALSE
  })
  if (ok) {
    .pass_count <<- .pass_count + 1
    cat(sprintf("  PASS: %s\n", name))
  } else {
    .fail_count <<- .fail_count + 1
    if (!any(grepl(name, .fail_msgs, fixed = TRUE))) {
      .fail_msgs <<- c(.fail_msgs, sprintf("  FAIL: %s -- returned FALSE", name))
    }
    cat(sprintf("  FAIL: %s\n", name))
  }
}

section <- function(title) cat(sprintf("\n=== %s ===\n", title))

# job_visibility() lives in jobs/utils.R precisely so this can be sourced with no
# JWT library, no DB driver and no vacalibration.
utils_path <- if (file.exists("backend/jobs/utils.R")) "backend/jobs/utils.R" else "../backend/jobs/utils.R"
source(utils_path)

section("1. Anonymous callers enumerate nothing")

test("NULL user -> none", identical(job_visibility(NULL), "none"))

section("2. Admin sees everything")

test("role=admin -> all", identical(job_visibility(list(id = "u1", role = "admin")), "all"))
test("admin as a length-1 list (R/JSON shape) -> all",
     identical(job_visibility(list(id = "u1", role = list("admin"))), "all"))

section("3. Authenticated non-admin sees only their own")

test("role=user -> own", identical(job_visibility(list(id = "u1", role = "user")), "own"))
test("role=researcher -> own", identical(job_visibility(list(id = "u1", role = "researcher")), "own"))
test("role=Admin (wrong case) is NOT admin",
     identical(job_visibility(list(id = "u1", role = "Admin")), "own"))
test("role=admin with trailing space is NOT admin",
     identical(job_visibility(list(id = "u1", role = "admin ")), "own"))

section("4. Malformed role degrades to the LEAST privilege, never to admin")

for (bad in list(NULL, NA, NA_character_, character(0), c("admin", "user"), list(), 0L, TRUE)) {
  label <- paste0("role=", paste(utils::capture.output(str(bad)), collapse = " "))
  got <- tryCatch(job_visibility(list(id = "u1", role = bad)), error = function(e) "ERROR")
  test(sprintf("%s -> own (not all)", label), identical(got, "own"))
}

section("5. The exact regression: an unauthenticated request must not read as admin")

# req$user is NULL under AUTH_GRACE_PERIOD; the old expression
# `!is.null(req$user) && req$user$role != "admin"` was FALSE for it, selecting
# the admin branch. job_visibility must never return "all" for that input.
test("anonymous never yields the admin scope", !identical(job_visibility(NULL), "all"))
test("only an explicit admin role yields the admin scope",
     sum(sapply(list(NULL, list(role = "user"), list(role = NA), list(role = character(0))),
                function(u) identical(job_visibility(u), "all"))) == 0)

cat(sprintf("\n%s\n", strrep("=", 70)))
cat(sprintf("Total: %d  Passed: %d  Failed: %d\n", .test_count, .pass_count, .fail_count))
if (.fail_count > 0) {
  cat("\nFailures:\n"); for (m in .fail_msgs) cat(m, "\n")
  quit(status = 1)
}
cat("All job visibility tests passed.\n")
quit(status = 0)
