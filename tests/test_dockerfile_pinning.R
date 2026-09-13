# =============================================================================
# Dockerfile Pinning Guard -- GitHub issue #123
# =============================================================================
# A build from an unchanged commit must resolve the same base image and the
# same R package versions no matter when it is built. The 2-day outage in
# #122 happened because RcppParallel shipped a CRAN release requiring cmake
# and the Dockerfile installed everything unpinned from cloud.r-project.org.
# The breakage surfaced on a PR that had only touched .R files, so it was
# misattributed to that PR. This guard asserts the pinning properties from
# source so that class of failure cannot recur silently.
#
# Pure source-assertion test: no network, no Docker, no packages beyond base
# R. Must run in the CI `backend` job before the "Install jsonlite" step.
#
# Usage:
#   Rscript tests/test_dockerfile_pinning.R
#
# Run from the project root or backend/. Exit code: 0 = all pass, 1 = failures.

# --- Test helpers (same style as test_misclass_matrix.R) ---
.test_count <- 0L
.pass_count <- 0L
.fail_count <- 0L
.fail_msgs  <- character()

test <- function(desc, expr) {
  .test_count <<- .test_count + 1L
  tryCatch({
    ok <- eval(expr, envir = parent.frame())
    if (!isTRUE(ok)) stop("assertion returned FALSE")
    .pass_count <<- .pass_count + 1L
    cat(sprintf("  PASS: %s\n", desc))
  }, error = function(e) {
    .fail_count <<- .fail_count + 1L
    msg <- sprintf("  FAIL: %s -- %s", desc, conditionMessage(e))
    .fail_msgs <<- c(.fail_msgs, msg)
    cat(msg, "\n")
  })
}

section <- function(title) cat(sprintf("\n=== %s ===\n", title))

# --- Locate the Dockerfile under test ---
if (file.exists("backend/Dockerfile")) {
  dockerfile_path <- "backend/Dockerfile"
} else if (file.exists("Dockerfile")) {
  dockerfile_path <- "Dockerfile"
} else {
  stop("Run this test from the project root or backend/ directory")
}

lines <- readLines(dockerfile_path)
# Comment-stripped view. The Dockerfile's header prose mentions cmake,
# cloud.r-project.org, and the snapshot rationale -- counting unfiltered
# lines would make the file self-invalidating.
code <- lines[!grepl("^\\s*#", lines)]

BASE_DIGEST <- "sha256:3dae5d2eeddf74f10e0a81fb6b7ae350295e288000304f438b844b2c1e00fe2c"
SNAPSHOT_URL <- "https://p3m.dev/cran/__linux__/noble/2026-08-01"
VACAL_SHA <- "498df45b6e14e02a3152b843c605b4a33240f12e"

# =============================================================================
section("base image is pinned")
# =============================================================================

from_idx <- grep("^FROM ", code)

test("exactly one FROM line",
     length(from_idx) == 1)

test("FROM line is exactly the digest-pinned rocker/r-ver:4.4 form",
     length(from_idx) == 1 &&
       identical(trimws(code[from_idx]),
                 sprintf("FROM rocker/r-ver:4.4@%s", BASE_DIGEST)))

test("a comment records the tag/R-version (4.4.3), deliberately checked against raw lines",
     any(grepl("4.4.3", lines, fixed = TRUE)))

test("a comment records the multi-arch scope of the digest, deliberately checked against raw lines",
     any(grepl("multi-arch", lines, fixed = TRUE)))

# =============================================================================
section("CRAN snapshot is pinned in exactly one place")
# =============================================================================

env_idx <- grep("^ENV CRAN_SNAPSHOT=", code)

test("exactly one ENV CRAN_SNAPSHOT= line",
     length(env_idx) == 1)

test("the snapshot URL occurs exactly once across all of code (single source of truth)",
     sum(grepl(SNAPSHOT_URL, code, fixed = TRUE)) == 1)

test("cloud.r-project.org does not appear anywhere in code",
     sum(grepl("cloud.r-project.org", code, fixed = TRUE)) == 0)

test("no install.packages( call carries its own repos= argument (repos = NULL, a local tarball, is the one allowed form)",
     sum(grepl("install.packages(", code, fixed = TRUE) &
         grepl("repos", code, fixed = TRUE) &
         !grepl("repos = NULL", code, fixed = TRUE)) == 0)

test("at least one line appends to Rprofile.site with >>",
     any(grepl("Rprofile.site", code, fixed = TRUE) & grepl(">>", code, fixed = TRUE)))

test("every Rprofile.site line that redirects uses >> (append), never a bare >",
     {
       rp_lines <- code[grepl("Rprofile.site", code, fixed = TRUE)]
       redirecting <- rp_lines[grepl(">", rp_lines, fixed = TRUE)]
       length(redirecting) == 0 || all(grepl(">>", redirecting, fixed = TRUE))
     })

# =============================================================================
section("vacalibration is pinned to a commit SHA, not a branch or tag")
# =============================================================================
# CRAN still carries 2.2, whose Stan models do not compile against
# StanHeaders 2.39.1 -- vacalibration is pinned from GitHub at a commit SHA
# until CRAN carries 2.3.1 (reversal path:
# .planning/seeds/switch-vacalibration-pin-to-cran.md). A content-addressed
# SHA cannot be silently moved the way a branch or tag can.

env_idx <- grep("^ENV VACALIBRATION_SHA=", code)

test("exactly one ENV VACALIBRATION_SHA line",
     length(env_idx) == 1)

env_sha <- if (length(env_idx) == 1) sub("^ENV VACALIBRATION_SHA=", "", code[env_idx]) else NA_character_

test("VACALIBRATION_SHA is a 40-hex commit SHA (a branch name or version tag cannot match this)",
     !is.na(env_sha) && grepl("^[0-9a-f]{40}$", env_sha))

test("VACALIBRATION_SHA equals the recorded VACAL_SHA constant",
     !is.na(env_sha) && identical(env_sha, VACAL_SHA))

# Count OCCURRENCES, not lines: two installs chained on one physical line
# would otherwise be invisible to every assertion below.
archive_hits <- regmatches(code, gregexpr("sandy-pramanik/vacalibration/archive/[^'\"]+", code))
archive_refs <- unlist(archive_hits)

test("exactly one GitHub archive URL for sandy-pramanik/vacalibration in the whole Dockerfile",
     length(archive_refs) == 1)

test("the archive URL is built from ${VACALIBRATION_SHA}, not a second literal ref",
     length(archive_refs) == 1 &&
       identical(archive_refs, "sandy-pramanik/vacalibration/archive/${VACALIBRATION_SHA}.tar.gz"))

test("the archive install uses repos = NULL (nothing resolves against a live index)",
     any(grepl("sandy-pramanik/vacalibration/archive/", code, fixed = TRUE) &
         grepl("repos = NULL", code, fixed = TRUE)))

test("no other line references sandy-pramanik/vacalibration (no remotes::install_github, no @branch)",
     sum(lengths(regmatches(code, gregexpr("sandy-pramanik/vacalibration", code, fixed = TRUE)))) == 1)

test("no install.packages( line still names 'vacalibration' in quotes",
     sum(grepl("install.packages(", code, fixed = TRUE) &
         grepl("'vacalibration'", code, fixed = TRUE)) == 0)

test("remotes is not installed (the tarball install needs no helper package)",
     !any(grepl("remotes", code, fixed = TRUE)))

# repos = NULL resolves no dependencies, so vacalibration's Imports must already
# be on the image from the snapshot. The first deploy of the tarball install
# failed exactly here ("dependencies 'rstan', 'patchwork', 'reshape2',
# 'LaplacesDemon' are not available"): locally they were pre-installed, in the
# image nothing had pulled them once vacalibration left the CRAN install line.
archive_idx <- grep("sandy-pramanik/vacalibration/archive/", code, fixed = TRUE)
imports_idx <- grep("install.packages(", code, fixed = TRUE)
imports_idx <- imports_idx[vapply(imports_idx, function(i)
  all(vapply(c("'rstan'", "'patchwork'", "'reshape2'", "'LaplacesDemon'"),
             function(pkg) grepl(pkg, code[i], fixed = TRUE), logical(1))), logical(1))]

test("vacalibration's Imports (rstan, patchwork, reshape2, LaplacesDemon) are installed from the snapshot in one install.packages( call",
     length(imports_idx) >= 1)

test("that Imports install precedes the tarball install (repos = NULL resolves nothing)",
     length(archive_idx) == 1 && length(imports_idx) >= 1 && min(imports_idx) < archive_idx)

# Manifest path mirrors the same "run from project root or backend/" support
# as dockerfile_path above -- cheap local half of the deploy-time manifest
# diff, catching a Dockerfile/manifest disagreement before the push.
manifest_path <- if (dockerfile_path == "backend/Dockerfile") {
  "backend/package-manifest.csv"
} else {
  "package-manifest.csv"
}

test("backend/package-manifest.csv records vacalibration,2.3.1",
     file.exists(manifest_path) &&
       "vacalibration,2.3.1" %in% trimws(readLines(manifest_path)))

# =============================================================================
section("sodium is an explicit dependency")
# =============================================================================

test("an install.packages( call includes 'sodium' explicitly",
     any(grepl("install.packages(", code, fixed = TRUE) & grepl("'sodium'", code, fixed = TRUE)))

test("libsodium-dev is still present (system library, distinct from the R package)",
     any(grepl("libsodium-dev", code, fixed = TRUE)))

# =============================================================================
section("later is an explicit dependency")
# =============================================================================
# backend/db/retention.R calls later::later() directly (issue #114). later
# arrived transitively via plumber; naming it explicitly is the same "sodium
# lesson" as above. It must resolve from the already-pinned snapshot, so the
# committed manifest must not change (D-06) -- caught here locally instead of
# only at deploy time.

test("an install.packages( call includes 'later' explicitly",
     any(grepl("install.packages(", code, fixed = TRUE) & grepl("'later'", code, fixed = TRUE)))

test("backend/package-manifest.csv records later,1.4.8",
     file.exists(manifest_path) &&
       "later,1.4.8" %in% trimws(readLines(manifest_path)))

# =============================================================================
section("nothing load-bearing was disturbed")
# =============================================================================

test("cmake is still installed (PR #122, required by RcppParallel 6.2.0)",
     any(grepl("cmake", code, fixed = TRUE)))

test("default-jdk is still installed",
     any(grepl("default-jdk", code, fixed = TRUE)))

test("R CMD javareconf is still run",
     any(grepl("R CMD javareconf", code, fixed = TRUE)))

test("seqcalib.stan is still referenced (Stan recompilation step intact)",
     any(grepl("seqcalib.stan", code, fixed = TRUE)))

test("seqcalib_mmat.stan is still referenced (Stan recompilation step intact)",
     any(grepl("seqcalib_mmat.stan", code, fixed = TRUE)))

test("options(warn=2) still guards at least one install",
     any(grepl("options(warn=2)", code, fixed = TRUE)))

# =============================================================================
section("layer ordering preserves failure attribution")
# =============================================================================

copy_idx_all <- grep("^COPY backend/", code)

test("exactly one COPY backend/ line",
     length(copy_idx_all) == 1)

copy_idx <- if (length(copy_idx_all) == 1) copy_idx_all else Inf

install_idxs <- grep("install.packages(", code, fixed = TRUE)

test("every install.packages( line precedes the COPY",
     length(install_idxs) > 0 && all(install_idxs < copy_idx))

manifest_idx <- grep("/opt/package-manifest.csv", code, fixed = TRUE)

test("the /opt/package-manifest.csv line precedes the COPY (a failure before COPY cannot be an application-source change)",
     length(manifest_idx) > 0 && all(manifest_idx < copy_idx))

# =============================================================================
section("the image emits a package manifest")
# =============================================================================

test("/opt/package-manifest.csv occurs exactly once in code",
     sum(grepl("/opt/package-manifest.csv", code, fixed = TRUE)) == 1)

test("installed.packages() is called to build the manifest",
     any(grepl("installed.packages()", code, fixed = TRUE)))

test("LC_COLLATE is set for deterministic, diffable sort order",
     any(grepl("LC_COLLATE", code, fixed = TRUE)))

test("a stopifnot() asserts sodium's presence at build time",
     any(grepl("stopifnot", code, fixed = TRUE) & grepl("sodium", code, fixed = TRUE)))

# =============================================================================
section("exactly one Dockerfile per service")
# =============================================================================
# Issue #123 also removed a drifted, unpinned copy of backend/Dockerfile that
# lived inside the comsa-k8s-deploy skill's assets and that the skill's own
# Quick Setup instructions told the reader to `cp` over the real file. This
# section asserts a second copy cannot come back silently.

# Resolve the repo root via git, not relative-path guessing, so this section
# works whether the test is invoked from the project root or from backend/
# (same two entry points test/dockerfile_path probing above supports).
repo_root <- tryCatch(
  trimws(system2("git", c("rev-parse", "--show-toplevel"), stdout = TRUE)),
  error = function(e) NA_character_
)

test("the deleted assets/dockerfiles template directory does not exist",
     !is.na(repo_root) &&
       !file.exists(file.path(repo_root, ".claude/skills/comsa-k8s-deploy/assets/dockerfiles")))

# git ls-files (not list.files()) so this ignores untracked files and
# anything under node_modules. If git is unavailable, system2() returns
# character(0); identical() against the 2-element expected vector then
# fails the assertion rather than vacuously passing.
tracked_all <- system2("git", c("-C", repo_root, "ls-files"), stdout = TRUE)
tracked_dockerfiles <- tracked_all[grepl("^Dockerfile", basename(tracked_all))]

test("the only tracked Dockerfiles are backend/Dockerfile and frontend/Dockerfile",
     identical(sort(tracked_dockerfiles), c("backend/Dockerfile", "frontend/Dockerfile")))

# git grep -l exits 1 (no stdout) when there are no matches -- that is the
# passing case here, not a tool failure, so stderr is suppressed rather than
# treated as an error. .planning/ is excluded (dated planning documents
# legitimately discuss the deleted path) and so is this test file itself
# (it necessarily contains the literal string above). The exclusion is done
# in R, not via git pathspecs, so the intent stays readable.
grep_hits <- system2("git", c("-C", repo_root, "grep", "-l", "--", "assets/dockerfiles"),
                      stdout = TRUE, stderr = FALSE)
grep_hits <- grep_hits[!grepl("^\\.planning/", grep_hits)]
grep_hits <- grep_hits[grep_hits != "tests/test_dockerfile_pinning.R"]

test("no tracked file outside .planning/ (and this test file) still references the deleted template path",
     length(grep_hits) == 0)

# =============================================================================
# Summary
# =============================================================================
cat(sprintf("\n%s\n", strrep("=", 70)))
cat(sprintf("Total: %d  Passed: %d  Failed: %d\n",
            .test_count, .pass_count, .fail_count))
if (.fail_count > 0) {
  cat("\nFailures:\n")
  for (m in .fail_msgs) cat(m, "\n")
  quit(status = 1)
}
cat("All Dockerfile pinning tests passed.\n")
quit(status = 0)
