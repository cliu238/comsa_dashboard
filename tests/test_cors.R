#!/usr/bin/env Rscript
# CORS origin policy — backend/cors.R (issue #4)
#
# backend/plumber.R's `cors` filter set `Access-Control-Allow-Origin: *` on every
# route, unconditionally. Issue #4 ("Restrict CORS in production") was closed with
# no corresponding change to the filter.
#
# The wildcard was never needed in production: k8s/ingress.yaml routes
# /comsa-dashboard/api(/|$)(.*) to the backend and /comsa-dashboard(/|$)(.*) to the
# frontend under the SAME host, and frontend/.env.production sets
# VITE_API_BASE_URL=/comsa-dashboard/api — a relative path. Production is same-origin,
# so it needs no CORS header at all. Only local development is cross-origin
# (frontend :5173, backend :8000).
#
# Deliberately dependency-free — no DB, no plumber, no jose — so this runs in CI.

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
      .fail_msgs <<- c(.fail_msgs, sprintf("  FAIL: %s -- assertion returned FALSE", name))
    }
    cat(sprintf("  FAIL: %s\n", name))
  }
}

# Same convention as tests/test_auth_visibility.R: runnable from the repo root or
# from tests/. cors.R is deliberately free of plumber/DB/JWT so this can source it.
backend_dir <- if (dir.exists("backend")) "backend" else "../backend"
source(file.path(backend_dir, "cors.R"))

cat("\n=== 1. Default policy (no CORS_ALLOWED_ORIGINS set) ===\n")

defaults <- cors_allowed_origins("")
test("defaults to the local dev origins only",
     setequal(defaults, c("http://localhost:5173", "http://localhost:3000")))
test("the default policy contains no wildcard",
     !("*" %in% defaults))

cat("\n=== 2. The wildcard is gone (issue #4) ===\n")

test("an unknown origin gets NO Access-Control-Allow-Origin value",
     is.null(cors_allow_origin("https://evil.example.com", defaults)))
test("a browser origin is never answered with '*'",
     !identical(cors_allow_origin("http://localhost:5173", defaults), "*"))
test("an allowed origin is echoed back exactly",
     identical(cors_allow_origin("http://localhost:5173", defaults), "http://localhost:5173"))

cat("\n=== 3. Matching is exact, not prefix/substring ===\n")

test("a suffix-extended lookalike is rejected",
     is.null(cors_allow_origin("http://localhost:5173.evil.example.com", defaults)))
test("a prefix-extended lookalike is rejected",
     is.null(cors_allow_origin("https://evil.example.com/http://localhost:5173", defaults)))
test("scheme is part of the match (http vs https)",
     is.null(cors_allow_origin("https://localhost:5173", defaults)))
test("port is part of the match",
     is.null(cors_allow_origin("http://localhost:9999", defaults)))

cat("\n=== 4. Missing / malformed Origin ===\n")

test("NULL origin (same-origin request, no header) yields no value",
     is.null(cors_allow_origin(NULL, defaults)))
test("empty-string origin yields no value",
     is.null(cors_allow_origin("", defaults)))
test("NA origin yields no value",
     is.null(cors_allow_origin(NA_character_, defaults)))
test("the literal string 'null' (sandboxed iframe / file://) is rejected",
     is.null(cors_allow_origin("null", defaults)))

cat("\n=== 5. Operator override via CORS_ALLOWED_ORIGINS ===\n")

custom <- cors_allowed_origins("https://dev.sites.idies.jhu.edu, https://example.org")
test("comma-separated origins are parsed and trimmed",
     setequal(custom, c("https://dev.sites.idies.jhu.edu", "https://example.org")))
test("an origin from the override is allowed",
     identical(cors_allow_origin("https://example.org", custom), "https://example.org"))
test("an origin outside the override is still refused",
     is.null(cors_allow_origin("https://evil.example.com", custom)))
test("blank entries are dropped rather than becoming a match-anything hole",
     setequal(cors_allowed_origins("https://a.example, , https://b.example"),
              c("https://a.example", "https://b.example")))

cat("\n=== 6. A wildcard cannot be reintroduced through config ===\n")

wildcard_err <- tryCatch({ cors_allowed_origins("*"); "no error" },
                          error = function(e) conditionMessage(e))
test("CORS_ALLOWED_ORIGINS='*' fails loudly instead of silently re-opening the hole",
     !identical(wildcard_err, "no error"))
test("the wildcard rejection explains itself",
     grepl("wildcard|\\*", wildcard_err))

mixed_err <- tryCatch({ cors_allowed_origins("https://a.example,*"); "no error" },
                       error = function(e) conditionMessage(e))
test("a wildcard hidden among real origins is rejected too",
     !identical(mixed_err, "no error"))

cat("\n=== 7. The filter in plumber.R uses this policy ===\n")

plumber_src <- readLines(file.path(backend_dir, "plumber.R"), warn = FALSE)
plumber_txt <- paste(plumber_src, collapse = "\n")

test("plumber.R no longer hardcodes the wildcard",
     !grepl('Access-Control-Allow-Origin"?,\\s*"\\*"', plumber_txt))
test("plumber.R routes the decision through cors_allow_origin()",
     grepl("cors_allow_origin(", plumber_txt, fixed = TRUE))
test("plumber.R sets Vary: Origin so a cached response cannot leak across origins",
     grepl("Vary", plumber_txt, fixed = TRUE))

cat("\n========================================\n")
cat(sprintf("Tests: %d | Passed: %d | Failed: %d\n", .test_count, .pass_count, .fail_count))
cat("========================================\n")
if (.fail_count > 0) {
  cat("\nFailed tests:\n"); for (m in .fail_msgs) cat(m, "\n")
  quit(status = 1)
} else {
  cat("\nAll CORS policy tests passed.\n")
  quit(status = 0)
}
