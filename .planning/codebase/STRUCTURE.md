# Codebase Structure

**Analysis Date:** 2026-08-18

## Directory Layout

```
comsa_dashboard/
├── backend/                     # R plumber API + async job system
│   ├── plumber.R                 # All HTTP route handlers (858 lines)
│   ├── run.R                     # Server entry point (plumb + run on $PORT)
│   ├── init_validation.R         # Startup Stan model validation
│   ├── Dockerfile                # rocker/r-ver-based image, installs openVA/vacalibration
│   ├── auth/                     # JWT auth: passwords, tokens, middleware, user CRUD
│   │   ├── passwords.R
│   │   ├── tokens.R
│   │   ├── middleware.R          # auth_filter, require_admin, check_job_access
│   │   └── users.R
│   ├── db/
│   │   └── connection.R          # Postgres pool, job/log/file CRUD, env loading (503 lines)
│   ├── jobs/                     # Job orchestration
│   │   ├── config.R              # Library loads, Stan/future config, DB source
│   │   ├── processor.R           # process_job() dispatcher + run_pipeline()
│   │   ├── run_job.R             # Background Rscript entry point (one job per process)
│   │   ├── utils.R                # Shared helpers: cause mapping, validation, result shaping (1229 lines)
│   │   └── algorithms/
│   │       ├── openva.R          # run_openva()
│   │       └── vacalibration.R   # run_vacalibration()
│   ├── migrations/                # Hand-run SQL migrations (001, 002, 003 + test_insert.sql)
│   ├── scripts/                   # One-off/debug R scripts (debug_matrix*.R, generate_sample_csvs.R)
│   └── data/                      # Runtime data (gitignored contents, dirs tracked)
│       ├── sample_data/           # Bundled RDS/CSV sample datasets for demos
│       ├── uploads/<job_id>/      # User-uploaded input CSVs (ephemeral, per-pod)
│       ├── outputs/<job_id>/      # Generated result CSVs (ephemeral, per-pod, ~600+ dirs from history)
│       └── jobs/                  # Job metadata JSON sidecar files
├── frontend/                     # React SPA (Vite)
│   ├── src/
│   │   ├── main.jsx               # ReactDOM root, BrowserRouter, AuthProvider
│   │   ├── App.jsx                # Routes, sidebar nav, page layout
│   │   ├── App.css, index.css     # Global styles
│   │   ├── api/
│   │   │   └── client.js          # ALL backend HTTP calls + unbox() normalization boundary
│   │   ├── auth/
│   │   │   └── AuthContext.jsx    # React context: user, login/register/logout
│   │   ├── components/            # One component per file, co-located `.test.js(x)`
│   │   ├── pages/                 # Route-level components (Login, Register, Admin, Landing, etc.)
│   │   ├── content/                # Static content/link data (links.js)
│   │   ├── utils/                  # Pure helper modules (causeDisplay, labels, export, progress, matrixUtils, datetime)
│   │   └── assets/                 # Static assets (images/svgs)
│   ├── e2e/                        # Playwright specs (`*.spec.js`)
│   ├── public/                     # Static files served as-is (sample CSVs, favicon)
│   ├── docs/                       # Frontend-scoped planning docs (superpowers artifacts)
│   ├── playwright.config.js
│   ├── vite.config.js              # Excludes e2e/ from vitest
│   └── package.json
├── tests/                         # Backend-focused R integration/unit tests + fixture files
│   ├── test_vacalibration_backend.R  # ~206 assertions, calls vacalibration() directly
│   ├── test_auth_visibility.R
│   ├── test_input_persistence.R
│   ├── test_misclass_matrix.R
│   └── files/                     # Ad hoc fixture uploads (e.g. .numbers exports)
├── k8s/                            # Kubernetes manifests (namespace, backend/frontend deployment, ingress)
├── docs/                           # Design docs, specs, plans (markdown)
│   ├── plans/
│   └── specs/
├── scripts/                        # Repo-level ops scripts (GHCR secret setup, pod troubleshooting)
├── .claude/skills/, .codex/skills/ # Project-specific Claude/Codex skill docs (openVA, vacalibration, plumber, test, k8s-deploy, postgresql, va-pipeline)
├── .github/workflows/              # CI: deploy.yml, test.yml
├── .planning/codebase/             # Generated codebase maps (this directory)
├── AGENTS.md, CLAUDE.md            # Agent/AI assistant instructions (project conventions)
└── README.md
```

## Directory Purposes

**`backend/jobs/algorithms/`:**
- Purpose: one file per computational algorithm family, each exporting a single `run_<type>(job)` entry function used by `processor.R`'s dispatch `switch()`
- Contains: `openva.R` (InterVA/InSilicoVA/EAVA via openVA package), `vacalibration.R` (Bayesian calibration via vacalibration package)
- Key files: `backend/jobs/algorithms/vacalibration.R` (result-shape source of truth; `run_pipeline()` in `processor.R` duplicates most of its post-calibration logic — see `ARCHITECTURE.md` Anti-Patterns)

**`backend/jobs/`:**
- Purpose: everything about turning a saved job row into a finished/failed job, independent of HTTP
- Contains: dispatcher (`processor.R`), background-process entry (`run_job.R`), shared cause-mapping/validation/result-building helpers (`utils.R`), library/runtime config (`config.R`)
- Key files: `jobs/utils.R` is the largest file in the backend (1229 lines) — grep here before adding a new helper, it likely already has a related one

**`backend/db/`:**
- Purpose: single module owning the Postgres connection pool and all job/log/file/user persistence functions
- Contains: `connection.R` only
- Key files: `db/connection.R` — `save_job`, `load_job`, `update_job_status`, `update_job_result`, `add_log`, `add_job_file`, `save_input_file`/`restore_input_files` (input-mirror durability)

**`backend/auth/`:**
- Purpose: JWT-based authentication and authorization, kept separate from job/DB logic so pieces can be unit-tested without a running Postgres or JWT library where possible
- Contains: `passwords.R` (bcrypt-style hash/verify), `tokens.R` (JWT create/verify), `middleware.R` (plumber filter + HTTP-level access checks), `users.R` (user CRUD)
- Note: `job_visibility()`/`job_access_decision()` — the actual authorization *decisions* — live in `backend/jobs/utils.R`, not here, specifically to stay testable without the `jose` JWT dependency (see comment in `middleware.R`)

**`backend/migrations/`:**
- Purpose: hand-applied SQL schema migrations (no migration runner/tool — applied manually or via deploy scripts)
- Contains: `001_initial_schema.sql` (jobs, job_logs, job_files), `002_users.sql`, `003_input_file_storage.sql`
- Naming: `NNN_description.sql`, strictly increasing, never edited after being applied

**`backend/scripts/`:**
- Purpose: one-off debugging and data-generation scripts, not part of the request path
- Contains: `debug_matrix*.R` (misclassification matrix debugging), `generate_sample_csvs.R`, `validate_samples.R`, `test_samples.sh`

**`backend/data/`:**
- Purpose: runtime data directory; subdirectories are created at request time, not pre-populated in git (except `sample_data/`)
- Contains: `uploads/<job_id>/` (input CSVs), `outputs/<job_id>/` (result CSVs/PNGs), `jobs/` (JSON metadata sidecars), `sample_data/` (bundled demo RDS/CSV files, tracked in git)
- Generated: uploads/outputs are generated per-job and ephemeral (wiped on pod redeploy); `sample_data/` is committed

**`frontend/src/components/`:**
- Purpose: all React UI components, flat (no subdirectories) — one `.jsx` (or `.js` for pure-logic modules like `CSMFChart.js`) per component, with tests co-located
- Contains: form (`JobForm.jsx`, `CausePreview.jsx`), list/detail (`JobList.jsx`, `JobDetail.jsx`), visualization (`CSMFChart.js`, `MisclassificationMatrix.jsx`), chrome (`ProtectedRoute.jsx`, `CustomSelect.jsx`, `ProgressIndicator.jsx`), demo (`DemoGallery.jsx`, `VideosSection.jsx`)
- Key files: `JobDetail.jsx` (results rendering, tabs), `CSMFChart.js` (pure view-model builders, no JSX)

**`frontend/src/pages/`:**
- Purpose: one component per route, wired up in `App.jsx`'s `<Routes>`
- Contains: `LoginPage.jsx`, `RegisterPage.jsx`, `LandingPage.jsx`, `AdminPage.jsx`, `ResourcePage.jsx`, `AcknowledgmentPage.jsx`

**`frontend/src/utils/`:**
- Purpose: pure, framework-free helper functions shared across components; every file has a co-located `.test.js`
- Contains: `causeDisplay.js` (cause name formatting/ordering), `labels.js` (algorithm/age-group display labels), `datetime.js` (timestamp formatting), `export.js` (CSV/PNG/PDF export), `matrixUtils.js` (misclassification matrix cell coloring), `progress.js` (log-parsing progress estimation)

**`frontend/src/api/`:**
- Purpose: sole boundary between frontend and backend HTTP; owns the `unbox()` R-JSON-quirk normalization
- Contains: `client.js` (all endpoint functions), `client.test.js`, `client.issue105.test.js` (regression test), `integration.test.js` (auto-starts backend if not running)

**`tests/` (repo root, not `frontend/` or `backend/`):**
- Purpose: backend-focused R tests that exercise `vacalibration()`/auth/input-persistence logic directly (not via HTTP), plus shared fixture files
- Contains: `test_vacalibration_backend.R`, `test_auth_visibility.R`, `test_input_persistence.R`, `test_misclass_matrix.R`, `files/` (fixture uploads)
- Naming: `test_<area>.R`, run manually via `Rscript tests/test_*.R` (see `.claude/skills/test/`)

**`k8s/`:**
- Purpose: Kubernetes deployment manifests for the two-service (frontend/backend) deployment
- Contains: `namespace.yaml`, `backend-deployment.yaml`, `frontend-deployment.yaml`, `ingress.yaml`

**`docs/`:**
- Purpose: durable design docs, specs, and historical plans (not auto-generated codebase maps — those live in `.planning/codebase/`)
- Contains: `plans/` (dated design docs, e.g. `2026-03-12-multi-upload-ensemble-design.md`), `specs/` (feature specs, e.g. `2026-04-07-user-management.md`)

## Key File Locations

**Entry Points:**
- `backend/run.R`: plumber server process start
- `backend/jobs/run_job.R`: background job-runner process start (one per job)
- `frontend/src/main.jsx`: React app mount

**Configuration:**
- `backend/jobs/config.R`: R package loads, Stan/future runtime config
- `.env`, `.env.local` (repo root, gitignored contents): DB credentials, `PORT`, `AUTH_GRACE_PERIOD`, `VITE_API_BASE_URL`
- `frontend/vite.config.js`: Vite/vitest config (excludes `e2e/`)
- `frontend/playwright.config.js`: E2E test config (Chromium-only, 3min timeout)

**Core Logic:**
- `backend/plumber.R`: every HTTP route
- `backend/jobs/processor.R`: job dispatch + pipeline orchestration
- `backend/jobs/algorithms/vacalibration.R`: calibration result assembly (canonical shape)
- `backend/jobs/utils.R`: cause mapping, validation, shared result-building helpers
- `backend/db/connection.R`: all persistence
- `frontend/src/api/client.js`: all HTTP calls + `unbox()`
- `frontend/src/components/JobDetail.jsx`: results rendering
- `frontend/src/components/CSMFChart.js`: view-model builders

**Testing:**
- `backend`: `tests/test_*.R` (repo root `tests/`, not `backend/tests/`)
- `frontend`: co-located `*.test.js`/`*.test.jsx`/`*.behavior.test.jsx` next to source files, plus `frontend/e2e/*.spec.js`

## Naming Conventions

**Files (backend, R):**
- One file per logical module, `snake_case` for multi-word filenames that are not R object names (e.g. `connection.R`, `run_job.R`)
- Algorithm modules named after the algorithm/package they wrap: `openva.R`, `vacalibration.R`
- Migrations: `NNN_description.sql` with strictly increasing zero-padded numeric prefix

**Files (frontend, JS/JSX):**
- Components: `PascalCase.jsx` (e.g. `JobDetail.jsx`, `MisclassificationMatrix.jsx`)
- Pure logic modules (no JSX): `camelCase.js` (e.g. `causeDisplay.js`, `labels.js`) — note `CSMFChart.js` is an exception (PascalCase but no JSX, pure view-model builders co-located conceptually with `CSMFChart` rendering in `JobDetail.jsx`)
- Tests: `<SourceName>.test.js` / `.test.jsx` for vitest; `<SourceName>.<issueNNN>.test.js(x)` or `.behavior.test.jsx` for regression/behavior-specific suites tied to a GitHub issue number; `.spec.js` reserved exclusively for Playwright E2E (`frontend/e2e/`)

**Functions (R):**
- `snake_case` throughout, verb-first for actions (`run_vacalibration`, `save_job`, `extract_misclass_matrix`, `build_summary_df`), `is_`/`has_`/`require_`/`assert_` prefixes for predicates/guards (`is_broad_format`, `require_enum`, `assert_all_causes_mapped`)
- Private/internal helpers prefixed with a leading dot: `.declared_not_calibrated`, `.build_misclass_entry` (both in `jobs/utils.R`)

**Functions (JS):**
- `camelCase`, verb-first for actions (`submitJob`, `buildCsmfFacets`, `formatCauseDisplay`), `use`-prefixed for hooks (`useAuth`)

**Variables:**
- R: `snake_case` (`job_id`, `va_broad`, `calib_result`)
- JS: `camelCase` (`jobId`, `refreshTrigger`)

**Types/interfaces:**
- No TypeScript in this codebase; shapes are documented via comments (e.g. the extensive shape-documentation comments in `CSMFChart.js`) rather than type declarations. R has no formal type system; job/result shapes are documented in comments in `plumber.R` and `jobs/utils.R`.

## Where to Add New Code

**New job type (e.g. a third algorithm):**
- Add `backend/jobs/algorithms/<name>.R` exporting `run_<name>(job)`, matching the existing shape (load input -> run package call -> build result list -> write output files -> `add_job_file()`)
- Register it in `backend/jobs/processor.R`'s `process_job()` `switch()` and in `backend/plumber.R`'s `VALID_JOB_TYPES` (defined via `jobs/utils.R` — search `VALID_JOB_TYPES` before adding)
- Source it from `backend/jobs/processor.R`'s top-of-file `source()` calls
- If the new type also needs pipeline-style chaining, expect to duplicate result-assembly into `run_pipeline()` unless the Anti-Pattern in `ARCHITECTURE.md` has been fixed first — check before copy-pasting further

**New HTTP endpoint:**
- Add a new `#* @get`/`#* @post` block to `backend/plumber.R`; add a corresponding function to `frontend/src/api/client.js` following the `fetchJson()` pattern (never call `fetch()` directly from a component)
- If the endpoint returns job-scoped data, reuse `check_job_access()` (`backend/auth/middleware.R`) for authorization, not a hand-rolled check

**New React component:**
- Add `frontend/src/components/<Name>.jsx` (flat, no subfolders) with a co-located `<Name>.test.jsx`
- If the component needs a nontrivial data transform, put the transform in a pure function in the component's own `.js` file (see `CSMFChart.js` pattern) or in `frontend/src/utils/`, and unit-test it separately from the rendering

**New page/route:**
- Add `frontend/src/pages/<Name>Page.jsx`, register the route in `frontend/src/App.jsx`'s `<Routes>`, wrap in `<ProtectedRoute>` unless intentionally public (mirror `LandingPage`/`LoginPage`/`RegisterPage`)

**Utilities:**
- Backend shared helpers: `backend/jobs/utils.R` (grep first — file is large and likely already has something close)
- Frontend shared helpers: `frontend/src/utils/<name>.js`, always with a co-located `<name>.test.js`

**Database schema changes:**
- Add a new `backend/migrations/NNN_description.sql` file (never edit an already-applied migration); update `backend/db/connection.R` CRUD functions to match

## Special Directories

**`backend/data/uploads/`, `backend/data/outputs/`:**
- Purpose: per-job input/output file storage
- Generated: Yes (created per-job at request time)
- Committed: No (gitignored contents; directory structure only exists at runtime) — NOTE: at analysis time this directory contains ~600+ leftover job subdirectories from prior runs; these are not source code and should not be treated as part of the codebase structure to navigate

**`backend/data/sample_data/`:**
- Purpose: bundled demo datasets (RDS files pre-run through openVA, plus `new_test_data.csv`)
- Generated: Partially (some RDS files are generated by `backend/scripts/generate_sample_csvs.R`)
- Committed: Yes

**`.planning/codebase/`:**
- Purpose: auto-generated codebase maps (this document and its siblings — STACK.md, ARCHITECTURE.md, etc.)
- Generated: Yes, by `/gsd-map-codebase`
- Committed: Typically yes (consumed by other GSD planning commands)

**`.claude/skills/`, `.codex/skills/`:**
- Purpose: project-specific AI-assistant skill documentation (openVA, vacalibration, plumber, test, va-pipeline, comsa-k8s-deploy, comsa-postgresql, log-query)
- Generated: No (hand-authored reference material)
- Committed: Yes

**`docs/superpowers/`, `frontend/docs/superpowers/`, `.superpowers/`:**
- Purpose: artifacts from a "superpowers" planning/brainstorm tool (plans, specs, brainstorm session state)
- Generated: Yes (tool-generated planning artifacts)
- Committed: Mixed (`.superpowers/` at repo root holds active session state; `docs/superpowers/` holds finalized plans/specs)

---

*Structure analysis: 2026-08-18*
