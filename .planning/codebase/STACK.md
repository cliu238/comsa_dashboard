# Technology Stack

**Analysis Date:** 2026-08-18

## Languages

**Primary:**
- R (>= 4.4, `rocker/r-ver:4.4` base image) - Backend API, all job-processing logic (`backend/plumber.R`, `backend/jobs/`)
- JavaScript (ES2020+/JSX) - Frontend React app (`frontend/src/`)

**Secondary:**
- SQL (PostgreSQL dialect) - Schema migrations (`backend/migrations/*.sql`)
- Bash - CI workflows, deploy scripts, sample data helper scripts (`backend/scripts/test_samples.sh`)

No `DESCRIPTION` file exists for the backend (confirmed by `.github/workflows/test.yml` comment) — this is a plain R script project, not an R package, so there is no CRAN-style dependency manifest, only ad hoc `library()` calls and the Dockerfile's `install.packages()` invocations.

## Runtime

**Environment:**
- R 4.4 (backend), pinned only at the OS-image level via `FROM rocker/r-ver:4.4` in `backend/Dockerfile`
- Node.js 18 (frontend Docker build, `frontend/Dockerfile` line 6: `FROM node:18-alpine`) vs Node.js 20 in CI (`.github/workflows/test.yml` line 30: `node-version: 20`) — **version mismatch between CI and the production Docker build**, not currently pinned via `.nvmrc` (none present)

**Package Manager:**
- npm (frontend) - Lockfile present: `frontend/package-lock.json`
- CRAN `install.packages()` (backend) - **No lockfile / no version pins.** See "Dependency Pinning Status" below.

## Frameworks

**Core:**
- plumber (R) - REST API framework exposing all backend endpoints, single file `backend/plumber.R` (~27KB, `@get`/`@post` annotated routes)
- React 19.2 (`frontend/package.json`) - Frontend UI framework
- React Router 7.14 (`react-router-dom`) - Client-side routing (`frontend/src/pages/`)

**Domain-specific (R):**
- openVA - VA data processing / cause-of-death coding algorithms (InterVA, InSilicoVA, EAVA), invoked in `backend/jobs/algorithms/openva.R` via `codeVA()`
- EAVA - Algorithm dependency of openVA, installed explicitly because it is only `Suggests`'d by openVA (`backend/Dockerfile` line 41 comment)
- vacalibration (v2.2) - Bayesian calibration of VA cause classifications, invoked in `backend/jobs/algorithms/vacalibration.R`
- rstan / rJava - Transitive/runtime dependencies pulled in to recompile vacalibration's bundled Stan models at image build time (`backend/Dockerfile` lines 45-71: `seqcalib.stan`, `seqcalib_mmat.stan` compiled fresh and written back over the CRAN-shipped `.rds` files for cross-platform compatibility)

**Testing:**
- Vitest 4.0 - Frontend unit tests (`frontend/package.json`, config embedded in `frontend/vite.config.js` `test` block)
- @testing-library/react 16.3 - Component testing helpers
- Playwright 1.58 (`@playwright/test`) - E2E tests, config `frontend/playwright.config.js`, spec files in `frontend/e2e/`
- Base R + jsonlite only - Backend test suites under `tests/*.R`, run directly with `Rscript` (no R test framework such as testthat is used)

**Build/Dev:**
- Vite 5.4 - Frontend dev server and production bundler (`frontend/vite.config.js`), base path `/comsa-dashboard/` baked in for the deployed subpath
- ESLint 9.39 (flat config, `frontend/eslint.config.js`) - JS/JSX linting, `eslint-plugin-react-hooks` + `eslint-plugin-react-refresh`
- Docker multi-stage builds for both services (`backend/Dockerfile`, `frontend/Dockerfile`)

## Key Dependencies

**Critical (R / backend, all from `backend/Dockerfile` `install.packages()` calls):**
- `plumber` - HTTP API server
- `RPostgres` + `pool` - PostgreSQL client and connection pooling (`backend/db/connection.R`)
- `jose` - JWT creation/verification, HMAC-SHA256 (`backend/auth/tokens.R`)
- `future` - Async job execution; plan selected in `backend/jobs/config.R` (`multicore` on Unix if supported, else `multisession`)
- `uuid` - Job ID generation
- `jsonlite` - JSON (de)serialization throughout backend
- `rJava` - Required by openVA's InSilicoVA algorithm (rjags dependency chain); Dockerfile does explicit Java linker-path configuration (`R CMD javareconf`) before installing it
- `knitr` - `Suggests`'d by vacalibration but required at runtime in v2.2 per Dockerfile comment (line 42)

**Notable gap:** `sodium` (Argon2id password hashing, `backend/auth/passwords.R`, `library(sodium)`) is used in the codebase but is **not** in the Dockerfile's explicit `install.packages()` lists. Verified 2026-08-18: it is present in the built image (sodium 1.4.0) and arrives **transitively via `plumber`**, the only installed package declaring it (`libsodium-dev` is installed at the OS/apt level, line 15, but the R package itself is never installed directly). This works today by accident: if `plumber` ever drops the dependency, `library(sodium)` at `backend/auth/passwords.R:4` fails at **runtime on the first login**, not at build time — the same unpinned-dependency failure mode as the RcppParallel/cmake outage (issue #123). Add `sodium` to the explicit install list.

**Infrastructure:**
- `html2canvas` 1.4 + `jspdf` 4.2 (frontend) - Client-side PDF/image export of job results
- `nginx:alpine` (frontend production image) - Serves the built SPA and reverse-proxies `/api` (see `frontend/Dockerfile` embedded nginx config)

## Dependency Pinning Status

**Backend R packages are installed UNPINNED from CRAN** in `backend/Dockerfile` (`install.packages(c(...), repos='https://cloud.r-project.org')` — no version arguments, no `renv.lock`, no `DESCRIPTION` with version constraints). This means every image rebuild pulls whatever is currently latest on CRAN for `plumber`, `jsonlite`, `uuid`, `future`, `RPostgres`, `pool`, `jose`, `rJava`, `openVA`, `EAVA`, `vacalibration`, and `knitr`.

This caused a 2-day production outage (tracked in issue #123): `RcppParallel`, a transitive dependency of openVA/EAVA, began requiring `cmake >= 3.5` in a CRAN release between 2026-07-28 and 2026-08-12, and the Dockerfile did not previously install `cmake`. The fix committed in `backend/Dockerfile` (lines 6-26) adds `cmake` (and `make`, `gcc`, `g++`) to the apt-get install list, but does **not** pin any R package versions — the underlying unpinned-dependency risk that caused the outage is unresolved and can recur with any other transitive dependency's future CRAN release.

**Frontend** dependencies are pinned via `frontend/package-lock.json` (npm), so JS dependency versions are reproducible; this pinning does not extend to the backend.

## Configuration

**Environment:**
- Loaded from `.env.local` (local dev) or `.env` (deployment fallback) via a hand-rolled parser in `backend/db/connection.R` (`load_env()`), checking current dir then parent dir for each file
- Root `.env` / `.env.local` files exist (contents not read — see forbidden-files policy) with variable **names**: `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE`, `PG_REMOTE_HOST`, `PG_REMOTE_PORT`, `SSH_HOST`, `SSH_USER`, `SSH_PASSWORD`, `UAT_URL`, `JWT_SECRET` (`.env`); `.env.local` has the same PG* and `JWT_SECRET` subset
- `UAT_URL` is documented in the project `CLAUDE.md` as an env var but is not referenced anywhere in `backend/`, `frontend/src/`, or CI workflow files — likely vestigial or reserved for a manual/undocumented workflow
- Frontend build-time config: `frontend/.env.production` sets `VITE_API_BASE_URL=/comsa-dashboard/api`, baked into the Vite bundle at build time
- Local dev frontend config: none needed — `frontend/src/api/client.js` defaults `API_BASE` to `http://localhost:8000` when `VITE_API_BASE_URL` is unset
- In k8s, backend secrets (`PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE` from `comsa-db-credentials`; `JWT_SECRET` from `comsa-jwt-secret`) are injected as env vars via `secretKeyRef` in `k8s/backend-deployment.yaml`

**Build:**
- `frontend/vite.config.js` - `base: '/comsa-dashboard/'` (must match the ingress path prefix), `define.__BUILD_TIME__` injected at build time, Vitest config co-located in the same file
- `frontend/eslint.config.js` - flat ESLint config, React 19 + hooks rules
- No `tsconfig.json` — frontend is JavaScript/JSX only, not TypeScript, despite `@types/react`/`@types/react-dom` devDependencies (used for editor IntelliSense only)

## Platform Requirements

**Development:**
- R >= 4.4 with the package set above installed locally (no automated setup script beyond the Dockerfile; `backend/README.md` documents manual `Rscript run.R`)
- Node.js (CI uses 20; Docker build uses 18 — use 20 locally to match CI, since that is the gate that runs `npm run build`/tests)
- Local PostgreSQL access via SSH tunnel to a remote/shared Postgres instance (`.claude/skills/comsa-postgresql/SKILL.md`: tunnel expected on `localhost:5433`, managed by `scripts/check_tunnel.sh`) — the database is not run in Docker/Compose locally
- `lsof -ti:8000` / `Rscript run.R` used to start the backend for local testing (per project `CLAUDE.md`)

**Production:**
- Deployment target: JHU IDIES `k8s-dev` Kubernetes cluster, namespace `comsa-dashboard` (`k8s/namespace.yaml`, pre-created by cluster admin)
- Images built and pushed to GitHub Container Registry (`ghcr.io/cliu238/comsa_dashboard-backend`, `-frontend`) via `.github/workflows/deploy.yml`
- Deployment mechanism: GitHub Actions SSHs through a JHU bastion (`dslogin01.pha.jhu.edu` → `k8slgn.idies.jhu.edu`) and runs `kubectl apply` + `kubectl rollout restart` against a pre-provisioned kubeconfig
- No persistent volume claim — namespace forbids one (per `backend/db/connection.R` comment) — backend pod filesystem is ephemeral; uploaded files are mirrored into Postgres (`job_input_files` table) to survive pod restarts
- Backend pod resources: 512Mi/250m requests, 2Gi/1000m limits (`k8s/backend-deployment.yaml`); frontend: 128Mi/100m requests, 256Mi/200m limits (`k8s/frontend-deployment.yaml`)
- Public URL: `https://dev.sites.idies.jhu.edu/comsa-dashboard` (frontend), `/comsa-dashboard/api/*` (backend, routed by `k8s/ingress.yaml`)

---

*Stack analysis: 2026-08-18*
