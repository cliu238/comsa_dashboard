---
phase: "03"
slug: "data-retention-policy"
status: verified
# threats_open = count of OPEN threats at or above workflow.security_block_on severity (the blocking gate)
threats_open: 0
asvs_level: 1
created: "2026-09-13"
---

# Phase 03 — Security

> Per-phase security contract: threat register, accepted risks, and audit trail.

---

## Trust Boundaries

| Boundary | Description | Data Crossing |
|----------|-------------|---------------|
| plumber process -> `jobs` table | An unbounded or mis-predicated DELETE destroys live user data; no backup, no soft delete | job rows (metadata, results, mirrored inputs) |
| purge loop -> pod filesystem | `unlink(recursive = TRUE)` on a path built from an id | uploaded VA CSVs, output files |
| main server -> per-job worker processes | Both source `db/connection.R`; only the main server may run maintenance | DB pool, scheduler |
| Dockerfile install list -> built image -> deploy-time manifest diff | A changed resolved version fails the deploy | package versions |
| backend constant -> user-facing copy | Users decide whether to download based on the stated window | retention window (90 days) |
| repository documentation -> future maintainer | A stale "no expiry" comment would breed a conflicting policy | policy text |
| local repo -> master -> GHCR image -> k8s-dev pod | Merge turns reviewed source into a running purge | container image |
| new pod -> production job data | First DB request in the new pod bulk-deletes expired jobs irreversibly | ~240 expired job rows and files |
| browser session -> dev API | Login-only since PR #112; admin JWT needed to read `/admin/jobs` | admin JWT |

---

## Threat Register

| Threat ID | Category | Component | Severity | Disposition | Mitigation | Status |
|-----------|----------|-----------|----------|-------------|------------|--------|
| T-03-01 | Tampering | `retention_purge_sql()` age predicate | critical | mitigate | Single pure function `backend/db/retention.R:27` emits `DELETE FROM jobs WHERE COALESCE(completed_at, created_at) < NOW() - INTERVAL '%d days' RETURNING id`; `tests/test_retention.R` asserts shape and that `retention_purge_sql(7)` contains no `90` (40/40 pass) | closed |
| T-03-02 | Denial of Service | `remove_job_disk()` path construction | high | mitigate | Empty-id guard `if (!nzchar(job_id)) return(invisible(FALSE))` at `retention.R:58` before `unlink()`; suite asserts parent dirs and sibling job survive | closed |
| T-03-03 | Denial of Service | purge raising during pool init | high | mitigate | `purge_expired_jobs()` (`retention.R:69`) and `schedule_purge()` (`retention.R:92`) both wrap bodies in `tryCatch`; re-arm follows the swallowed call | closed |
| T-03-04 | Elevation of Privilege | per-job worker running the purge | medium | mitigate | Calls sit inside the single `Sys.getenv("COMSA_WORKER") != "1"` guard at `connection.R:116-120`; asserted by suite | closed |
| T-03-05 | Repudiation | unauditable first mass deletion | high | mitigate | `RETURNING id` + `message(sprintf("Purged %d job(s) older than %d days: %s", ...))` at `retention.R:76`; 03-03-SUMMARY records post-deploy inventory (41 remain, oldest 2026-06-16, cutoff 2026-06-15) | closed |
| T-03-SC | Tampering | adding `later` to the image install list | high | mitigate | `later,1.4.8` already at `backend/package-manifest.csv:70`; `tests/test_dockerfile_pinning.R` "later is an explicit dependency" section (42/42 pass); deploy step "Verify backend package manifest (issue #123)" in `.github/workflows/deploy.yml:120` succeeded on run 34770420040 | closed |
| T-03-06 | Information Disclosure | purge log line contents | low | accept | UUIDs and a count only; same log already records orphan-cleanup ids — see AR-03-01 | closed |
| T-03-07 | Repudiation | user-facing window diverging from enforced window | high | mitigate | `tests/test_retention.R` section 4 numerically compares `RETENTION_NOTICE` (`JobList.jsx:8`) and README Data retention section against `RETENTION_DAYS`; runs in CI | closed |
| T-03-08 | Tampering | schema edit disguised as a documentation change | medium | mitigate | Verified: last diff to `backend/migrations/003_input_file_storage.sql` (commit `cee5289`) contains only `--` comment lines | closed |
| T-03-09 | Information Disclosure | the notice text | low | accept | Static copy, no identifiers, rendered to an authenticated user — see AR-03-02 | closed |
| T-03-10 | Spoofing | injecting markup through the notice | low | accept | Module constant rendered as JSX text child (`{RETENTION_NOTICE}`), no `dangerouslySetInnerHTML` — see AR-03-03 | closed |
| T-03-11 | Denial of Service | irreversible first-run bulk purge | critical | mitigate | Blocking human gate before deploy; user selected `proceed` (03-03-SUMMARY). Pre-deploy baseline was unavailable (no token at gate time) and is recorded as such rather than omitted | closed |
| T-03-12 | Repudiation | "the purge ran" claimed without evidence | high | mitigate | Real `GET /admin/jobs` query with printed cutoff, oldest remaining timestamp and `RETENTION-HOLDS` sentinel in 03-03-SUMMARY; pod-log unavailability written down | closed |
| T-03-13 | Repudiation | "the deploy succeeded" read from the wrong signal | medium | mitigate | Per-job conclusions via `gh run view 34770420040 --json jobs`; `build-and-push` job present and `success` | closed |
| T-03-14 | Spoofing | inspecting the job inventory without an admin session | low | mitigate | `/admin/jobs` guarded by `require_admin(req, res)` at `plumber.R:864`; token from the user's own browser session | closed |
| T-03-15 | Information Disclosure | admin JWT pasted into the session transcript | medium | accept | Short-lived dev-scoped token, read-only use, never written to a file; grep for `eyJ` across all phase-03 docs returns 0 — see AR-03-04 | closed |

*Status: open · closed · open — below high threshold (non-blocking)*
*Severity: critical > high > medium > low — only open threats at or above workflow.security_block_on count toward threats_open*
*Disposition: mitigate (implementation required) · accept (documented risk) · transfer (third-party)*

---

## Accepted Risks Log

| Risk ID | Threat Ref | Rationale | Accepted By | Date |
|---------|------------|-----------|-------------|------|
| AR-03-01 | T-03-06 | Purge log line carries job UUIDs and a count only; no VA record content or user email; same sink as existing orphan-cleanup log | planner (03-01-PLAN) | 2026-09-13 |
| AR-03-02 | T-03-09 | Retention notice is static copy with no job data or identifiers, shown only to authenticated users | planner (03-02-PLAN) | 2026-09-13 |
| AR-03-03 | T-03-10 | Notice is a module constant rendered as a JSX text child; React escapes it; no user input path | planner (03-02-PLAN) | 2026-09-13 |
| AR-03-04 | T-03-15 | Admin JWT is short-lived, dev-scoped, used for two read-only requests, never persisted; verified absent from phase docs | planner (03-03-PLAN) | 2026-09-13 |

*Accepted risks do not resurface in future audit runs.*

---

## Security Audit Trail

| Audit Date | Threats Total | Closed | Open | Run By |
|------------|---------------|--------|------|--------|
| 2026-09-13 | 16 | 16 | 0 | /gsd-secure-phase (L1 grep-depth; plan-authored register, short-circuit rule) |

---

## Sign-Off

- [x] All threats have a disposition (mitigate / accept / transfer)
- [x] Accepted risks documented in Accepted Risks Log
- [x] `threats_open: 0` confirmed
- [x] `status: verified` set in frontmatter

**Approval:** verified 2026-09-13
