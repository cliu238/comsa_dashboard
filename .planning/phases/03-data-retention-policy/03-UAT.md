---
status: complete
phase: 03-data-retention-policy
source: [03-VERIFICATION.md]
started: 2026-09-13T18:17:23Z
updated: 2026-09-14T01:45:41Z
---

## Current Test

[testing complete]

## Tests

### 1. Retention notice visible on dev
expected: One-line retention notice renders above the job table on dev; job list shows no job created before the 2026-06-15 cutoff.
result: pass

### 2. Fresh job works end-to-end on dev after the purge deploy
expected: A job submitted after the deploy (a demo run is fine) completes, one of its result files downloads, and rerun works.
result: pass
evidence: |
  Driven via Chrome on dev (2026-09-13 21:40-21:45 EDT, admin login).
  Demo job c8da56ea completed in 11s; GET /download/calibration_summary.csv -> 200 text/csv 539 B.
  Uploaded job 15a7a6a3 (sample_interva_neonate.csv, 1190 records) completed in 11s;
  GET /download/calibration_summary.csv -> 200 text/csv 540 B;
  POST /jobs/15a7a6a3/rerun -> new job 31d80e1f, completed in 12s.
note: |
  Rerun of a *demo* job returns "Original input file not found" because demo jobs use
  built-in sample data and store no input_file. Pre-existing since f4737f9 (2026-01-15),
  not a phase 3 regression; there is also no Rerun button in the UI (API-only endpoint).

## Summary

total: 2
passed: 2
issues: 0
pending: 0
skipped: 0
blocked: 0

## Gaps
