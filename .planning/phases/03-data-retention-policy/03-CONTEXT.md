# Phase 3: Data retention policy - Context

**Gathered:** 2026-09-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Stored job data has a defined expiry, applied automatically (issue #114). The
backend deletes every job older than the retention window — its `jobs` row and,
by cascade, its logs, file records and mirrored upload bytes — plus the matching
pod-local directories, without anyone triggering it. The window is stated where
users can see it and in the repository docs.

**In scope:** the purge routine and its schedule inside the existing backend
process; the on-disk cleanup that goes with it; a one-line user-facing notice;
README documentation; DB-free tests for the pure parts; post-deploy verification
on dev.

**Out of scope:** a user "delete my job" endpoint or button, an admin manual
purge action, per-job expiry dates in the UI, making the window configurable
per environment, any Kubernetes CronJob or database-side scheduler, and any
change to how jobs are stored.

</domain>

<decisions>
## Implementation Decisions

### Retention window
- **D-01:** Every job is deleted **90 days after it finished**. Age is
  `COALESCE(completed_at, created_at)`, so a job that never reached
  `completed` (stale `pending`/`running`) is purged on the same clock. One
  window for all jobs — every type, status, owner (including legacy
  `user_id IS NULL` jobs) and demo runs alike. The number lives in exactly one
  backend constant. — **Reversibility:** the constant is trivially changed;
  each deletion is one-way (no backup, no soft delete).
- **D-02:** Whole-job deletion, no tiering. `DELETE FROM jobs WHERE …` and let
  the existing `ON DELETE CASCADE` on `job_logs`, `job_files` and
  `job_input_files` do the rest; do not write per-table deletes. A shorter
  window for inputs than for results was rejected: it leaves jobs that exist
  but cannot be rerun or have their input downloaded, which would need new UI
  states for a degraded job.
- **D-03:** Demo jobs are not exempt. The `use_sample_data` / `demo_id` flags
  are stored only in the pod-local `data/jobs/<id>.json`, never in Postgres, so
  SQL cannot reliably tell a demo from an upload; and demo jobs grow the
  `GET /jobs` list just the same.
- **D-04:** No grandfathering and no dry-run switch. The first start after
  deploy purges everything already older than 90 days (roughly all ~240 jobs
  stored since January 2026, including the 194 pre-stall-flag results from
  issue #118). The purge writes one server log line with the count and the
  deleted ids so the first run is auditable. The user will warn the current
  testers to download what they need before the deploy. — **Reversibility:**
  one-way — the deleted rows and files have no backup.

### Purge mechanism
- **D-05:** The purge runs **inside the plumber server process**: once at
  startup, in `get_db_pool()` next to `cleanup_orphaned_jobs()` and behind the
  same `COMSA_WORKER != "1"` guard so per-job worker processes never run it,
  and then **every 24 hours** by re-scheduling itself with `later::later()`
  (httpuv's run loop services `later` callbacks between requests). Rejected:
  a Kubernetes CronJob (the namespace role could not even create a PVC in
  PR #113's check, CronJob rights are unverified, and it would need a second
  image or an authenticated endpoint), `pg_cron` (the database is externally
  hosted), and a purge-on-request endpoint (nothing would call it). Startup-only
  was rejected because deploys can be 16 days apart (issue #123 post-mortem).
- **D-06:** `later` is already in the image (1.4.8, transitively via plumber).
  Because the code will call it directly, add it to the explicit
  `install.packages()` list in `backend/Dockerfile` — the Phase 2 `sodium`
  lesson — and confirm `backend/package-manifest.csv` does not change.
- **D-07:** For each purged id also remove `data/uploads/<id>/`,
  `data/outputs/<id>/` and `data/jobs/<id>.json` if present (missing paths are
  not errors). A sweep of on-disk directories whose id no longer exists in
  `jobs` is optional (pod disk is wiped on every deploy anyway).
- **D-08:** A purge failure must never prevent the server from starting or
  serving: wrap it in `tryCatch`, log the error with `message()`, and let the
  next scheduled tick retry — the same posture as `cleanup_orphaned_jobs()`.

### Telling users
- **D-09:** One static sentence in the frontend where jobs are listed and/or
  submitted, to the effect of "Jobs and their uploaded files are deleted
  automatically 90 days after completion — download any results you need to
  keep." No per-job expiry date, no banner, no modal. The "90" shown to users
  must not silently diverge from the backend constant: either the API serves
  it (e.g. one field on the public `/health` response) or a dependency-free
  test asserts the two match. Planner picks.
- **D-10:** Document the policy in `README.md` (a short "Data retention"
  section; `backend/README.md` too if it describes stored data), and replace
  the "there is no automatic RETENTION/EXPIRY" comment in
  `backend/migrations/003_input_file_storage.sql` with a pointer to the purge.
  Closing issue #114 quotes the policy.

### Tests and verification
- **D-11:** Edge cases get a dependency-free R unit test **before**
  implementation (base R + jsonlite, same shape as
  `tests/test_input_persistence.R`, named explicitly in
  `.github/workflows/test.yml`): `completed_at` NULL falls back to
  `created_at`; a job exactly at the boundary; per-id disk removal when some
  or all paths are missing; the worker guard; and a source-level guard that the
  purge is wired into startup and reschedules itself.
- **D-12:** The real deletion is verified on dev after deploy, the way Phases
  1 and 02.1 were: the server log shows the first-run count, `GET /admin/jobs`
  (admin token from the browser session) lists no job with
  `COALESCE(completed_at, created_at)` older than 90 days, and a fresh job
  still runs, downloads and reruns normally.

### Claude's Discretion
- Exact SQL, function names, and where the purge helper lives
  (`backend/db/connection.R` beside `cleanup_orphaned_jobs()` is the obvious
  home).
- How the 24-hour tick is implemented (`later::later` re-arming itself vs. a
  plumber hook), as long as D-05's constraints hold.
- Whether the retention number reaches the frontend via `/health` or a
  guarded hard-coded string (D-09).
- Exact wording and placement of the user notice and the README section.
- Whether to include the optional orphan-directory sweep (D-07).

</decisions>

<canonical_refs>
## Canonical References

**Downstream agents MUST read these before planning or implementing.**

### The problem and its constraints
- GitHub issue #114 — the four decisions it asked for (retain what/how long;
  who purges; user delete; regulatory constraint) are all answered above: 90
  days, automatic in-process purge, no user delete this phase, no external
  constraint stated by the user.
- GitHub PR #113 body — records that the namespace role cannot create PVCs and
  the ResourceQuota has only ephemeral storage; the reason D-05 stays in-process.
- `backend/migrations/001_initial_schema.sql` — `jobs` timestamps
  (`created_at`, `started_at`, `completed_at`) and the `ON DELETE CASCADE` on
  `job_logs` / `job_files`.
- `backend/migrations/003_input_file_storage.sql` — cascade on
  `job_input_files` and the comment that must be updated (D-10).
- `.planning/codebase/CONCERNS.md` §"No data-retention/expiry policy" and
  §"`GET /jobs` cost grows linearly" — the two concerns this phase bounds.
- `.planning/codebase/ARCHITECTURE.md` §"Architectural Constraints" — process
  model (one `Rscript` per job), `COMSA_WORKER` guard, ephemeral disk layout.
- `.planning/ROADMAP.md` §"Phase 3" — goal and the two success criteria.

### Prior-phase lessons that apply
- `.planning/phases/02-reproducible-builds/02-CONTEXT.md` §"the missing
  `sodium` install" — why a directly-used package must be installed explicitly
  (D-06).
- `.planning/phases/02.1-adopt-vacalibration-2-3-1/02.1-CONTEXT.md` §D-12 —
  the post-deploy acceptance shape reused by D-12.

### Testing and deployment
- `.claude/skills/test/SKILL.md` — which suites exist and how they run.
- `.github/workflows/test.yml` — CI names each R suite explicitly; a new suite
  must be added there.
- `.claude/skills/comsa-k8s-deploy/SKILL.md` — deploy and verification path;
  kubectl is only reachable by dispatching `deploy.yml`.

</canonical_refs>

<code_context>
## Existing Code Insights

### Reusable Assets
- `backend/db/connection.R`: `get_db_pool()` initialises once per process and
  already runs `cleanup_orphaned_jobs()` on main-server startup only
  (`Sys.getenv("COMSA_WORKER") != "1"`), inside `tryCatch` with `message()`
  logging — the exact placement and error posture for the purge.
- `backend/db/connection.R`: `get_job_metadata_path()` and the constants for
  `data/jobs/`; upload and output dirs are `data/uploads/<id>/` and
  `data/outputs/<id>/` (see `POST /jobs` and the download route in
  `backend/plumber.R`).
- `later` 1.4.8 and `promises` 1.5.0 are in `backend/package-manifest.csv`
  (plumber dependencies), so scheduling needs no new package version.
- `GET /admin/jobs` (`backend/plumber.R`) returns `created_at`,
  `completed_at`, `user_email` for every job — the post-deploy verification
  query. `GET /health` is the only unauthenticated JSON route.
- `tests/test_input_persistence.R` — the dependency-free suite template
  (`section()` / `test()`, `quit(status = 1)` on failure);
  `tests/test_dockerfile_pinning.R` — the source-assertion guard pattern.

### Established Patterns
- Durable state is Postgres only; pod disk is ephemeral and wiped per deploy.
  The purge must treat missing on-disk paths as normal.
- Job status transitions are written only by the worker; startup recovery is
  the one exception. The purge is a second startup/periodic maintenance task
  and should look like the first.
- Every `install.packages()` in the Dockerfile runs under `options(warn=2)`;
  the manifest diff in `deploy.yml` must pass unchanged (D-06 adds no version).
- Frontend copy is plain JSX text; `JobList.jsx` has an empty-state block and
  a table header, `JobForm.jsx` the upload area — either is a natural place for
  the notice (D-09).

### Integration Points
- `backend/db/connection.R` `get_db_pool()` — startup hook and worker guard.
- `backend/Dockerfile` explicit install list (add `later`).
- `.github/workflows/test.yml` backend job — register the new suite.
- `README.md` — new "Data retention" section; `backend/migrations/003_…sql`
  comment.
- `frontend/src/components/JobList.jsx` or `JobForm.jsx` — the notice; a
  Vitest source/behaviour test alongside if the number is hard-coded.

</code_context>

<specifics>
## Specific Ideas

- The user chose 90 days, first-run purge of all historical jobs, and a UI
  one-liner plus repo docs — all three recommended options, no free-text
  amendments. No data-use-agreement or IRB constraint on the window was raised.
- Side effect worth noting in the closing comment: purging pre-2026-06 jobs
  also retires the 194 stored results from issue #118 that predate the stall
  flag.
- Dev has been login-only since PR #112; results are regenerable from the
  user's own CSV via a fresh upload, which is why irreversible deletion was
  accepted without a soft-delete.

</specifics>

<deferred>
## Deferred Ideas

- User-initiated "delete my job" (endpoint + button) — asked in #114 point 3;
  a new capability. The purge helper should be written so a future
  `DELETE /jobs/<id>` can call it for one id.
- Admin manual purge / "purge now" button — same reason.
- Per-job "expires on" column in the job list.
- A log-only (dry-run) mode or an env var to change the window per environment.
- Exempting demo jobs would first require persisting the demo flag in the
  `jobs` table.
- Bounding `GET /jobs` cost directly (issue-#118-era concern) — retention
  caps the row count but the per-job `load_job()` fan-out is untouched.

</deferred>

---

*Phase: 03-data-retention-policy*
*Context gathered: 2026-09-13*
