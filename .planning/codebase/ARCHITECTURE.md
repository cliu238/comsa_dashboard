<!-- refreshed: 2026-08-18 -->
# Architecture

**Analysis Date:** 2026-08-18

## System Overview

```text
┌─────────────────────────────────────────────────────────────────────┐
│                         React SPA (frontend/)                        │
│   Pages/Components — JobForm, JobDetail, DemoGallery, AdminPage      │
│   `frontend/src/components`, `frontend/src/pages`                    │
└───────────────────────────┬────────────────────────────────────────┘
                            │ fetch() + JWT bearer token
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                 api client boundary (unbox R JSON quirks)            │
│                 `frontend/src/api/client.js`                         │
└───────────────────────────┬────────────────────────────────────────┘
                            │ HTTP (multipart/form + query params)
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     R plumber HTTP API (backend/)                    │
│   Filters: cors -> auth_filter        Routes: /jobs, /auth, /admin   │
│   `backend/plumber.R`, `backend/auth/middleware.R`                   │
└───────────────────────────┬────────────────────────────────────────┘
                            │ start_job_async() -> Rscript subprocess
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  Background job runner (own R process)               │
│   `backend/jobs/run_job.R` -> `backend/jobs/processor.R`             │
├───────────────────┬───────────────────────┬─────────────────────────┤
│  run_openva()      │  run_vacalibration()  │  run_pipeline()         │
│ `jobs/algorithms/  │ `jobs/algorithms/     │ `jobs/processor.R`      │
│  openva.R`         │  vacalibration.R`     │ (openVA -> vacalibration)│
└───────────────────┴───────────────────────┴─────────────────────────┘
                            │ writes
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│  PostgreSQL (jobs, job_logs, job_files, input_files, users)          │
│  `backend/db/connection.R`, `backend/migrations/*.sql`               │
│  + ephemeral pod disk: `backend/data/uploads/<id>`,                  │
│    `backend/data/outputs/<id>` (wiped on redeploy, issue #110)       │
└─────────────────────────────────────────────────────────────────────┘
```

## Component Responsibilities

| Component | Responsibility | File |
|-----------|----------------|------|
| Plumber router | Defines every REST endpoint, request parsing, response shaping | `backend/plumber.R` |
| Auth filter/middleware | JWT verification, per-request `req$user`, job-access decisions | `backend/auth/middleware.R`, `backend/auth/tokens.R` |
| Job dispatcher | Chooses openva/vacalibration/pipeline based on `job.type` | `backend/jobs/processor.R` (`process_job()`) |
| Background runner | Separate `Rscript` process invoked per job (async boundary) | `backend/jobs/run_job.R` |
| openVA algorithm | Runs InterVA/InSilicoVA/EAVA via openVA package, extracts CSMF | `backend/jobs/algorithms/openva.R` |
| vacalibration algorithm | Loads CSV(s), maps causes to broad categories, runs Bayesian calibration, assembles result JSON | `backend/jobs/algorithms/vacalibration.R` |
| Pipeline orchestration | Runs openVA then vacalibration in one job, duplicates most of vacalibration.R's result assembly | `backend/jobs/processor.R` (`run_pipeline()`) |
| Shared job helpers | Cause mapping, validation, result-shaping helpers (`build_summary_df`, `build_per_algorithm`, `extract_misclass_matrix`, param parsing) | `backend/jobs/utils.R` |
| DB access layer | Connection pool, job CRUD, logs, file metadata, input-file byte mirror | `backend/db/connection.R` |
| React app shell | Routing, sidebar nav, auth-gated layout | `frontend/src/App.jsx`, `frontend/src/main.jsx` |
| Auth context | Holds JWT/user in memory + localStorage, login/register/logout | `frontend/src/auth/AuthContext.jsx` |
| API client + unbox boundary | All backend HTTP calls; normalizes R/plumber JSON quirks | `frontend/src/api/client.js` |
| Job submission UI | Multi-file upload, algorithm/age-group/country selection, pre-submit cause preview | `frontend/src/components/JobForm.jsx`, `CausePreview.jsx` |
| Job results UI | Status/log/results tabs, CSMF chart, misclassification matrix, exports | `frontend/src/components/JobDetail.jsx`, `CSMFChart.js`, `MisclassificationMatrix.jsx` |
| View-model builders | Pure functions turning raw `results` JSON into chart/table-ready shapes | `frontend/src/components/CSMFChart.js`, `frontend/src/utils/matrixUtils.js` |

## Pattern Overview

**Overall:** Two-tier client/server app with an async worker-process job system layered on top of a synchronous REST API. Not a queue-based job system — each job spawns its own OS process (`Rscript jobs/run_job.R <job_id>`) rather than being picked up by a persistent worker pool.

**Key Characteristics:**
- Stateless plumber API process; all durable job state lives in Postgres (`jobs`, `job_logs`, `job_files`, `input_files` tables).
- Job execution is fire-and-forget: `POST /jobs` returns immediately with `status: "pending"`; the frontend polls `GET /jobs/<id>/status` every 3 seconds (`frontend/src/components/JobDetail.jsx`).
- Each job type has its own algorithm module, but the two calibration-producing paths (`run_vacalibration()` and `run_pipeline()`) independently reimplement the same result-assembly logic — see **Anti-Patterns** below.
- Frontend is a pure view over backend-computed statistics; no client-side statistical computation. All chart/table transforms are pure, testable functions kept out of JSX (`CSMFChart.js`, `matrixUtils.js`).
- R's JSON serialization quirks (scalar vs length-1 array, `NULL` vs `{}`) are normalized at exactly one seam (`unbox()` in `frontend/src/api/client.js`); everything downstream of `fetchJson()` assumes normal JS scalars/nulls.

## Layers

**Presentation (React components/pages):**
- Purpose: render job forms, status, and results; no business logic beyond simple view-model shaping.
- Location: `frontend/src/components/`, `frontend/src/pages/`
- Contains: `.jsx` components, matching `.test.js`/`.test.jsx`/`.behavior.test.jsx` files
- Depends on: `frontend/src/api/client.js`, `frontend/src/utils/*`, `frontend/src/auth/AuthContext.jsx`
- Used by: `frontend/src/App.jsx` (routing)

**API client (unbox boundary):**
- Purpose: single point of contact with the backend HTTP API; owns auth headers, error unwrapping, and R-JSON normalization
- Location: `frontend/src/api/client.js`
- Contains: `fetchJson()`, `unbox()`, one exported function per endpoint (`submitJob`, `getJobStatus`, `previewMapping`, etc.)
- Depends on: `VITE_API_BASE_URL` env var, `localStorage` token
- Used by: every component/page that talks to the backend

**View-model builders (pure functions):**
- Purpose: transform raw, already-unboxed `results` JSON into render-ready shapes (facets, table rows, whisker offsets, matrix cell colors)
- Location: `frontend/src/components/CSMFChart.js`, `frontend/src/utils/matrixUtils.js`, `frontend/src/utils/causeDisplay.js`, `frontend/src/utils/labels.js`
- Depends on: nothing but plain JS/the shape of `results`
- Used by: `JobDetail.jsx`, `MisclassificationMatrix.jsx`; directly unit-tested (`CSMFChart.test.js`, `MisclassificationMatrix.test.js`)

**Plumber API (routing/HTTP):**
- Purpose: parse HTTP requests, enforce auth, validate parameters, persist job records, kick off background execution, shape HTTP responses
- Location: `backend/plumber.R`
- Contains: every `#* @get`/`#* @post` route handler
- Depends on: `backend/jobs/processor.R`, `backend/auth/*`, `backend/db/connection.R`
- Used by: frontend via HTTP only

**Job orchestration:**
- Purpose: dispatch a job by `type`, run it in a separate process, and record status/result/error
- Location: `backend/jobs/processor.R`, `backend/jobs/run_job.R`, `backend/jobs/config.R`
- Contains: `process_job()`, `start_job_async()`, `launch_background_job()`, `run_pipeline()`
- Depends on: `backend/jobs/algorithms/*`, `backend/jobs/utils.R`, `backend/db/connection.R`
- Used by: `backend/plumber.R` (`start_job_async` after `save_job`)

**Algorithm modules:**
- Purpose: run one specific computation (openVA classification, vacalibration calibration) and package its result JSON
- Location: `backend/jobs/algorithms/openva.R`, `backend/jobs/algorithms/vacalibration.R`
- Depends on: `openVA` and `vacalibration` R packages, `backend/jobs/utils.R` helpers
- Used by: `backend/jobs/processor.R` (`process_job()` switch, and directly by `run_pipeline()`)

**Shared job utilities:**
- Purpose: cross-cutting helpers used by every algorithm path: cause-name mapping/validation, misclassification-matrix extraction, per-algorithm result building, parameter parsing/validation, access-control decisions
- Location: `backend/jobs/utils.R` (1229 lines — the largest backend file)
- Depends on: `vacalibration` package internals (broad-cause matrices), `backend/db/connection.R` (`add_log`)
- Used by: `backend/jobs/algorithms/*.R`, `backend/jobs/processor.R`, `backend/plumber.R`, `backend/auth/middleware.R` (`job_visibility`, `job_access_decision`)

**Data access:**
- Purpose: Postgres connection pooling, job/user CRUD, log/file metadata, input-file byte mirroring for pod-restart durability
- Location: `backend/db/connection.R`, `backend/auth/users.R`
- Depends on: `RPostgres`, `pool`, `backend/migrations/*.sql` (schema)
- Used by: everything above it

**Auth:**
- Purpose: password hashing, JWT issuance/verification, request-level auth filter, job/resource access decisions
- Location: `backend/auth/passwords.R`, `backend/auth/tokens.R`, `backend/auth/middleware.R`, `backend/auth/users.R`
- Depends on: `jose` (JWT), `backend/db/connection.R`
- Used by: `backend/plumber.R` (filter + route handlers)

## Data Flow

### Primary Request Path (job submission -> result)

1. User fills `JobForm.jsx`, optionally triggers `previewMapping()` (`frontend/src/api/client.js:93`) which hits `POST /jobs/preview` for a dry-run cause-mapping report with no job created (`backend/plumber.R:364` `preview_cause_mapping`).
2. `submitJob()` (`frontend/src/api/client.js:52`) POSTs multipart form + query-string scalars to `POST /jobs`.
3. `backend/plumber.R:206` resolves and validates every scalar via `jobs/utils.R` parameter helpers (`require_enum`, `require_algorithms`, `resolve_age_group`, etc.), saves uploaded file(s) to `backend/data/uploads/<job_id>/`, calls `save_job()` (`backend/db/connection.R:146`) to insert the `jobs` row, then `save_input_file()` to mirror file bytes into Postgres (durability across pod restarts), then `start_job_async(job_id)`.
4. `start_job_async()` -> `launch_background_job()` (`backend/jobs/processor.R:11-36`) spawns a **new OS process**: `Rscript jobs/run_job.R <job_id>`. The plumber process returns `{job_id, status: "pending"}` immediately without waiting.
5. The spawned process (`backend/jobs/run_job.R`) sources `jobs/processor.R` and calls `process_job(job_id)`, which loads the job row, calls `ensure_input_files()` (restores files from the DB mirror if disk copies are missing — issue #110), sets status to `"running"`, then dispatches on `job$type` via `switch()` (`backend/jobs/processor.R:50-55`) to `run_openva()`, `run_vacalibration()`, or `run_pipeline()`.
6. The chosen algorithm function loads input data, maps causes to broad categories (`safe_cause_map`/`build_broad_matrix` in `jobs/utils.R`), runs the R package function (`codeVA()` or `vacalibration()`), assembles a result list, writes output CSVs to `backend/data/outputs/<job_id>/`, registers them via `add_job_file()`, and returns the result list.
7. `process_job()` calls `update_job_status(job_id, "completed")` then `update_job_result(job_id, result)` (`backend/db/connection.R`), which serializes the result list to the `jobs.result` JSONB column.
8. Meanwhile, `JobDetail.jsx` polls `GET /jobs/<id>/status` every 3s (`useEffect` interval, `frontend/src/components/JobDetail.jsx:57-63`); once `status === "completed"`, it fetches `GET /jobs/<id>/results` (`getJobResults`).
9. Every response passes through `fetchJson()` -> `unbox()` (`frontend/src/api/client.js:38-50`) before reaching component state.
10. `ResultsTab` -> `CalibratedResults` builds view-models via `buildCsmfFacets()`/`buildCsmfTableRows()` (`CSMFChart.js`) and renders the chart, misclassification matrix, and comparison table.

### Job Rerun Flow

1. `POST /jobs/<job_id>/rerun` (`backend/plumber.R:722`) loads the original job, calls `ensure_input_files()` to restore any wiped input files from the DB mirror, copies them into a new upload dir under a new `job_id`, clones job parameters, and starts async processing exactly like a fresh submission.

### Demo/Sample-Data Flow

1. `POST /demos/launch` (`backend/plumber.R:653`) or `POST /jobs/demo` (`backend/plumber.R:584`) creates a job with `use_sample_data = TRUE` and no uploaded file; algorithm modules branch on this flag to load bundled RDS sample files (`load_openva_sample`, `load_vacalibration_sample` in `jobs/utils.R`) instead of reading `job$input_file`.

**State Management:**
- Backend: all durable state in Postgres; no in-memory job registry in the plumber process (each request re-queries the DB). `.db_pool` is a module-level global in `backend/db/connection.R`, lazily initialized once per R process (so the plumber server and every spawned worker process each have their own pool).
- Frontend: component-local `useState`/`useEffect` polling in `JobDetail.jsx`; global state limited to `AuthContext` (JWT + user object), no Redux/Zustand/global store.

## Key Abstractions

**Job record (`jobs` table / R list):**
- Purpose: single source of truth for a unit of work — parameters, status, timestamps, log, result, error
- Examples: constructed in `backend/plumber.R` (`POST /jobs`, `/jobs/demo`, `/demos/launch`, `/jobs/<id>/rerun`), persisted via `save_job()`/`load_job()`/`update_job_status()`/`update_job_result()` in `backend/db/connection.R`
- Pattern: plain R list with fixed fields (`id`, `type`, `status`, `algorithm`, `age_group`, `country`, `calib_model_type`, `ensemble`, `n_mcmc/n_burn/n_thin`, `input_file`/`input_files`, `result`, `error`, `log`, `user_id`)

**Broad-cause matrix (`va_broad`):**
- Purpose: the intermediate format `vacalibration::vacalibration()` requires — per-record one-hot assignment to a fixed set of broad cause categories (6 for neonate, 9 for child)
- Examples: `build_broad_matrix()`, `safe_cause_map()` in `backend/jobs/utils.R`
- Pattern: built either by mapping specific algorithm cause names via `safe_cause_map()` (wraps `vacalibration::cause_map()`) or directly via `build_broad_matrix()` when the input is already broad-format

**Result object (job `result` JSON):**
- Purpose: the single JSON blob returned by `GET /jobs/<id>/results`, consumed unmodified by the frontend
- Examples: assembled independently in `run_openva()`, `run_vacalibration()`, and `run_pipeline()`
- Pattern: `{ algorithm, age_group, country, ensemble, uncalibrated_csmf, calibrated_csmf, calibrated_ci_lower, calibrated_ci_upper, per_algorithm, misclassification_matrix, cause_display_names, cause_order, files }` — same shape whether produced by vacalibration-only or pipeline jobs, because both hand-build it from the same `vacalibration()` return value

**View-model facet (frontend):**
- Purpose: decouples raw per-algorithm/ensemble result JSON from chart rendering
- Examples: `buildCsmfFacets()`, `buildCsmfTableRows()` in `frontend/src/components/CSMFChart.js`
- Pattern: pure function, one facet per algorithm (plus ensemble when present), each facet fully self-contained (`causes`, `lambda`, `ciUnreliable`, `stalledConstituents`)

## Entry Points

**Plumber HTTP server:**
- Location: `backend/run.R` -> `backend/plumber.R`
- Triggers: process start (`Rscript run.R`, or container `CMD`)
- Responsibilities: source `init_validation.R` (Stan model validation), plumb and run `plumber.R` on `$PORT` (default 8000)

**Background job runner:**
- Location: `backend/jobs/run_job.R`
- Triggers: `system2(Rscript, args = c("jobs/run_job.R", job_id), wait = FALSE)` from `launch_background_job()` in `backend/jobs/processor.R`
- Responsibilities: fix working directory to `backend/`, set `COMSA_WORKER=1` (skips startup-only orphan cleanup), source `jobs/processor.R`, call `process_job(job_id)`, exit

**React app:**
- Location: `frontend/src/main.jsx` -> `frontend/src/App.jsx`
- Triggers: browser loads `index.html` (Vite dev server or built `dist/`)
- Responsibilities: mount `BrowserRouter` (basename `/comsa-dashboard`), wrap in `AuthProvider`, render routed pages inside `App`

## Architectural Constraints

- **Process model:** every job runs in its own short-lived OS process (`Rscript jobs/run_job.R <id>`), not a shared worker pool or queue. No concurrency limit is enforced — many simultaneous jobs spawn many simultaneous R processes, each loading `openVA`/`vacalibration`/Stan.
- **Global state:** `.db_pool` (`backend/db/connection.R`) is a module-level singleton reinitialized per R process (main server and every spawned worker get their own pool + `ensure_input_file_storage()` call). `.job_metadata_dir` is a similar module-level path constant.
- **Ephemeral disk vs durable DB:** `backend/data/uploads/` and `backend/data/outputs/` are pod-local disk and are wiped on redeploy (issue #110). Input file bytes are mirrored into Postgres (`input_files` table via `save_input_file`/`restore_input_files`) specifically to survive this; output files are NOT mirrored and are treated as regenerable via rerun.
- **No message queue:** async boundary is `system2(..., wait = FALSE)`, not Redis/SQS/etc. Job status transitions (`pending` -> `running` -> `completed`/`failed`) are only ever written by the worker process itself; a killed pod leaves jobs stuck in `"running"` until `cleanup_orphaned_jobs()` runs on next main-server startup.
- **R/JSON serialization boundary:** plumber's `jsonlite` auto-unboxing rules (length-1 vectors -> scalars, `NULL` -> `{}`) are a permanent characteristic of every response. The frontend's `unbox()` (`frontend/src/api/client.js`) is the only place this is corrected; any new backend field must be read downstream assuming it has passed through `unbox()`.
- **InSilicoVA global-env workaround:** `codeVA(..., model = "InSilicoVA")` uses `rjags`/`future`, which has environment-scoping issues; both `openva.R` and `processor.R`'s pipeline path work around this by temporarily assigning input data to `.GlobalEnv` under a per-job unique name before calling `codeVA()`, then removing it (`backend/jobs/algorithms/openva.R:36-38`, `backend/jobs/processor.R:108-118`).

## Anti-Patterns

### Duplicated result-assembly logic between vacalibration-only and pipeline paths

**What happens:** `run_vacalibration()` (`backend/jobs/algorithms/vacalibration.R:190-297`) and `run_pipeline()` (`backend/jobs/processor.R:173-291`) both call the same `vacalibration()` package function and then independently reimplement: extracting `primary` row (ensemble vs single-algo), rounding `uncalibrated`/`calibrated`/CI lists, calling `build_per_algorithm()`, `build_stall_fields()`, `extract_misclass_matrix()`, writing `calibration_summary.csv` and `misclass_matrix*.csv` via nearly identical loops, and assembling the final `result_obj` list with matching field names.
**Why it's wrong:** The two code blocks are ~100 lines each of near-copy-paste. A fix to result assembly (new field, changed rounding, bug in misclassification-matrix file naming, changed handling of `stall_fields`) has to be applied twice by hand. History shows this landing in only one path at a time (per project memory: fixes for issues #83, #90, #101, #117 all touch both files in lockstep, and are easy to miss in one).
**Do this instead:** Extract a single `assemble_calibration_result(calib_result, job, algorithms, ...)` helper into `backend/jobs/utils.R` that both `run_vacalibration()` and `run_pipeline()` call after they obtain `calib_result` from `vacalibration()`. Keep `run_pipeline()`'s openVA step and `run_vacalibration()`'s multi-file loading step separate; only the post-`vacalibration()` assembly is duplicated. When modifying either result-shape, grep both files (`grep -rn "build_per_algorithm\|build_stall_fields\|extract_misclass_matrix" backend/jobs/`) until this is unified.

### Sample-data vs uploaded-data branching duplicated per algorithm module

**What happens:** Both `run_openva()` (`backend/jobs/algorithms/openva.R:9-15`) and `run_vacalibration()`/`run_pipeline()` independently check `isTRUE(job$use_sample_data)` and branch to different loader functions, each hand-rolling the same "load sample vs read CSV vs error if missing" logic in three places.
**Why it's wrong:** Any change to how sample data is chosen or how missing-file errors are reported must be replicated across all three call sites.
**Do this instead:** A single `load_job_input(job, algo)` dispatcher in `jobs/utils.R` that already exists in spirit (`load_openva_sample`, `load_vacalibration_sample`) could be the single decision point; currently each caller still duplicates the `if (isTRUE(job$use_sample_data))` branch itself.

### Global-environment workaround for InSilicoVA scoping

**What happens:** Input data is assigned to `.GlobalEnv` under a manufactured variable name (`..insilico_data..` or `..insilico_data_<job_id>_<algo>..`) purely to work around `codeVA(model = "InSilicoVA")`'s interaction with `future`/`rjags` scoping, then removed with `rm()`/`on.exit()`.
**Why it's wrong:** Pollutes the global environment of a long-lived plumber/worker process; a crash between `assign()` and `rm()` (e.g., in the pipeline's multi-algorithm loop, which does not use `on.exit()` for the pipeline case at `backend/jobs/processor.R:108-118`, only an explicit `rm()` after the block) can leak the variable into subsequent jobs sharing the same worker process. In practice each job runs in its own freshly-spawned `Rscript` process (see Architectural Constraints), which limits but does not eliminate the risk if `process_job()` is ever called synchronously in-process (`launch_background_job()`'s fallback path, `backend/jobs/processor.R:22`).
**Do this instead:** Treat this as a documented, intentional package-level workaround (it is commented in both files); do not remove without confirming `future`/`rjags` scoping is actually fixed upstream.

## Error Handling

**Strategy:** `tryCatch()` at process-job granularity: any error thrown inside `run_openva()`/`run_vacalibration()`/`run_pipeline()` is caught in `process_job()` (`backend/jobs/processor.R:60-62`) and recorded as `status = "failed"`, `error = conditionMessage(e)`. Route-handler-level `tryCatch()` is used inconsistently: some handlers (`/auth/login`, `/jobs` list) wrap their body in `tryCatch`, others (`POST /jobs`, `/jobs/<id>/rerun`) rely on early `return(list(error = ...))` for validation failures and let unexpected exceptions propagate as plumber 500s.

**Patterns:**
- Parameter validation failures return `list(error = "...")` with HTTP 200 (not always paired with a non-200 status) rather than throwing — e.g., `require_enum()`/`require_algorithms()` in `backend/jobs/utils.R` throw R conditions that are caught and converted to `{error: message}` by the calling route (`backend/plumber.R:221-238`), specifically so a raw `stop()` inside a `tryCatch` error handler does not abort the caller's outer function.
- Domain validation failures (e.g., unrecognized cause names) throw structured, actionable errors via `validate_causes()`/`assert_all_causes_mapped()` (`backend/jobs/utils.R`) rather than silently dropping records — an explicit project convention (see `assert_all_causes_mapped`, issue #92).
- Frontend never assumes an error is a clean string: `JobDetail.jsx`'s inline error-rendering IIFE (`backend/plumber.R`-produced `status.error` field) explicitly handles string, array-of-one-object, and empty-object shapes because of the R JSON boundary.

## Cross-Cutting Concerns

**Logging:** Backend job logs are DB-backed (`job_logs` table) and streamed near-real-time from long-running R package calls via `run_with_capture()` (`backend/jobs/utils.R:8`), which sinks stdout to a temp file tailed by a separate spawned `Rscript` "flusher" process every 2 seconds, plus direct `add_log()` calls for messages/warnings intercepted via `withCallingHandlers`. Frontend polls `GET /jobs/<id>/log` alongside status.

**Validation:** Centralized in `backend/jobs/utils.R` parameter helpers (`require_enum`, `optional_count`, `require_algorithms`, `resolve_age_group`) used by every job-creation route in `plumber.R`, and in cause-mapping validators (`validate_causes`, `assert_all_causes_mapped`) used by both calibration algorithm paths.

**Authentication:** JWT-based, enforced globally by the `auth` plumber filter (`backend/auth/middleware.R`) except for `PUBLIC_ENDPOINTS` (`/health`, `/auth/login`, `/auth/register`). `AUTH_GRACE_PERIOD` env var can disable enforcement (documented as off since login shipped). Job-level access control (`job_access_decision`, `job_visibility` in `backend/jobs/utils.R`) is kept out of `middleware.R` so it stays testable without a JWT library dependency.

---

*Architecture analysis: 2026-08-18*
