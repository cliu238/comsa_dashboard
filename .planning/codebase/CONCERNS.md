# Codebase Concerns

**Analysis Date:** 2026-08-18

## Tech Debt

**Unpinned R package supply chain (OPEN issue #123):**
- Issue: `backend/Dockerfile` installs every R package unpinned from CRAN at three sites (`:35` plumber/jsonlite/uuid/future/RPostgres/pool/jose, `:38` rJava, `:43` openVA/EAVA/vacalibration/knitr), all via `repos='https://cloud.r-project.org'`, which always resolves to the newest release. `FROM rocker/r-ver:4.4` (`backend/Dockerfile:3`) is also a floating minor tag, not a pinned patch/digest.
- Files: `backend/Dockerfile`
- Impact: image contents depend on the build date — two builds of the same commit can differ. This already caused a real 2-day outage: `RcppParallel` (transitive dep of openVA/EAVA) started requiring `cmake` in a CRAN release published between 2026-07-28 and 2026-08-12; no repo code changed, but the next backend deploy failed. Because 16 days passed with no deploy, the failure surfaced on an unrelated PR (#115, R-only changes) and was initially misattributed to that PR — diagnosing it required proving the failing Dockerfile layer runs before `COPY`, so no source change could have caused it. The frontend has `frontend/package-lock.json`; the backend has no equivalent lockfile (no `renv.lock` present).
- Fix approach: pin to a dated CRAN snapshot (e.g. Posit Package Manager, `packagemanager.posit.co/cran/__linux__/<distro>/<date>`) at all three `install.packages()` call sites, and pin `rocker/r-ver` to a specific patch version or digest. `renv` is a heavier alternative (lockfile + activation + image cache handling).

**Duplicated result-assembly logic between the two job paths:**
- Issue: `run_vacalibration()` (`backend/jobs/algorithms/vacalibration.R:206-296`) and `run_pipeline()` (`backend/jobs/processor.R:189-270`) contain a near-verbatim ~70-line block: selecting the `primary` row from `pcalib_postsumm`/`p_uncalib`, extracting `uncalibrated`/`calibrated`/`calibrated_low`/`calibrated_high`, calling `build_per_algorithm()`, `build_stall_fields()`, `extract_misclass_matrix()`, `build_summary_df()`, writing `calibration_summary.csv` and the misclassification-matrix CSVs, and assembling `result_obj`. The only differences are the local variable name (`result` vs `calib_result`) and how `algo_names`/`algorithms` are derived.
- Files: `backend/jobs/algorithms/vacalibration.R:206-296`, `backend/jobs/processor.R:189-270`
- Impact: fixes have to be applied twice. Issue #101's fix (PR #115) explicitly had to touch "both job paths" — the PR description calls this out directly because the stall-detection/lambda-mapping helpers (`build_lambda_map`, `path_correction_stalled`, `build_stall_fields` in `backend/jobs/utils.R:666-790`) were already centralized, but the surrounding orchestration code that calls them was not, so it is easy for a future fix to land in only one file and silently leave the other job type unpatched.
- Fix approach: extract the shared ~70-line block (primary-row selection through result_obj assembly, minus each caller's own `output_dir`/log-writing specifics) into one function in `backend/jobs/utils.R` that both `run_vacalibration()` and `run_pipeline()` call with `result`/`va_input` metadata as arguments.

**One-off debug scripts left in the repo:**
- Issue: `backend/scripts/debug_matrix.R`, `debug_matrix2.R`, `debug_matrix3.R`, `debug_matrix4.R` are four near-duplicate, undocumented, ad-hoc scripts (all dated the same day) written to inspect `Mmat_tomodel`/`Mmat.asDirich` while diagnosing the misclassification-matrix issues (#31, #90). None are referenced by any test, CI job, or `README`.
- Files: `backend/scripts/debug_matrix.R`, `backend/scripts/debug_matrix2.R`, `backend/scripts/debug_matrix3.R`, `backend/scripts/debug_matrix4.R`
- Impact: violates the project's own stated policy ("don't create unnecessary files... archive or delete the legacy file" — `CLAUDE.md`). Adds noise for anyone browsing `backend/scripts/` looking for the real utilities (`generate_sample_csvs.R`, `validate_samples.R`).
- Fix approach: delete all four, or consolidate any still-useful inspection logic into a single documented `scripts/inspect_calibration_result.R`.

**Stray one-off SQL script in the migrations directory:**
- Issue: `backend/migrations/test_insert.sql` is a manual test INSERT referencing one specific historical job UUID (`760e77d6-1224-4eaa-a84e-e13f380584f7.json`), sitting alongside the real numbered migrations (`001_initial_schema.sql`, `002_users.sql`, `003_input_file_storage.sql`).
- Files: `backend/migrations/test_insert.sql`
- Impact: not a real migration (no numeric prefix, not idempotent, references data that may not exist); risks confusing anyone who assumes everything in `migrations/` is meant to run in order against a fresh database.
- Fix approach: move it to `backend/scripts/` (clearly marked as a one-off manual verification script) or delete it.

**Hardcoded absolute path in a backend test script:**
- Issue: `backend/test_db_integration.R:7` calls `setwd("/Users/ericliu/projects5/comsa_dashboard/backend")`, a path specific to one developer's machine.
- Files: `backend/test_db_integration.R`
- Impact: the script fails for any other developer or in CI; it is excluded from `.github/workflows/test.yml` (only `tests/test_misclass_matrix.R`, `tests/test_auth_visibility.R`, `tests/test_input_persistence.R` run there), so this has gone unnoticed.
- Fix approach: use `here::here()` or derive the path from `Sys.getenv()`/`commandArgs()`, or move the script under `tests/` and align it with the other suites that already run relative to the repo root.

**`backend/jobs/utils.R` is a 1,229-line catch-all:**
- Issue: this single file mixes cause-name validation (`assert_all_causes_mapped`, `validate_causes`, `safe_cause_map` wrappers), path-correction/stall detection (`build_lambda_map`, `path_correction_stalled`, `build_stall_fields`), misclassification-matrix extraction (`extract_misclass_matrix`, `.build_misclass_entry`, `normalize_mmat`), per-algorithm CSMF assembly (`build_per_algorithm`), and job-visibility/access-control logic (`job_visibility`, `job_access_decision`) — five largely-unrelated concerns in one 1,229-line file, more than 4x the size of the next-largest job-logic file (`backend/plumber.R` at 858 lines).
- Files: `backend/jobs/utils.R`
- Impact: a change made for one concern (e.g. tightening stall detection) sits in the same file as, and is easy to conflate with, unrelated logic (e.g. `job_access_decision`, which gates who can read a job's data) — raising the odds a future edit to one silently touches the other's behavior without a corresponding test update.
- Fix approach: split into `jobs/cause_mapping.R`, `jobs/path_correction.R`, `jobs/misclass_matrix.R`, and move `job_visibility()`/`job_access_decision()` into `auth/` (already noted in `backend/auth/middleware.R` as living in `utils.R` "so it is testable without a JWT library" — that constraint can be satisfied by a smaller, separate file).

**Closed issues whose underlying gap is still present in code:**
- Issue: #3 ("Add job timeout mechanism") and #6 ("Add pagination to job list endpoint") were both closed with no comments and no corresponding code change. Grepping `backend/jobs/*.R` for `withTimeout`/`timeout` finds nothing, and `GET /jobs` (`backend/plumber.R:493-537`) has no `LIMIT`/`OFFSET`/page parameter anywhere in the query or handler.
- Files: `backend/jobs/processor.R`, `backend/jobs/algorithms/*.R`, `backend/plumber.R:493-537`
- Impact: the original problems these issues described are unresolved — see Known Bugs / Performance Bottlenecks below for the concrete consequences. Anyone consulting the issue tracker to check "has this been handled?" will get a false negative.
- Fix approach: either reopen with an explicit "not planned" rationale (matching how #118 was closed), or implement the fix and reference the issue in the commit.

## Known Bugs

**OPEN issue #101 — path correction can silently no-op ("same results for uncalibrated and calibrated"):**
- Symptoms: for a run where a broad cause has zero (or near-zero) deaths, `vacalibration`'s path-correction line search starts at lambda = 0.99 and steps down until the implied calibrated CSMF leaves `[0,1]`; when 0.99 is already infeasible (a CSMF of 0 sits on the simplex boundary) the search exits on its first iteration and returns 0.99, so `lambda*I + (1-lambda)*M` is ~99% identity — calibration does essentially nothing, and the reported credible intervals are inflated to look ~7x tighter than an uncalibrated run (because the mixed-in prior concentration is ~120x larger). A stalled run therefore looks *more* certain, not less.
- Files: root cause is inside the `vacalibration` R package itself (not this repo); the dashboard's own trigger is documented at `backend/jobs/utils.R:666-707` (`LAMBDA_CEILING`, `path_correction_stalled()`, `build_lambda_map()`, `stalled_algorithms()`).
- Trigger: the dashboard pads every upload to all 9 broad causes (matching `cause_map()`'s own behavior) rather than dropping zero-death causes before calibration — this is exactly what puts a cause on the simplex boundary and triggers the stall. Confirmed end-to-end on the issue's own reporter data (`sample_eava_1to59m.csv`): lambda = 0.99, stalled = TRUE; adding 50 deaths to each zero-count cause instead gives lambda = 0.37, not stalled.
- Workaround: none in the dashboard. PR #115 (merged) added detection and UI/export suppression of the false-precision intervals (see below) but does not change the underlying calibration outcome. The package author (`@sandy-pramanik`) is reportedly adding an `exclude_zero_causes` argument to `vacalibration` itself; whether to auto-exclude zero-death causes via `donotcalib` is called out in #115 as a modeling decision still open in #101, not yet implemented on either side.
- Downstream effects already fixed on the dashboard side (all closed, all reference #101): #116 (misclassification-matrix panel showed the ~99%-identity `Mmat_tomodel` captioned as real sensitivity — now needs the stall flag threaded into `MisclassificationMatrix.jsx`, tracked separately), #117 (`calibration_summary.csv` presented stalled-run CIs as ordinary bounds — fixed by #115's `build_summary_df` blanking bounds + recording lambda), #118 (194 historical stored results predate the flag — see Test Coverage Gaps below, closed as not-planned).

## Security Considerations

**Wildcard CORS on every endpoint:**
- RESOLVED 2026-08-25 (PR #128, closes #4): the wildcard is gone. `backend/cors.R` holds an exact-match origin allowlist defaulting to the local dev origins, overridable via `CORS_ALLOWED_ORIGINS` (a `*` entry is rejected loudly rather than silently no-ops). The filter echoes the request's own origin only when allowlisted, sets `Vary: Origin` unconditionally, and answers a disallowed preflight with 403. The deployed app was always same-origin — `k8s/ingress.yaml` puts the API under the frontend's host and `.env.production` uses a relative `VITE_API_BASE_URL` — so it needs no CORS header at all. Verified live: `https://evil.example.com` gets no `Access-Control-Allow-Origin` from `dev.sites.idies.jhu.edu`. Guarded by `tests/test_cors.R` (23 assertions) in CI.

  Original finding: `backend/plumber.R` set `Access-Control-Allow-Origin: *` for every route, in a filter running before the auth filter. With Bearer-token auth a wildcard alone did not let a foreign page silently attach a victim's token, but any origin could read the response to a request it CAN authenticate, and it removed origin-based defence-in-depth. Issue #4 had been closed with no corresponding change.
- Files: `backend/plumber.R:60-70`
- Current mitigation: JWT is required on all non-public endpoints as of `AUTH_GRACE_PERIOD` defaulting to `false` (`backend/auth/middleware.R:12`, fixed for issue #109).
- Recommendations: done in PR #128 — env-configurable exact-match allowlist. `/health`, `/auth/login` and `/auth/register` remain public and unauthenticated by design; they are now simply not readable cross-origin by an arbitrary site.

**No path sanitization on the file-download route parameter:**
- Risk: `GET /jobs/<job_id>/download/<filename>` (`backend/plumber.R:543-576`) builds `file_path <- file.path(output_dir, filename)` directly from the `filename` URL segment with no `basename()` or allowlist check — only the *error message* text calls `basename(filename)` for display (`:561`), the actual path used for `file.exists()`/`readBin()` does not. Plumber's default route-parameter matching does not include literal `/`, which limits (but does not by itself rule out) traversal via encoded segments; this has not been penetration-tested against the live deployment.
- Files: `backend/plumber.R:543-576`
- Current mitigation: `job_id` is separately validated via a `::uuid`-cast DB lookup (`load_job()`, `backend/db/connection.R:222`) and `check_job_access()` gates on ownership/role, so an attacker would need a `filename` payload that escapes `output_dir` while a request is otherwise authorized for some job. Other file-serving code in the same file (e.g. rerun's copy-in logic, `backend/plumber.R:747-796`) does apply `basename()` defensively.
- Recommendations: apply `basename(filename)` (or reject any value containing `/` or `..`) before constructing `file_path`, matching the pattern already used elsewhere in `plumber.R`.

**No upload size limit or rate limiting:**
- Risk: no `maxRequestSize`/body-size cap was found in `backend/plumber.R` or `backend/run.R`, and no rate-limiting middleware exists anywhere in `backend/`. Since issue #110's fix, every uploaded CSV is additionally mirrored as base64 in the `job_input_files` Postgres table (`backend/migrations/003_input_file_storage.sql`) so it survives pod restarts — an unbounded or repeated large upload now has a direct, unbounded path into the database, not just the ephemeral filesystem.
- Files: `backend/plumber.R`, `backend/run.R`, `backend/migrations/003_input_file_storage.sql`
- Current mitigation: none found.
- Recommendations: set an explicit request-size ceiling appropriate to expected VA CSV sizes, and consider basic per-user/per-IP rate limiting on `POST /jobs` given each job also spawns an MCMC `future` process.

**No data-retention/expiry policy for identifying health data (OPEN issue #114):**
- Risk: uploaded VA CSVs (potentially identifying) and job results accumulate indefinitely in `job_input_files`, `job_files`, and the `jobs.result` JSONB column, with no scheduled purge and no user-facing delete endpoint. Cascading `ON DELETE` is wired correctly at the schema level, but nothing ever triggers a delete.
- Files: schema referenced in `backend/migrations/001_initial_schema.sql`, `003_input_file_storage.sql`
- Current mitigation: access is restricted to the owning user/admin (post #109), so this is a data-minimization/compliance gap, not an active exposure.
- Recommendations: decide and implement a retention window (e.g. purge inputs N days after job completion), and/or a user- or admin-triggered delete endpoint (`DELETE FROM jobs` cascades correctly already).

## Performance Bottlenecks

**`GET /jobs` does an N+1×4 query/IO storm to return 4 fields per job:**
- Problem: `backend/plumber.R:493-537` calls `load_job(id)` once per visible job ID just to extract `job_id, type, status, created_at`. `load_job()` (`backend/db/connection.R:219-280`) performs, per job: (1) `SELECT * FROM jobs WHERE id = $1`, (2) `get_job_logs(job_id)` — an unbounded, un-`LIMIT`ed fetch of *every* log line ever written for that job (MCMC/vacalibration jobs can log thousands of `Iteration: X / Y` lines), (3) a `load_job_metadata()` disk read of `data/jobs/<id>/metadata.json`, and (4) a `get_job_files(job_id, "input")` query.
- Files: `backend/plumber.R:493-537`, `backend/db/connection.R:219-280`
- Cause: the list endpoint reuses the single-job loader rather than a lightweight summary query; nothing limits the log fetch inside it.
- Improvement path: add a `list_job_summaries()` that runs one `SELECT id, type, status, created_at FROM jobs WHERE ... ORDER BY created_at DESC LIMIT $n OFFSET $m` and never touches `get_job_logs`/`get_job_files`/metadata files. With 240+ completed jobs already on record as of #118 (and no pagination — see below), an admin's `/jobs` page can trigger 700-1,000+ round-trips.

**No pagination on `GET /jobs` (issue #6 closed without a fix):**
- Problem: `job_ids <- switch(job_visibility(req$user), all = list_job_ids(), own = ...)` (`backend/plumber.R:500-510`) has no `LIMIT`/`OFFSET`/page parameter; every visible job is loaded and returned every time.
- Files: `backend/plumber.R:493-537`
- Cause: never implemented despite the issue being closed as if resolved.
- Improvement path: add `?page=&limit=` query params and a `total` count in the response, as the original issue proposed; pairs naturally with the `list_job_summaries()` fix above.

**No job timeout mechanism (issue #3 closed without a fix):**
- Problem: nothing in `backend/jobs/processor.R` or `backend/jobs/algorithms/*.R` wraps job execution in a timeout. A hung InSilicoVA or MCMC run (the exact scenario #3 was filed for) still runs indefinitely, occupying a `future` worker slot (`backend/jobs/config.R:23-27` configures `multicore`/`multisession`, with no per-job cap).
- Files: `backend/jobs/processor.R`, `backend/jobs/config.R`
- Cause: never implemented despite the issue being closed as if resolved.
- Improvement path: wrap `run_with_capture()` calls with `R.utils::withTimeout()` (as the original issue suggested) and mark the job `failed` with a clear message on expiry.

## Fragile Areas

**Cross-language JSON boundary (R `NULL`/`NA` vs. JS `null`/undefined):**
- Files: `frontend/src/api/client.js` (`unbox()`), `frontend/src/components/CSMFChart.js`, `backend/db/connection.R` (`toJSON(result, auto_unbox = TRUE)`, no `na="null"`), `backend/jobs/utils.R:1056-1060`.
- Why fragile: `jsonlite::toJSON(..., auto_unbox = TRUE)` with the default `na` handling serializes R's `NULL` as `{}` and `NA` (e.g. `NA_real_`) as the *string* `"NA"`, not JSON `null`. `unbox()` (`frontend/src/api/client.js:5-25`) only special-cases empty objects (`{}` → `null`) and one-element primitive arrays (→ scalar); it does not special-case the string `"NA"`. `backend/jobs/utils.R:1056-1060` documents this explicitly and works around it for the misclassification matrix by *dropping* excluded-cause cells rather than emitting `NA` into them. `CSMFChart.js:38-41` documents the same hazard for `lambda_calibpath`/`path_correction_stalled` and deliberately uses `typeof src.lambda_calibpath === 'number'` / `=== true` instead of `??`, specifically because `"NA" ?? x` would return the string `"NA"` (a non-null value) rather than falling through — but the same file still uses `?? 0` / `?? null` for `uncalibrated`/`calibrated`/`ciLower`/`ciUpper` (`CSMFChart.js:52-55`), which would silently pass a literal `"NA"` string through as a CSMF value if `p_uncalib`/`pcalib_postsumm` ever produced an `NA` cell. That is not believed to happen today (CSMF proportions are not expected to be `NA`), but nothing enforces it, and no test in `CSMFChart.test.js` currently exercises an `"NA"`-valued `uncalibrated_csmf`/`calibrated_csmf` entry (only `lambda_calibpath: 'NA'` is tested, per `CSMFChart.test.js:164`).
- Safe modification: any new numeric field crossing this boundary must be read on the frontend with an explicit `typeof x === 'number'` (or equivalent) guard, never a bare `??`/truthy check, and the R side should prefer omitting a field entirely over emitting `NA` into it when the value is not meaningful (the pattern already used in `extract_misclass_matrix`).
- Test coverage: `frontend/src/api/client.test.js` covers `unbox()`'s array/object handling; `CSMFChart.test.js:164-165` covers the `"NA"` string specifically for `lambda_calibpath` only.

**Silent test skips contradict the project's own no-silent-skip policy:**
- Files: `frontend/e2e/demo-gallery.spec.js:6-13`, `frontend/e2e/file-upload.spec.js:6-13`
- Why fragile: both Playwright specs run `test.skip(true, 'Backend not running — skipping E2E tests')` inside a `beforeAll` when `GET http://localhost:8000/health` fails, rather than failing loudly or auto-starting the backend. This directly contradicts `CLAUDE.md`'s stated policy ("No silent test skips: Tests must never silently skip... auto-start it or fail loudly") and the explicit testing instruction to start the backend automatically rather than skip. A developer running `npm run test:e2e` without a backend up gets a green/skipped report, not a failure, and may believe the suite passed.
- Compounding factor: `.github/workflows/test.yml` never runs Playwright E2E, `frontend/src/api/integration.test.js`, or `tests/test_vacalibration_backend.R` at all (the comment at `test.yml:37-40` and `:50-57` states this is a deliberate, documented CI exclusion, not a silent one at the CI-config level — but combined with the specs' own internal skip, it means these suites, including the ~206-assertion R suite that would catch a regression in the #101/#115 stall-detection logic, have **no automated enforcement** and run only when a developer remembers to invoke them locally against a live backend).
- Safe modification: change both specs' `beforeAll` to attempt starting the backend (`Rscript run.R &`) when `/health` is unreachable, mirroring `frontend/src/api/integration.test.js`'s documented auto-start behavior, and fail (not skip) if it still cannot be reached after a timeout.

**Duplicated result-assembly across job paths (see Tech Debt above):**
- Files: `backend/jobs/algorithms/vacalibration.R:206-296`, `backend/jobs/processor.R:189-270`
- Why fragile: identical logic maintained in two places; historically, at least one fix (path-correction/#101 reporting) required deliberately visiting both files, called out explicitly in PR #115's description as "fiddly."
- Safe modification: any change to CSMF extraction, stall-field wiring, misclassification-matrix extraction, or summary-CSV generation must be applied to *both* files until they are unified; grep both files after any such change to confirm parity.

## Scaling Limits

**Job outputs remain on ephemeral pod storage (partial fix of issue #110):**
- Current capacity: `k8s/backend-deployment.yaml` declares no `volumes`/`volumeMounts`/PVC. Issue #110's fix (migration `003_input_file_storage.sql`, `backend/db/connection.R:356-420`) mirrors uploaded **inputs** into Postgres as base64 so they survive pod replacement, but job **outputs** (`calibration_summary.csv`, `misclass_matrix*.csv`, any generated PNGs) written under `data/outputs/<job_id>/` are not mirrored anywhere and are wiped on every deploy, crash, or restart.
- Limit: any job whose pod has since been replaced cannot serve its output-file downloads. `backend/plumber.R:556-563` now returns a clear 404 ("Output files do not persist across server restarts; re-run the job to regenerate them.") instead of the previous 500, which is an improvement, but the underlying loss is unresolved and forces a full MCMC re-run (multi-minute) to recover downloadable artifacts.
- Scaling path: either mirror outputs into Postgres the same way inputs were (small CSVs, same pattern as `job_input_files`), or attach a PersistentVolumeClaim to `data/outputs/`. `replicas: 1` in `k8s/backend-deployment.yaml` also means there is currently no horizontal scaling of the backend at all.

**`GET /jobs` cost grows linearly (soon super-linearly in wall time) with total job count:**
- Current capacity: ~240 completed jobs recorded as of issue #118 (2026-08-12), growing.
- Limit: see Performance Bottlenecks above — every `/jobs` request re-fetches full log history and metadata for every visible job with no pagination or caching.
- Scaling path: `list_job_summaries()` + pagination (see above).

## Dependencies at Risk

**Unpinned R packages (issue #123, OPEN):** see Tech Debt above. `openVA`, `EAVA`, `vacalibration`, `knitr`, `plumber`, `jsonlite`, `uuid`, `future`, `RPostgres`, `pool`, `jose`, `rJava` are all installed at whatever version is current on `cloud.r-project.org` on the day the image is built; no `renv.lock` or pinned-snapshot equivalent exists for the backend (contrast with `frontend/package-lock.json`).

**`FROM rocker/r-ver:4.4` floating tag:** `backend/Dockerfile:3` (and `.claude/skills/comsa-k8s-deploy/assets/dockerfiles/Dockerfile.backend:2`, a copy of the same Dockerfile pattern used by the k8s-deploy skill) both float on the `4.4` minor tag rather than a pinned patch version or digest.

## Missing Critical Features

**Data-retention/expiry policy (OPEN issue #114):** no scheduled purge, no delete-job endpoint, no documented retention window for identifying VA health data stored in `jobs`, `job_input_files`, `job_files`. See Security Considerations above.

**Job timeout mechanism:** see Performance Bottlenecks above (issue #3, closed unimplemented).

**Job-list pagination:** see Performance Bottlenecks above (issue #6, closed unimplemented).

## Test Coverage Gaps

**194 historical stored results have unknowable calibration state (issue #118, closed as not-planned):**
- What's not tested/recoverable: as of 2026-08-12, of 240 completed jobs, 195 had `calibrated_csmf` but only 1 carried the `path_correction_stalled` flag added by #115 — meaning 194 stored results predate the field and their true stall state is unknown (not necessarily "not stalled," which is what a missing field defaults to on the frontend). At least two of the 194 were confirmed to carry the stall signature (calibrated ≈ uncalibrated *and* mean CI width far below the fleet norm) by manual inspection.
- Files: `backend/db/connection.R:396-404` (`update_job_result`/`toJSON`), `:234` (`fromJSON` on read), `backend/plumber.R:507` area (`GET /jobs/<id>/results` returns the JSONB verbatim), `frontend/src/components/CSMFChart.js` (`buildCsmfFacets`/`buildCsmfTableRows` default missing fields to not-stalled).
- Risk: a historical job whose calibration silently did nothing can still render as an ordinary, trustworthy result to anyone viewing it today.
- Priority: Medium — deliberately closed as not-planned (re-running 194 multi-minute MCMC jobs was judged not worth it), but worth a lightweight mitigation (e.g. the "unknown" UI state proposed in the issue, or the cheap calibrated≈uncalibrated + narrow-CI retro-detector) if this surfaces again in user reports.

**E2E and full backend-integration suites are not enforced by CI:**
- What's not tested in CI: `frontend/e2e/demo-gallery.spec.js`, `frontend/e2e/file-upload.spec.js`, `frontend/src/api/integration.test.js`, and `tests/test_vacalibration_backend.R` (~206 assertions across 18 sections, covering input validation, openVA WHO2016 format, CSV-to-RDS consistency, cause display mapping, and ensemble persistence) all require a live R plumber backend and are explicitly excluded from `.github/workflows/test.yml`.
- Files: `.github/workflows/test.yml:36-57`, `frontend/e2e/*.spec.js`
- Risk: a regression in the calibration pipeline itself (e.g. a future change to stall detection, cause mapping, or the openVA→vacalibration handoff) can merge to `master` without any automated suite catching it; these suites only run when a developer remembers to start the backend and invoke them manually.
- Priority: Medium-High — the CI exclusion is transparently documented (not itself a silent gap), but combined with the Playwright specs' own silent `test.skip` on a missing backend (see Fragile Areas above), there is effectively zero automated coverage of the full calibration pipeline end to end.

---

*Concerns audit: 2026-08-18*
