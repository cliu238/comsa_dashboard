# Phase 3: Data retention policy - Pattern Map

**Mapped:** 2026-09-13
**Files analyzed:** 7
**Analogs found:** 7 / 7

## File Classification

| New/Modified File | Role | Data Flow | Closest Analog | Match Quality |
|-------------------|------|-----------|----------------|---------------|
| `backend/db/connection.R` (add `purge_expired_jobs()` + scheduler) | service/utility | batch (startup + periodic DB+disk cleanup) | `backend/db/connection.R` `cleanup_orphaned_jobs()` (same file, lines 122-139) | exact |
| `backend/Dockerfile` (add `later` to install list) | config | batch (build-time) | `backend/Dockerfile` line 77 `install.packages(c('plumber', ...))` | exact |
| `tests/test_retention.R` (new) | test | batch/transform (dependency-free unit tests) | `tests/test_input_persistence.R` (full file) | exact |
| `tests/test_dockerfile_pinning.R` (extend with `later` + manifest assertions) | test | transform (source-assertion) | `tests/test_dockerfile_pinning.R` "sodium is an explicit dependency" section | exact |
| `.github/workflows/test.yml` (register new suite) | config | batch (CI) | existing `backend:` job step list | exact |
| `frontend/src/components/JobList.jsx` (add notice) | component | request-response (render) | `JobList.jsx` empty-state block, lines 102-109 | exact |
| `README.md` / `backend/migrations/003_input_file_storage.sql` (docs) | config | N/A (documentation) | existing "no automatic RETENTION/EXPIRY" comment in `003_input_file_storage.sql` | exact |

## Pattern Assignments

### `backend/db/connection.R` — add `purge_expired_jobs()` and scheduling

**Analog:** `backend/db/connection.R` (same file), `cleanup_orphaned_jobs()` at lines 122-139, and its call site inside `get_db_pool()` at lines 113-117.

**Startup-hook + worker-guard pattern** (lines 113-117):
```r
    # Orphan cleanup, by contrast, must run once — main server startup only, not
    # in per-job workers.
    if (Sys.getenv("COMSA_WORKER") != "1") {
      cleanup_orphaned_jobs()
    }
```
Add the purge call immediately after this, behind the same guard:
```r
    if (Sys.getenv("COMSA_WORKER") != "1") {
      cleanup_orphaned_jobs()
      purge_expired_jobs()
      schedule_purge()   # re-arms itself via later::later() every 24h
    }
```

**Error-handling / logging pattern** (lines 122-139, `cleanup_orphaned_jobs`):
```r
cleanup_orphaned_jobs <- function() {
  tryCatch({
    conn <- .db_pool
    result <- dbGetQuery(conn, "
      UPDATE jobs
      SET status = 'failed', ...
      RETURNING id
    ")
    if (nrow(result) > 0) {
      message(sprintf("Cleaned up %d orphaned running job(s): %s",
        nrow(result), paste(result$id, collapse = ", ")))
    }
  }, error = function(e) {
    message("Warning: Failed to clean up orphaned jobs: ", conditionMessage(e))
  })
}
```
`purge_expired_jobs()` should follow this exact shape: `tryCatch(..., error = function(e) message(...))`, a `DELETE ... RETURNING id` query, and a `message()` log line with count + ids (D-08, D-04). Age predicate per D-01: `WHERE COALESCE(completed_at, created_at) < NOW() - INTERVAL '90 days'`. Whole-row delete relies on existing `ON DELETE CASCADE` (D-02) — no per-table deletes needed (cascades already defined in `backend/migrations/001_initial_schema.sql` for `job_logs`/`job_files` and `003_input_file_storage.sql` for `job_input_files`).

**On-disk cleanup pattern** — reuse path helpers already in this file:
```r
.job_metadata_dir <- file.path("data", "jobs")
get_job_metadata_path <- function(job_id) {
  file.path(.job_metadata_dir, paste0(job_id, ".json"))
}
```
For each purged id, additionally build `file.path("data", "uploads", job_id)` and `file.path("data", "outputs", job_id)` (these path strings are used verbatim elsewhere in `backend/plumber.R` for upload/download routes — grep confirms `mkdir -p /app/data/uploads /app/data/outputs` in `backend/Dockerfile` line 152). Remove with `unlink(path, recursive = TRUE)`, and treat `!file.exists(path)` as a no-op, not an error (D-07).

**Scheduling pattern (new, no direct analog)** — `later::later(schedule_purge, delay = 24*60*60)` called from inside `purge_expired_jobs()`'s own tryCatch (or a thin wrapper) so the reschedule happens even if the previous purge errored (D-05, D-08). No existing `later` usage in the codebase; this is new per D-05/D-06's discretion ("re-arming itself vs. a plumber hook").

---

### `backend/Dockerfile` — add `later` to explicit install list

**Analog:** line 77 (same file):
```
RUN R -e "options(warn=2); install.packages(c('plumber', 'jsonlite', 'uuid', 'future', 'RPostgres', 'pool', 'jose', 'sodium'))"
```
Append `'later'` to this same vector (mirrors the documented "sodium lesson" — a transitively-available package must be listed explicitly once the code calls it directly). Comment above should explain why, following the sodium comment's style (lines directly above 77 in the current file). Per D-06, `backend/package-manifest.csv` must NOT change (later 1.4.8 is already present transitively) — only the explicit-install list changes.

---

### `tests/test_retention.R` (new) — dependency-free unit tests

**Analog:** `tests/test_input_persistence.R` (full file, 1-90 approx).

**Harness pattern** (lines 1-23):
```r
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
```

**Source-locate pattern** (dual entry point root/backend):
```r
utils_path <- if (file.exists("backend/jobs/utils.R")) "backend/jobs/utils.R" else "../backend/jobs/utils.R"
source(utils_path)
```
Adapt to source `backend/db/connection.R` (or an extracted pure helper) the same dual-path way.

**Summary/exit pattern** (tail of file):
```r
cat(sprintf("\n%s\n", strrep("=", 70)))
cat(sprintf("Total: %d  Passed: %d  Failed: %d\n", .test_count, .pass_count, .fail_count))
if (.fail_count > 0) { cat("\nFailures:\n"); for (m in .fail_msgs) cat(m, "\n"); quit(status = 1) }
cat("All input persistence tests passed.\n")
quit(status = 0)
```

Per D-11, cover: `completed_at` NULL falls back to `created_at`; boundary-exact job (90 days to the second); per-id disk removal with some/all paths missing (use `unlink`/`file.exists` the same way the analog's `tmp <- tempfile(...)` setup does); the `COMSA_WORKER` guard (assert purge is not called when `COMSA_WORKER == "1"` — this likely needs a source-level grep assertion, see next pattern); and the startup/reschedule wiring.

---

### `tests/test_dockerfile_pinning.R` — extend with `later` + guard assertions

**Analog:** same file, "sodium is an explicit dependency" section (search `grepl("'sodium'"`):
```r
test("an install.packages( call includes 'sodium' explicitly",
     any(grepl("install.packages(", code, fixed = TRUE) & grepl("'sodium'", code, fixed = TRUE)))

test("libsodium-dev is still present (system library, distinct from the R package)",
     any(grepl("libsodium-dev", code, fixed = TRUE)))
```
Add an analogous section: `test("an install.packages( call includes 'later' explicitly", ...)` plus (per D-06) a manifest-unchanged assertion mirroring the vacalibration-manifest check pattern:
```r
test("backend/package-manifest.csv records vacalibration,2.3.1",
     file.exists(manifest_path) &&
       "vacalibration,2.3.1" %in% trimws(readLines(manifest_path)))
```

**Source-level wiring guard** (for D-11's "purge is wired into startup and reschedules itself") — follow the `grep`-on-source style used for Dockerfile assertions; apply the same technique against `backend/db/connection.R` source lines (read with `readLines`, assert call to `purge_expired_jobs()` appears inside the `COMSA_WORKER != "1"` guard block and that `later::later(` appears in the purge function body).

---

### `.github/workflows/test.yml` — register the new suite

**Analog:** existing step list in the `backend:` job (tail of file):
```yaml
      - name: Dockerfile pinning guard (issue #123)
        run: Rscript tests/test_dockerfile_pinning.R
      - name: Install jsonlite
        run: Rscript -e 'install.packages("jsonlite")'
      - name: Misclassification matrix (issue #104)
        run: Rscript tests/test_misclass_matrix.R
      ...
      - name: Input-file persistence codec (issue #110)
        run: Rscript tests/test_input_persistence.R
```
Add a new named step `- name: Data retention purge (issue #114)` / `run: Rscript tests/test_retention.R` after the input-persistence step, same one-line-per-suite style, named explicitly (never globbed) per CLAUDE.md and the file's own stated convention.

---

### `frontend/src/components/JobList.jsx` — user-facing notice

**Analog:** empty-state block, lines 102-109 in `frontend/src/components/JobList.jsx`:
```jsx
  if (jobs.length === 0) {
    return (
      <div className="job-list empty">
        <p>No jobs yet. Submit a job or run a demo to get started.</p>
      </div>
    );
  }

  return (
    <div className="job-list">
      <h3>Recent Jobs</h3>
      <table>
```
This is plain JSX text, no i18n/props layer — matches D-09's "static sentence" requirement. Add a `<p className="retention-notice">Jobs and their uploaded files are deleted automatically 90 days after completion — download any results you need to keep.</p>` near the `<h3>Recent Jobs</h3>` heading (non-empty-state path) so it is visible whenever jobs are listed, not only on the empty state. If the "90" is sourced from `/health` instead of hard-coded (D-09's open choice), `GET /health` already returns a plain list (`backend/plumber.R` lines 99-102):
```r
#* Health check
#* @get /health
function() {
  list(status = "ok", timestamp = Sys.time())
}
```
Adding a `retention_days = 90` field here follows the same flat-list return shape; the frontend would fetch `/health` the way other API calls in `frontend/src/api/` are structured (not directly inspected — no existing `/health` consumer found in frontend, so this is a new small fetch, best kept simple per CLAUDE.md: a one-line `fetch('/health').then(r => r.json()).then(d => setDays(d.retention_days))` is sufficient, no new api/ module required for a single number).

---

### Documentation — `README.md`, `backend/migrations/003_input_file_storage.sql`

**Analog:** the comment to replace, in `backend/migrations/003_input_file_storage.sql` (exact text not re-quoted here to avoid truncation risk — locate via `grep -n "RETENTION" backend/migrations/003_input_file_storage.sql` during implementation) stating "there is no automatic RETENTION/EXPIRY". Replace with a one-line comment pointing at the purge location, e.g. `-- Automatic purge: see purge_expired_jobs() in backend/db/connection.R (issue #114, 90-day window).`

For `README.md`, follow the existing top-level section style (short heading + 2-4 sentences, no tables) — add a "## Data retention" section stating the 90-day window, whole-job cascade delete, and no user-delete endpoint in this phase. If `backend/README.md` exists and mentions stored data, mirror the same short section there.

---

## Shared Patterns

### Startup-only maintenance task, guarded and tryCatch-wrapped
**Source:** `backend/db/connection.R` `cleanup_orphaned_jobs()` (lines 122-139) and its call site in `get_db_pool()` (lines 113-117).
**Apply to:** `purge_expired_jobs()` and its scheduler — same `tryCatch` + `message()` logging posture, same `COMSA_WORKER != "1"` guard, called from the same place in `get_db_pool()`.

### Dependency-free R test harness
**Source:** `tests/test_input_persistence.R` (test/section helpers, dual root/backend source-locate, summary+quit(status=) tail).
**Apply to:** `tests/test_retention.R`.

### Source-assertion testing over Dockerfile/config text
**Source:** `tests/test_dockerfile_pinning.R` (comment-stripped `code <- lines[!grepl("^\\s*#", lines)]`, then `grepl(..., fixed = TRUE)` assertions).
**Apply to:** the `later` package-install assertion and the purge-wiring source guard in `backend/db/connection.R`.

### Plain-JSX static user notices
**Source:** `frontend/src/components/JobList.jsx` (no props/i18n layer for static copy — see empty-state `<p>` at lines 102-109).
**Apply to:** the retention notice text.

### Explicit CI suite registration (no globbing)
**Source:** `.github/workflows/test.yml` `backend:` job step list — every suite named explicitly with a comment tying it to its issue number; `tests/test_vacalibration_backend.R` is the documented counter-example (deliberately excluded, stated why).
**Apply to:** registering `tests/test_retention.R`.

## No Analog Found

None — every file in scope has a same-file or near-identical analog (largely because the purge extends `cleanup_orphaned_jobs()` in the very file it lives in).

## Metadata

**Analog search scope:** `backend/db/connection.R`, `backend/plumber.R`, `backend/Dockerfile`, `tests/*.R`, `.github/workflows/test.yml`, `frontend/src/components/JobList.jsx`, `frontend/src/components/JobForm.jsx`
**Files scanned:** 8
**Pattern extraction date:** 2026-09-13
