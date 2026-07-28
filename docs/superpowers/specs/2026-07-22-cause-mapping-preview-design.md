# Pre-submit cause-mapping preview

Date: 2026-07-22
Status: Approved (design)

## Problem

Uploading the vacalibration package's own bundled datasets failed only *after*
job submission, with errors buried in the job log (e.g. EAVA neonate's 250
"Unspecified" records tripping the `assert_all_causes_mapped` guard). Users had
no way to see, before running, how their causes map to broad categories, which
records will be excluded, or the true calibrated denominator. The frontend only
showed a static, hardcoded `SUPPORTED_CAUSES` list (a duplicate of the backend
broad-cause list) and never inspected the uploaded file.

## Goal

Show the user, before they submit, exactly how their uploaded causes will be
handled: each cause → its broad category, which records are excluded (and why),
which causes are unrecognized (with spelling suggestions), and the number of
records that will actually be calibrated. Block submission on genuine errors;
warn but allow on expected exclusions.

## Principle

The frontend never maps causes itself. It asks the backend, which uses the SAME
R helpers the real calibration job uses. Single source of truth — no fourth copy
of the cause taxonomy.

## Backend

### Helper: `preview_cause_mapping(input_data, age_group)` (`backend/jobs/utils.R`)

Reuses existing units — `drop_undetermined_causes`, `is_broad_format`,
`build_broad_matrix` / `safe_cause_map`, and `suggest_closest`. Runs the mapping
only (no MCMC, no DB). Returns a list:

- `total_records` — integer, rows in the uploaded file
- `calibrated_denominator` — integer, records that map to a broad cause
- `excluded_undetermined` — list of `{cause, count}` (the "Unspecified"-type drops)
- `unrecognized` — list of `{cause, count, suggestion}` (causes mapping to nothing;
  `suggestion` is the closest broad cause via `suggest_closest`, or null)
- `mapping` — list of `{input_cause, broad_cause, count}` for recognized causes
- `has_errors` — boolean, `length(unrecognized) > 0`

"Unrecognized" = a cause that is neither an undetermined label nor maps to any
broad category (i.e. would be dropped by `assert_all_causes_mapped` for a reason
other than being undetermined).

### Endpoint: `POST /jobs/preview` (`backend/plumber.R`)

- Same auth as `POST /jobs`. CSV files are multipart (one per algorithm), but
  `age_group` — like every scalar `POST /jobs` takes — MUST be sent as a
  QUERY-STRING parameter, e.g. `POST /jobs/preview?age_group=child`. A multipart
  text field does NOT work: plumber gives a text part no Content-Type, so it is
  parsed with `parseQS`, and a bare value like `child` (no `=`) becomes an empty
  list. `age_group` is required and is never defaulted (issue #105).
- Applies the same `cause1`→`cause` rename and `ID`/`cause` column check as the
  job path; on a bad file, returns a structured error (not a 500).
- Runs `preview_cause_mapping` per file. Returns JSON: `{ reports: { <algo>: <report> } }`.
- Creates NO job row, writes NO DB record, runs NO MCMC.

## Frontend (`JobForm.jsx`, `api/client.js`)

- `api/client.js`: add `previewMapping(files, ageGroup)` calling `POST /jobs/preview`.
- On file attach (automatically, per algorithm), call `previewMapping` and render
  a preview panel per algorithm:
  - Headline: e.g. "940 of 1190 records will be calibrated; 250 'Unspecified' excluded."
  - Table: `Your cause | Maps to | Records`.
  - Unrecognized causes: red row with suggestion ("did you mean 'pneumonia'?");
    their presence **disables Submit**.
  - Undetermined exclusions: amber note; Submit stays enabled.
- The dynamic preview replaces the static supported-cause hint once a file is
  chosen. (Optional cleanup: endpoint returns the supported-cause list so the
  hardcoded `SUPPORTED_CAUSES` duplicate can be deleted — deferred unless trivial.)

## Anti-drift guarantee

`run_vacalibration`'s mapping hot path is left untouched (now covered by the
golden-dataset contract test). Instead, a test asserts `preview_cause_mapping`
produces the SAME broad matrix as the job path for every bundled dataset — DRY-
equivalent safety without rewriting the calibration path before handover.

## Testing

- Backend (`tests/test_vacalibration_backend.R`):
  - `preview_cause_mapping` report correctness on golden data: excluded counts,
    denominator, empty `unrecognized`.
  - A deliberately-misspelled cause (e.g. "Pnemonia") appears in `unrecognized`
    with a non-null suggestion and sets `has_errors = TRUE`.
  - Consistency: `preview_cause_mapping` broad matrix == job-path broad matrix
    for each `{age_group, algorithm}` bundled dataset.
- Frontend (vitest): preview panel renders from a mocked report; Submit disabled
  when `has_errors`; amber warning (Submit enabled) when only `excluded_undetermined`.

## Out of scope

- No client-side cause mapping.
- No change to the calibration algorithm or result shape.
- No refactor of `run_vacalibration`'s mapping path.
