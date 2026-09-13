---
phase: 03-data-retention-policy
plan: 02
subsystem: frontend+docs
tags: [react, r, data-retention, tdd, documentation]

# Dependency graph
requires:
  - phase: 03-data-retention-policy
    provides: "03-01: backend/db/retention.R's RETENTION_DAYS=90 and the purge mechanism this plan documents and quotes from"
provides:
  - "A one-sentence user-facing retention notice (RETENTION_NOTICE) rendered in JobList.jsx's job-listing path"
  - "A machine-checked guarantee (tests/test_retention.R section 4) that the notice's integer, README.md's integer, and RETENTION_DAYS never silently diverge"
  - "README.md and backend/README.md '## Data retention' sections documenting the policy"
  - "backend/migrations/003_input_file_storage.sql's cascade comment now points at the purge instead of recording its absence"
affects: ["03-03"]

# Actuals (#2632)
actuals:
  tokens: 2023
  tasks: 2
  commits: 3
  plan_head_before: f81cf1f809ae9dcf94a046658ad2b97455178dcb

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "Dependency-free source-assertion test extended to a second file type (JSX, README) using the same dual-path-probe + comment-stripped idiom already established in this suite -- regex integer extraction (regmatches/gregexpr) plus numeric comparison against the single source constant, rather than re-stating the number in the test"
    - "Module-level static copy constant beside an existing one (RETENTION_NOTICE beside JOBS_PER_PAGE), rendered as a plain JSX text child -- no props/i18n layer, matches the file's existing convention for static strings"

key-files:
  created: []
  modified:
    - tests/test_retention.R
    - frontend/src/components/JobList.jsx
    - README.md
    - backend/README.md
    - backend/migrations/003_input_file_storage.sql

key-decisions:
  - "The retention number reaches the frontend as a guarded literal (RETENTION_NOTICE), not through a new /health field -- per the plan's resolution of D-09's open choice, avoiding a new API field, a fetch, async state and a loading case for one static word"
  - "backend/README.md's Data retention section states no integer at all, unlike README.md's -- pointing only at RETENTION_DAYS in backend/db/retention.R so there is no fourth copy of the number to drift"
  - "Chrome E2E verification (generally required for new user-facing features per .claude/skills/test/SKILL.md) was not run for this change: the plan's own <verification> block enumerates 7 checks, none of which is a Chrome E2E test, and the change is static text with no interactive behavior -- covered instead by the dependency-free R assertion tying it to RETENTION_DAYS, the full frontend vitest suite (confirms the JSX change did not break existing component tests), and the production build"

requirements-completed: ["#114", "D-01", "D-09", "D-10"]

coverage:
  - id: D1
    description: "A user looking at their jobs reads one static sentence saying jobs and uploads are deleted automatically 90 days after completion and that results worth keeping must be downloaded -- no per-job expiry date, no banner, no modal -- and CI fails if that sentence, README.md's Data retention section, and RETENTION_DAYS ever disagree"
    requirement: "#114"
    verification:
      - kind: unit
        ref: "Rscript tests/test_retention.R (section 4, 8 assertions)"
        status: pass
      - kind: unit
        ref: "cd frontend && npx vitest run --exclude '**/api/integration.test.js' (365 tests)"
        status: pass
    human_judgment: false
  - id: D2
    description: "The repository documents the policy where a reader looks for it: README.md and backend/README.md each carry a Data retention section, and the migration comment that used to record the absence of an expiry policy now points at purge_expired_jobs() and RETENTION_DAYS"
    requirement: "D-10"
    verification:
      - kind: other
        ref: "grep -q '^## Data retention' README.md backend/README.md && grep -q purge_expired_jobs backend/migrations/003_input_file_storage.sql (NOTE-REPLACED / STALE-NOTE-GONE)"
        status: pass
    human_judgment: false

# Metrics
duration: 8min
completed: 2026-09-13
status: complete
---

# Phase 3 Plan 2: Data retention — telling users and the repository Summary

**One `RETENTION_NOTICE` constant rendered after `<h3>Recent Jobs</h3>` in `JobList.jsx`, a `## Data retention` section in both READMEs, and the migration's stale "no automatic expiry" comment replaced with a pointer to `purge_expired_jobs()` — all three numeric statements held equal to `RETENTION_DAYS` by a dependency-free R assertion written RED first.**

## Performance

- **Duration:** 8 min
- **Started:** 2026-09-13T05:28:00Z (approx, from first commit timestamp)
- **Completed:** 2026-09-13T05:31:13Z
- **Tasks:** 2 completed
- **Files modified:** 5 (0 created, 5 modified)

## Accomplishments

- `tests/test_retention.R` section 4 ("the window users are told matches the window enforced"): 8 new dependency-free assertions reading `JobList.jsx` and `README.md` as text, verified RED (exit 1, section-4's 8/8 assertions failing on the actual target assertions — "returned FALSE", not a crash or syntax error — while sections 1-3's 32 pre-existing assertions stayed green) before either file was touched.
- `frontend/src/components/JobList.jsx`: `RETENTION_NOTICE` module constant beside `JOBS_PER_PAGE` —

  > Jobs and their uploaded files are deleted automatically 90 days after completion — download any results you need to keep.

  — rendered once, immediately after `<h3>Recent Jobs</h3>`, in the job-listing path (not only the empty state).
- `README.md`: new `## Data retention` section before `## API Endpoints`, stating the 90-day window (measured from completion, or creation for a job that never completed), the cascade delete, the no-manual-step automatic purge, and a pointer to `RETENTION_DAYS` in `backend/db/retention.R`.
- `backend/README.md`: new `## Data retention` section between Output Files and Job Types — deliberately states no integer, pointing only at `RETENTION_DAYS` so there is no fourth copy of the number.
- `backend/migrations/003_input_file_storage.sql`: the block comment above `job_input_files` that used to record "there is no automatic RETENTION/EXPIRY of stored uploads" now points at `purge_expired_jobs()` and `RETENTION_DAYS`, crediting issue #114. Only comment lines changed; the DDL, index, and cascade sentence are byte-identical.
- `Rscript tests/test_retention.R`: 40/40 passing after GREEN (32 pre-existing + 8 new).

## Task Commits

Each task was committed atomically (Task 1 is `type="tracer" tdd="true"`, producing the full RED→GREEN cycle):

1. **Task 1 — RED: failing retention-notice/README tests** - `c8c1f75` (test)
2. **Task 1 — GREEN: notice + README section** - `b55fd7d` (feat)
3. **Task 2: backend docs + migration comment** - `d819524` (docs)

**Plan metadata:** committed alongside this SUMMARY.

_Note: no REFACTOR commit — the GREEN implementation (one constant, one rendered paragraph, one README section) needed no cleanup._

## Files Created/Modified

- `tests/test_retention.R` — section 4, 8 new assertions tying `JobList.jsx`'s notice and `README.md`'s section to `RETENTION_DAYS`
- `frontend/src/components/JobList.jsx` — `RETENTION_NOTICE` constant + rendered paragraph (new)
- `README.md` — `## Data retention` section (new)
- `backend/README.md` — `## Data retention` section (new, no integer stated)
- `backend/migrations/003_input_file_storage.sql` — comment replaced (no DDL change)

## Decisions Made

- The retention number reaches the frontend as a guarded literal, never through a new `/health` field — per the plan's own resolution of D-09's open choice (CLAUDE.md's simplest-code rule: a fetch, async state, and a loading case would add real surface for no behavioral gain over a module constant whose agreement with the backend is already machine-checked).
- `backend/README.md`'s section states no integer at all (unlike `README.md`'s), so there remain exactly three statements of the window — the backend constant and the two asserted-against-it copies — never four.
- Chrome E2E was consciously not run for this change (see frontmatter `key-decisions` for the full rationale): the plan's own 7-item `<verification>` list does not call for it, and the change is static text with no interactive behavior, already covered by the full vitest suite plus the dependency-free source assertion.

## Deviations from Plan

### Auto-fixed Issues

None required — the implementation matched the plan's behavior spec on the first GREEN attempt.

### Noted, Not Fixed (Scope Boundary)

**1. [Out of scope] Pre-existing `npm run lint` failures unrelated to this task**
- **Found during:** Task 1, running the plan's `<verify>` command `cd frontend && npm run lint && npm run build`
- **Issue:** 4 ESLint errors in `frontend/src/auth/AuthContext.jsx` (`react-hooks/set-state-in-effect`, `react-refresh/only-export-components`) and `frontend/src/api/integration.test.js` (`no-undef` on `process`). None of these files were touched by this plan.
- **Verification that it predates this plan:** confirmed via `git stash` + `npx eslint .` against commit `f81cf1f` (the end of plan 03-01, before any 03-02 commit) — identical 4 errors, same files. Last touched by unrelated commit `05047ec` ("chore(test): add PR test CI + env-configurable backend port").
- **Scope boundary applied:** `frontend/src/components/JobList.jsx` (the only frontend file this task modified) lints clean in isolation (`npx eslint src/components/JobList.jsx` exits 0), and `npm run build` succeeds. Per the deviation rules' scope boundary, pre-existing failures in unrelated files are out of scope for auto-fix.
- **Logged to:** `.planning/phases/03-data-retention-policy/deferred-items.md` and `.planning/WINDOWS.md` (kind: `lint-warning`, status: `open`).

---

**Total deviations:** 0 auto-fixed. 1 pre-existing out-of-scope issue noted and logged (not fixed). **Impact on plan:** None — the task's own changes are lint-clean and build-clean; the noted issue is unrelated technical debt that predates this phase.

## Issues Encountered

None beyond the pre-existing lint issue documented above.

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- ROADMAP criterion 1 (the documented half of data retention) is now complete: the window is stated in the UI, in `README.md`, in `backend/README.md`, and in the migration comment that defines the cascade it relies on — and the two user-visible copies are machine-checked against the one backend constant.
- D-09 and D-10 are both satisfied and pinned by `tests/test_retention.R`'s section 4.
- No schema change, no new API field, no new CSS file — confirmed by `NOTICE-SCOPE-OK` and `SQL-COMMENT-ONLY`.
- Ready for 03-03 (post-deploy verification on dev, D-12), which depends on both 03-01's purge mechanism and 03-02's documentation/notice being in place — which they now are.
- No blockers.

---
*Phase: 03-data-retention-policy*
*Completed: 2026-09-13*

## Self-Check: PASSED

All modified files confirmed present on disk (`tests/test_retention.R`, `frontend/src/components/JobList.jsx`,
`README.md`, `backend/README.md`, `backend/migrations/003_input_file_storage.sql`, this SUMMARY). All 3 commits
(`c8c1f75`, `b55fd7d`, `d819524`) confirmed present in `git log`. All task `<acceptance_criteria>` and the
plan-level `<verification>` re-run and passing:
- `Rscript tests/test_retention.R`: 40/40 (exit 0)
- `cd frontend && npx vitest run --exclude '**/api/integration.test.js'`: 365/365 (exit 0)
- `cd frontend && npm run build`: succeeds
- `NOTICE-PLACED`, `NOTICE-SCOPE-OK`, `DOCS-OK`, `STALE-NOTE-GONE`, `SQL-COMMENT-ONLY`, `TDD-ORDER-OK`: all printed
- `npm run lint`: fails on 4 pre-existing, unrelated errors (documented above as out of scope, not a regression from this plan)
