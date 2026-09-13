---
status: testing
phase: 03-data-retention-policy
source: [03-VERIFICATION.md]
started: 2026-09-13T18:17:23Z
updated: 2026-09-13T18:17:23Z
---

## Current Test

number: 1
name: Retention notice visible on dev
expected: |
  Logged into https://dev.sites.idies.jhu.edu/comsa-dashboard/ , the job list shows a one-line
  notice above the "Recent Jobs" table: "Jobs and their uploaded files are deleted automatically
  90 days after completion — download any results you need to keep." The list is short and shows
  no job created before 2026-06-15.
awaiting: user response

## Tests

### 1. Retention notice visible on dev
expected: One-line retention notice renders above the job table on dev; job list shows no job created before the 2026-06-15 cutoff.
result: [pending]

### 2. Fresh job works end-to-end on dev after the purge deploy
expected: A job submitted after the deploy (a demo run is fine) completes, one of its result files downloads, and rerun works.
result: [pending]

## Summary

total: 2
passed: 0
issues: 0
pending: 2
skipped: 0
blocked: 0

## Gaps
