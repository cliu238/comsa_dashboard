---
phase: 03-data-retention-policy
plan: 03
subsystem: infra
tags: [retention, deploy, k8s, github-actions, verification, issue-114]

requires:
  - phase: 03-data-retention-policy
    provides: "03-01 purge (backend/db/retention.R) and 03-02 notice + docs, both committed on master"
provides:
  - "The retention purge is live on dev (PR #135, squash commit cee5289, deploy run 34770420040 all green)"
  - "Deployed proof that nothing older than the 90-day window survives: 41 jobs remain, oldest 2026-06-16, cutoff 2026-06-15"
  - "Issue #114 closed with the agreed policy quoted verbatim and the first-run evidence"
affects: [verify-work, phase-3-uat]

actuals:
  tokens: 2000
  tasks: 3
  commits: 1

tech-stack:
  added: []
  patterns:
    - "Post-deploy acceptance via GET /admin/jobs with an admin session token; scalars in that response are R-boxed one-element arrays and must be unwrapped before comparing"

key-files:
  created:
    - .planning/phases/03-data-retention-policy/03-03-SUMMARY.md
  modified: []

key-decisions:
  - "User selected `proceed` at the blocking-human gate (no token supplied at that point, so the pre-deploy baseline was recorded as unavailable)"
  - "Landed via the repo's PR convention (PR #135, squash) after the user's explicit `proceed` — the plan text said the agent could not push; the user's decision authorised it"
  - "Task 3's retention assertion was re-run with the API's array boxing unwrapped; the plan's literal command mis-parsed `oldest_day` and never printed the sentinel — a verification-command defect, not a purge defect"

patterns-established:
  - "Deployed evidence, never inferred: per-job run conclusions, the manifest step, /health, and a real admin query with a printed cutoff and oldest timestamp"

requirements-completed: ["#114", "D-04", "D-10", "D-12"]

coverage:
  - id: D1
    description: "Phase commits landed on master and the image rebuilt with `later` explicit; deploy run 34770420040 green in every job including build-and-push; package-manifest verification step success on the first build"
    verification:
      - kind: other
        ref: "gh run view 34770420040 --json jobs --jq '.jobs[] | {name, conclusion}'"
        status: pass
      - kind: other
        ref: "gh run view 34770420040 --json jobs --jq '.jobs[].steps[] | select(.name | test(\"package manifest\")) | {name, conclusion}'"
        status: pass
    human_judgment: false
  - id: D2
    description: "The deployed backend deleted every job past the 90-day window on its own: GET /admin/jobs shows 41 jobs, oldest 2026-06-16 11:26:30, none earlier than the 2026-06-15 cutoff (RETENTION-HOLDS)"
    verification:
      - kind: integration
        ref: "curl -H 'Authorization: Bearer <admin jwt>' https://dev.sites.idies.jhu.edu/comsa-dashboard/api/admin/jobs | jq (unboxed COALESCE(completed_at, created_at) min vs cutoff)"
        status: pass
      - kind: other
        ref: "curl -sS -o /dev/null -w '%{http_code}' https://dev.sites.idies.jhu.edu/comsa-dashboard/api/health -> 200"
        status: pass
    human_judgment: false
  - id: D3
    description: "Issue #114 closed (COMPLETED) with a comment quoting the README policy, naming RETENTION_DAYS in backend/db/retention.R, and noting the 194 retired issue-#118 results"
    verification:
      - kind: other
        ref: "gh issue view 114 --json state,stateReason -> CLOSED / COMPLETED; https://github.com/cliu238/comsa_dashboard/issues/114#issuecomment-5655110654"
        status: pass
    human_judgment: false
  - id: D4
    description: "The one-line retention notice is visible above the job table on dev, and the job list is short with no job created before 2026-06-15"
    verification: []
    human_judgment: true
    rationale: "Rendering in the deployed UI needs human eyes; the API inventory (D2) covers the data half"
  - id: D5
    description: "A job submitted after the deploy completes, one of its result files downloads, and rerun works"
    verification: []
    human_judgment: true
    rationale: "End-to-end job flow on dev needs a logged-in human session and a real MCMC run; not yet confirmed by the user at close-out"

duration: ~1h 40m (wall clock incl. build and waiting on the human gate)
completed: 2026-09-13
status: complete
---

# Phase 3 Plan 03: Land it and prove it Summary

**The 90-day retention purge is live on dev and has already deleted every expired job: 41 remain, oldest 2026-06-16, none past the 2026-06-15 cutoff; issue #114 is closed with the policy quoted.**

## Performance

- **Duration:** ~1h 40m wall clock (decision gate wait, ~9 min image build and deploy, verification)
- **Started:** 2026-09-13T05:35Z (checkpoint presented)
- **Completed:** 2026-09-13T17:20Z
- **Tasks:** 3
- **Files modified:** 0 source files (evidence-only plan)

## Accomplishments
- User authorised the irreversible first-run purge (`proceed`) with the real predicate and blast radius in front of them.
- Phase commits landed on master via PR #135 (squash commit `cee5289`); deploy run 34770420040: `check-changes`, `build-and-push`, `deploy` all `success`; "Verify backend package manifest" step `success` on the first build; `/api/health` 200.
- Deployed proof of deletion: post-deploy inventory 41 jobs (28 completed, 13 failed), oldest `2026-06-16 11:26:30`, newest `2026-09-13 03:41:02`, zero jobs older than the cutoff; `RETENTION-HOLDS`.
- Issue #114 closed as completed with the README policy quoted verbatim, `RETENTION_DAYS` in `backend/db/retention.R` named, plan links, and the accepted retirement of the 194 issue-#118 results.

## Task Commits

No source commits — this plan produces evidence only.

**Plan metadata:** see the `docs(03-03)` commit that adds this SUMMARY.

## Evidence record (D-04 audit)

| Item | Value |
|---|---|
| Task 1 selection | `proceed` (no token at that time) |
| Pre-deploy baseline | **unavailable** — no admin session before the deploy (Chrome extension not connected in this session; user supplied the token only after rollout). Last measured inventory: ~240 jobs on 2026-08-12 (#118). |
| PR / merge | #135, squash commit `cee5289` |
| Deploy run | 34770420040 — check-changes success, build-and-push success, deploy success |
| Manifest step | "Verify backend package manifest (issue #123)": success |
| Health | 200 |
| Post-deploy inventory | 41 jobs; oldest `2026-06-16 11:26:30`; newest `2026-09-13 03:41:02`; cutoff `2026-06-15`; older_than_cutoff=0 |
| Count delta | ~240 → 41 (≈200 removed; exact delta unknowable without the baseline) |
| Timestamp serialisation | `created_at` / `completed_at` arrive as **one-element JSON arrays of naive strings**, e.g. `["2026-06-16 11:26:30"]` — no timezone, second precision, R/plumber boxing |
| Purge log line | **not retrieved** — kubectl is reachable only through the `deploy.yml` SSH path, which does not print pod logs; the API inventory is the primary evidence |
| Issue #114 | CLOSED (COMPLETED) — https://github.com/cliu238/comsa_dashboard/issues/114#issuecomment-5655110654 |
| Fresh job on dev | **pending user confirmation** (human-check, harvested into phase UAT) |

## Decisions Made
- Landed the change myself via the repo's PR convention once the user replied `proceed`; the plan's Task 2 assumed the agent could not push, but the user's decision was explicitly "push and deploy".
- Closed #114 on the strength of the deployed API proof rather than waiting for the fresh-job UI confirmation; that confirmation stays a human-check item for UAT.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Task 3 verify command mis-parsed the boxed timestamps**
- **Found during:** Task 3 (retention assertion)
- **Issue:** the plan's `jq -r '… | min' | cut -c1-10` operated on one-element arrays, producing `oldest_day=[\n  "2026-06` and never printing `RETENTION-HOLDS`, even though the data satisfied the assertion.
- **Fix:** re-ran the same assertion with each scalar unwrapped (`if type=="array" then .[0] else . end`); `RETENTION-HOLDS` printed and an explicit count of jobs older than the cutoff returned 0.
- **Files modified:** none (command-line only)
- **Verification:** `post_total=41 oldest=2026-06-16 11:26:30 … cutoff=2026-06-15 oldest_day=2026-06-16 RETENTION-HOLDS`

---

**Total deviations:** 1 auto-fixed (1 bug in a verification command).
**Impact on plan:** none on the shipped behaviour; the real timestamp format is now recorded for future plans.

## Issues Encountered
- Pre-deploy baseline could not be captured (see evidence table). Recorded as unavailable per the plan, not omitted.
- Purge log line unretrievable from this machine (see evidence table).
- `gh issue close` does not accept `--comment-file`; retried with `--comment "$(cat …)"`.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 3 code and docs are on master and deployed; remaining human checks (notice visible, fresh job completes/downloads/reruns) are UAT items.
- Deferred ideas (user delete, admin purge button, per-job expiry column) remain in 03-CONTEXT.md.

## Self-Check: PASSED

---
*Phase: 03-data-retention-policy*
*Completed: 2026-09-13*
