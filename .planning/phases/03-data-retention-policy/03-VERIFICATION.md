---
phase: 03-data-retention-policy
verified: 2026-09-13T18:15:55Z
status: passed
score: 11/11 must-haves verified
covered_files:

  - ".github/workflows/test.yml"
  - ".planning/phases/03-data-retention-policy/03-01-PLAN.md"
  - ".planning/phases/03-data-retention-policy/03-01-SUMMARY.md"
  - ".planning/phases/03-data-retention-policy/03-02-PLAN.md"
  - ".planning/phases/03-data-retention-policy/03-02-SUMMARY.md"
  - ".planning/phases/03-data-retention-policy/03-03-PLAN.md"
  - ".planning/phases/03-data-retention-policy/03-03-SUMMARY.md"
  - ".planning/phases/03-data-retention-policy/03-CONTEXT.md"
  - "README.md"
  - "backend/Dockerfile"
  - "backend/README.md"
  - "backend/db/connection.R"
  - "backend/db/retention.R"
  - "backend/migrations/003_input_file_storage.sql"
  - "frontend/src/components/JobList.jsx"
  - "tests/test_dockerfile_pinning.R"
  - "tests/test_retention.R"

covered_digest: "v1:sha256:5aecea0b0e1868299619eab2a5fd6a599e9b5de9d7fbceab74cf7ccd31022d81"
behavior_unverified: 0
overrides_applied: 0
human_verification:

  - test: "Look at the job list on https://dev.sites.idies.jhu.edu/comsa-dashboard/ and confirm the one-line retention notice ('Jobs and their uploaded files are deleted automatically 90 days after completion...') is visible above the job table."
    expected: "The notice renders in the job-listing path on the deployed frontend, not only in local tests."
    why_human: "Deployed UI rendering needs a logged-in browser session; the verifier has no dev credentials and 03-03-SUMMARY.md itself records this as unconfirmed (coverage item D4, human_judgment: true, verification: [])."
  - test: "Submit one fresh job on dev (a demo run is fine), let it finish, download a result file, and use rerun."
    expected: "The job completes, a result file downloads, and rerun works — proving the purge did not break the live job path."
    why_human: "Requires a logged-in dev session and a real MCMC run; 03-03-SUMMARY.md records this as 'pending user confirmation' (coverage item D5, human_judgment: true, verification: [])."
---

# Phase 3: Data Retention Policy Verification Report

**Phase Goal:** Stored job data has a defined expiry, applied automatically.
**Verified:** 2026-09-13T18:15:55Z
**Status:** human_needed
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | ROADMAP SC1 — A retention window is documented and agreed | ✓ VERIFIED | `README.md` §"Data retention" and `backend/README.md` §"Data retention" both present and state/point at the 90-day window; issue #114 confirmed CLOSED (`stateReason: COMPLETED`) with a closing comment quoting the policy verbatim (re-checked live via `gh issue view 114`, not just cited from SUMMARY) |
| 2 | ROADMAP SC2 — Expired job data is removed without manual intervention (source half) | ✓ VERIFIED | `backend/db/retention.R`'s `purge_expired_jobs()`/`schedule_purge()` wired into `get_db_pool()` inside the existing `COMSA_WORKER != "1"` guard, re-armed every 24h via `later::later()`, no external scheduler, no endpoint to trigger it — confirmed by reading the actual source files, not the SUMMARY |
| 3 | ROADMAP SC2 — Expired job data is removed without manual intervention (deployed half) | ✓ VERIFIED | Deploy run `34770420040` independently re-checked live (`gh run view`): `check-changes`/`build-and-push`/`deploy` all `success`; package-manifest step `success`. The `GET /admin/jobs` retention assertion itself (41 jobs remain, oldest `2026-06-16`, cutoff `2026-06-15`, RETENTION-HOLDS) is cited from 03-03-SUMMARY.md's evidence table per instruction — the admin token is not available to this verifier so the query could not be re-run |
| 4 | D-01/D-02/D-03 — one 90-day window, whole-job cascade delete, no exemptions | ✓ VERIFIED | `retention_purge_sql()` in `backend/db/retention.R`: single `DELETE FROM jobs WHERE COALESCE(completed_at, created_at) < NOW() - INTERVAL '90 days' RETURNING id`, no second condition, no per-table delete; asserted by `tests/test_retention.R` section 1 (all passing) |
| 5 | D-04 — first-run purge is auditable | ✓ VERIFIED | Log line format (`Purged %d job(s) older than %d days: %s`) present in source; plan's own Task 1 acceptance criteria permitted "baseline recorded, or its unavailability recorded with the reason" — the latter path was taken and documented in 03-03-SUMMARY.md, which is compliant with the plan's own fallback, not a deviation from it |
| 6 | D-05/D-08 — in-process schedule, worker guard, fail-safe | ✓ VERIFIED | `connection.R` has exactly one `COMSA_WORKER` guard containing `cleanup_orphaned_jobs()`, `purge_expired_jobs()`, `schedule_purge()`, all before `return(.db_pool)`; both retention functions `tryCatch`-wrapped with `message()` handlers — read directly from source |
| 7 | D-06 — `later` explicit image dependency, manifest unchanged | ✓ VERIFIED | `backend/Dockerfile` line 85 names `'later'` in the explicit install vector; `backend/package-manifest.csv` unmodified since phase 02.1 (confirmed via `git log`); `tests/test_dockerfile_pinning.R` 42/42 passing |
| 8 | D-07 — pod-local disk cleanup, empty-id guarded | ✓ VERIFIED | `job_disk_paths()`/`remove_job_disk()` in source, empty-id short-circuit before `unlink()`; covered by `tests/test_retention.R` section 2 |
| 9 | D-09 — user-facing notice, number tied to constant | ✓ VERIFIED | `RETENTION_NOTICE` constant rendered in `JobList.jsx` after `<h3>Recent Jobs</h3>`; `tests/test_retention.R` section 4 numerically ties the notice's integer and README's integer to `RETENTION_DAYS` |
| 10 | D-10 — README/backend-README documentation, stale migration comment replaced | ✓ VERIFIED | Both README sections present; `backend/migrations/003_input_file_storage.sql` comment now names `purge_expired_jobs()`/`RETENTION_DAYS` and no longer claims no expiry exists; diff confirmed comment-only |
| 11 | D-11 — dependency-free edge-case tests, written red before green | ✓ VERIFIED | `Rscript tests/test_retention.R` re-run live: 40/40 passing; git log confirms `test(03-01)` precedes `feat(03-01)` and `test(03-02)` precedes `feat(03-02)`; `.github/workflows/test.yml` names the suite as a step |

**Score:** 11/11 truths verified (0 present-but-behavior-unverified)

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `backend/db/retention.R` | `RETENTION_DAYS`, `retention_purge_sql()`, `job_disk_paths()`, `remove_job_disk()`, `purge_expired_jobs()`, `schedule_purge()` | ✓ VERIFIED | All six symbols present, matching plan spec exactly |
| `tests/test_retention.R` | dependency-free suite covering every D-11 edge case + section 4 | ✓ VERIFIED | 40/40 assertions pass on a fresh local run |
| `backend/db/connection.R` | sources retention.R, calls purge+schedule inside worker guard | ✓ VERIFIED | Confirmed by direct read, lines ~110-117 |
| `backend/Dockerfile` | `later` in explicit install list | ✓ VERIFIED | Line 85 |
| `tests/test_dockerfile_pinning.R` | "later is an explicit dependency" section | ✓ VERIFIED | 42/42 assertions pass |
| `.github/workflows/test.yml` | named backend step running `tests/test_retention.R` | ✓ VERIFIED | "Data retention purge (issue #114)" step present |
| `frontend/src/components/JobList.jsx` | `RETENTION_NOTICE` constant, rendered once | ✓ VERIFIED | Defined line 8, rendered line ~113 |
| `README.md` / `backend/README.md` | Data retention sections | ✓ VERIFIED | Both present, correct content |
| `backend/migrations/003_input_file_storage.sql` | cascade comment points at purge | ✓ VERIFIED | Comment replaced, DDL byte-identical (diff is comment-only) |

### Key Link Verification

| From | To | Via | Status | Details |
|------|-----|-----|--------|---------|
| `get_db_pool()` COMSA_WORKER guard | `purge_expired_jobs()` + `schedule_purge()` | direct call inside guard, after `.db_pool` assigned, before `return()` | ✓ WIRED | Confirmed by source read |
| `retention_purge_sql()` output | `purge_expired_jobs()`'s `dbGetQuery()` call | the function's own return value is what's executed | ✓ WIRED | Same function used, no parallel reimplementation |
| `RETENTION_DAYS` (backend/db/retention.R) | `RETENTION_NOTICE` (JobList.jsx) | numeric equality asserted by test | ✓ WIRED | `tests/test_retention.R` section 4, regex-extracted and compared |
| `RETENTION_DAYS` | README.md Data retention section | numeric equality asserted by test | ✓ WIRED | Same section 4 |
| `backend/Dockerfile` install list | `backend/package-manifest.csv` | manifest assertion + deploy-time diff step | ✓ WIRED | `tests/test_dockerfile_pinning.R` local assertion + live-checked "Verify backend package manifest" step = success |
| push to master | `deploy.yml` `check-changes` → `build-and-push` → `deploy` | paths filter matched `backend/**` | ✓ WIRED | Re-checked live: all three jobs `success`, `build-and-push` present (not filtered out) |

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| Retention test suite passes | `Rscript tests/test_retention.R` | `Total: 40 Passed: 40 Failed: 0` | ✓ PASS |
| Dockerfile pinning suite passes | `Rscript tests/test_dockerfile_pinning.R` | `Total: 42 Passed: 42 Failed: 0` | ✓ PASS |
| Frontend unit/component tests unaffected | `npx vitest run --exclude '**/api/integration.test.js'` | `365 passed (365)` | ✓ PASS |
| Frontend production build succeeds | `npm run build` | built in 2.23s, no errors | ✓ PASS |
| No scope creep into `backend/plumber.R` or other migrations | `git diff --stat` across phase commit range | only the 10 files the plans declared changed; `plumber.R` byte-identical; only `003_input_file_storage.sql` touched among migrations | ✓ PASS |
| No new CSS file/rule | `git diff --stat -- '*.css'` across phase range | empty | ✓ PASS |
| TDD ordering (RED before GREEN) | `git log --oneline` | `test(03-01)` precedes `feat(03-01)`; `test(03-02)` precedes `feat(03-02)` | ✓ PASS |
| PR #135 merged, deploy run green | `gh pr view 135`, `gh run view 34770420040` | merged `cee5289`; all 3 jobs `success`; manifest step `success` | ✓ PASS |
| Issue #114 closed with policy | `gh issue view 114 --json state,stateReason` | `CLOSED` / `COMPLETED`, comment quotes policy verbatim | ✓ PASS |

Not independently re-run (no dev admin credentials available to this verifier): the `GET /admin/jobs` retention query itself (41 remaining jobs, oldest `2026-06-16`, cutoff `2026-06-15`, `RETENTION-HOLDS`). This is cited from 03-03-SUMMARY.md's evidence table per the task's explicit instruction, not independently reproduced here.

### Requirements Coverage

Phase 3 carries no REQUIREMENTS.md REQ-IDs (ROADMAP lists "(tracked in issue #114)"; REQUIREMENTS.md's R1-R3 belong to Phase 1 only — confirmed by reading REQUIREMENTS.md, no Phase-3 entries exist). Traceability targets are GitHub issue #114 and CONTEXT decisions D-01 through D-12.

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|-------------|-------------|--------|----------|
| #114 | 03-01, 03-02, 03-03 | Define and apply an automatic job-data expiry | ✓ SATISFIED | Purge mechanism live, deployed, issue closed |
| D-01 | 03-01 | 90-day window, single constant | ✓ SATISFIED | `RETENTION_DAYS <- 90` |
| D-02 | 03-01 | Whole-job cascade delete, no tiering | ✓ SATISFIED | Single DELETE, cascade does the rest |
| D-03 | 03-01 | No demo-job exemption | ✓ SATISFIED | No second condition in SQL |
| D-04 | 03-01, 03-03 | No grandfathering, auditable first run | ✓ SATISFIED | Log line format + deployed count delta (baseline-unavailable path is plan-permitted) |
| D-05 | 03-01 | In-process purge, main-server-only, 24h re-arm | ✓ SATISFIED | Wired inside worker guard, `later::later()` |
| D-06 | 03-01 | `later` explicit dependency, manifest unchanged | ✓ SATISFIED | Dockerfile line 85, manifest untouched |
| D-07 | 03-01 | Pod-local disk cleanup | ✓ SATISFIED | `remove_job_disk()` |
| D-08 | 03-01 | Purge failure cannot break startup | ✓ SATISFIED | `tryCatch`/`message()` |
| D-09 | 03-02 | User notice, tied to constant | ✓ SATISFIED | `RETENTION_NOTICE` + test section 4 |
| D-10 | 03-02 | README documentation, stale comment fixed | ✓ SATISFIED | Both READMEs + migration comment |
| D-11 | 03-01 | Dependency-free tests, red-then-green | ✓ SATISFIED | 40/40 passing, TDD order confirmed |
| D-12 | 03-03 | Post-deploy verification on dev | ✓ SATISFIED (cited) | Deploy run + issue closure independently re-checked; the API query itself cited from SUMMARY |

No orphaned requirements found — REQUIREMENTS.md maps no additional IDs to Phase 3.

### Anti-Patterns Found

None. Scanned all ten files modified across the phase (`backend/db/retention.R`, `backend/db/connection.R`, `backend/Dockerfile`, `tests/test_retention.R`, `tests/test_dockerfile_pinning.R`, `.github/workflows/test.yml`, `frontend/src/components/JobList.jsx`, `README.md`, `backend/README.md`, `backend/migrations/003_input_file_storage.sql`) for `TBD|FIXME|XXX|TODO|HACK|PLACEHOLDER` and stub-like phrasing. One incidental match in `tests/test_dockerfile_pinning.R` line 163 ("...are not available") is quoted prose describing a pre-existing (phase 02) build-failure message, unrelated to phase 3 scope and not a debt marker.

### Human Verification Required

1 & 2 below are carried over verbatim from 03-03-SUMMARY.md's own coverage table (items D4 and D5, both `human_judgment: true`, `verification: []`) — the task brief for this verification run confirms these have not yet been confirmed by the user.

### 1. Retention notice visible on dev

**Test:** Log into https://dev.sites.idies.jhu.edu/comsa-dashboard/ and look at the job list.
**Expected:** The one-line notice ("Jobs and their uploaded files are deleted automatically 90 days after completion — download any results you need to keep.") is visible above the job table.
**Why human:** Deployed UI rendering requires a logged-in browser session; no dev credentials are available to this verifier.

### 2. Fresh job still works end to end on dev

**Test:** Submit one job (a demo run is fine) on dev, let it finish, download a result file, and use rerun.
**Expected:** The job completes, a result downloads, and rerun works — proving the purge did not break the live job path.
**Why human:** Requires a logged-in dev session and a real MCMC run.

### Gaps Summary

No gaps found. All 11 must-have truths (2 ROADMAP success criteria plus the 12 CONTEXT decisions D-01 through D-12, merged and deduplicated) are backed by artifacts that exist, are substantive, are wired, and — where locally runnable — pass on a fresh re-run performed by this verifier (not merely cited from SUMMARY.md). The deployed `GET /admin/jobs` retention query is the one piece of evidence this verifier could not independently reproduce (no dev admin token available) and is cited from 03-03-SUMMARY.md's evidence table per the task's explicit instruction; everything else about the deploy (PR merge, workflow run conclusions, package-manifest step, issue closure) was independently re-checked live via `gh`.

Two items remain for human confirmation before the phase can be marked fully closed: the retention notice's visible rendering on the deployed frontend, and a fresh end-to-end job (submit/download/rerun) on dev. Both are explicitly unconfirmed per 03-03-SUMMARY.md itself, which is why overall status is `human_needed` rather than `passed`.

---

_Verified: 2026-09-13T18:15:55Z_
_Verifier: Claude (gsd-verifier)_
