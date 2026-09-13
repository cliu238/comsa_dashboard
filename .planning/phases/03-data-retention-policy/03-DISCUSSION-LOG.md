# Phase 3: Data retention policy - Discussion Log

> **Audit trail only.** Do not use as input to planning, research, or execution agents.
> Decisions are captured in CONTEXT.md — this log preserves the alternatives considered.

**Date:** 2026-09-13
**Phase:** 03-data-retention-policy
**Areas discussed:** Retention window, First-run handling of historical jobs, Telling users

Before asking anything, the codebase, issue #114, PR #113 and the codebase maps
were read. Conclusions that were forced by constraints were stated to the user as
decisions with a veto, not asked: in-process purge (no CronJob / pg_cron), whole-job
cascade deletion (no tiering), no demo exemption (flag not in DB), age from
`COALESCE(completed_at, created_at)`, user/admin delete actions deferred, one
constant for the window. The user did not veto any of them.

---

## Retention window

| Option | Description | Selected |
|--------|-------------|----------|
| 90 days | About a quarter; researchers can revisit and rerun (the #104 reporter came back weeks later) while identifying data does not accumulate | ✓ |
| 30 days | Closer to data minimisation, but a short window for researchers to return to old results | |
| 180 days | Half a year; barely affects anyone but the policy is weak on identifying data | |
| Other | Fill in a number if a COMSA data-use agreement or IRB requires one | |

**User's choice:** 90 days
**Notes:** No regulatory constraint was raised.

---

## First-run handling of historical jobs

| Option | Description | Selected |
|--------|-------------|----------|
| Enable immediately, purge on first start | Uniform policy, simplest code; the purge logs deleted ids and count; user can warn testers to download first | ✓ |
| Log-only first, then enable | First deploy only lists what would be deleted; a one-line change enables deletion after review | |
| Grandfather pre-policy jobs | Policy applies only to jobs created after launch; needs a cutoff constant and leaves the historical accumulation unsolved | |

**User's choice:** Enable immediately, purge on first start
**Notes:** Roughly 240 jobs stored since January 2026 will be deleted on the first start, including the 194 pre-stall-flag results from #118.

---

## Telling users

| Option | Description | Selected |
|--------|-------------|----------|
| One-line UI notice + repo docs | Static sentence near the job list / upload form, plus README and the #114 closing comment | ✓ |
| Repo docs only | README and issue only; users discover the policy when results vanish | |
| Per-job expiry date | An "expires on" column; clearest but the largest UI change in the phase | |

**User's choice:** One-line UI notice + repo docs

---

## Claude's Discretion

- Exact SQL, helper names and placement (next to `cleanup_orphaned_jobs()`).
- 24-hour tick implementation (`later::later` re-arming vs. plumber hook).
- Whether the number reaches the frontend via `/health` or a test-guarded string.
- Notice wording and placement; README section wording.
- Optional orphan-directory sweep.

## Deferred Ideas

- User "delete my job" endpoint and button.
- Admin manual purge action.
- Per-job expiry column.
- Dry-run mode or per-environment window configuration.
- Demo-job exemption (would need the flag persisted in `jobs`).
- Bounding `GET /jobs` per-job fan-out cost.
