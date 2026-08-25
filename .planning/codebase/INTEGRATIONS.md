# External Integrations

**Analysis Date:** 2026-08-18

## APIs & External Services

No third-party SaaS APIs (payment, email, SMS, error tracking, analytics, etc.) are integrated. A repo-wide search for common integration markers (Sentry, Datadog, S3, SES/SMTP, SendGrid, Twilio, Stripe, Redis, Elasticsearch) and for outbound HTTP calls (`httr::`, `curl::`) in `backend/` returned no matches. The system is self-contained: React frontend → R plumber API → PostgreSQL, plus local invocation of the openVA/vacalibration R packages (no external network calls made by those packages at runtime in this codebase's usage).

**R Package Ecosystem (not runtime APIs, but external computational dependencies):**
- openVA + EAVA - Verbal autopsy cause-of-death coding algorithms (InterVA, InSilicoVA, EAVA), invoked via `codeVA()` in `backend/jobs/algorithms/openva.R`
  - SDK/Client: CRAN packages, installed unpinned (see `.planning/codebase/STACK.md`)
  - Auth: none (local R library call, no network)
- vacalibration (v2.2) - Bayesian calibration of cause-of-death classifications against a misclassification matrix, invoked in `backend/jobs/algorithms/vacalibration.R`
  - SDK/Client: CRAN package + bundled/recompiled Stan models (`rstan`)
  - Auth: none (local R library call, no network)

## Data Storage

**Databases:**
- PostgreSQL - Primary data store for job tracking, users, logs, and file metadata
  - Connection: `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE` env vars, loaded via `backend/db/connection.R` `load_env()`
  - Client: `RPostgres` driver + `pool::dbPool()` connection pool (min 0, max 10 connections), initialized lazily on first `get_db_pool()` call
  - Hosting: **externally hosted, not run inside the k8s cluster or in Docker Compose.** Local development reaches it over an SSH tunnel to port `5433` (`.claude/skills/comsa-postgresql/SKILL.md`, `scripts/check_tunnel.sh`); `.env` additionally defines `PG_REMOTE_HOST`/`PG_REMOTE_PORT`/`SSH_HOST`/`SSH_USER`/`SSH_PASSWORD` for that tunnel. In k8s, credentials are injected from the `comsa-db-credentials` Secret (`k8s/backend-deployment.yaml`) — the manifests only reference an existing DB, they do not provision one.
  - Schema: `backend/migrations/001_initial_schema.sql` (jobs, job_logs, job_files), `002_users.sql` (users, adds jobs.user_id), `003_input_file_storage.sql` (job_input_files — base64-mirrored uploads, see below). Migrations are plain `.sql` files with no migration-runner tooling found; `job_input_files` DDL is also re-applied idempotently at pool-init time via `ensure_input_file_storage()` in `backend/db/connection.R`.
  - Tables: `jobs` (status, algorithm params, JSONB `error`/`result`), `job_logs` (per-job log lines), `job_files` (output file registry), `job_input_files` (base64-encoded input CSV mirror, keyed by `job_id`+`filename`), `users` (auth)

**File Storage:**
- Local filesystem only — `backend/data/uploads/` and `backend/data/outputs/` (created by the Dockerfile: `mkdir -p /app/data/uploads /app/data/outputs`)
- **Ephemeral by design**: the k8s namespace forbids PersistentVolumeClaims (comment in `backend/db/connection.R`), so pod-local files vanish on every deploy/restart. Uploaded input CSVs are mirrored into Postgres (`job_input_files` table, base64-over-TEXT) and restored to disk on demand via `ensure_input_files()`/`restore_input_files()` when a job is rerun on a fresh pod (issue #110 per code comments). Output files (job results) are **not** mirrored this way and are lost on pod restart/redeploy unless downloaded by the user beforehand.

**Caching:**
- None. No Redis/Memcached; `pool` is a DB connection pool, not a cache layer.

## Authentication & Identity

**Auth Provider:**
- Custom, self-hosted — no third-party auth provider (no Auth0/Okta/Firebase/Cognito)
  - Implementation: JWT-based session auth
    - Passwords hashed with Argon2id via `sodium::password_store()` / `password_verify()` (`backend/auth/passwords.R`)
    - Tokens issued with `jose::jwt_encode_hmac()` (HMAC-SHA256), 24-hour expiry, claims `sub` (user_id), `email`, `role`, `iat`, `exp` (`backend/auth/tokens.R`)
    - Secret: `JWT_SECRET` env var, read lazily and cached in `get_jwt_secret()`; hard-fails (`stop()`) if unset
    - Enforcement: `@filter auth` in `backend/plumber.R` (see `backend/auth/middleware.R`), applied globally to all routes after the CORS filter
    - Endpoints: `POST /auth/register`, `POST /auth/login`, `GET /auth/me`, `PUT /auth/me` (`backend/plumber.R`)
    - Roles: `user` (default) and `admin`, enforced via a DB `CHECK` constraint (`backend/migrations/002_users.sql`) and used for job-visibility scoping (`tests/test_auth_visibility.R`)
    - Frontend: JWT stored in `localStorage` (`frontend/src/api/client.js` `getAuthHeaders()`), sent as `Authorization: Bearer <token>`; a 401 response clears the token and fires an `auth:logout` window event

## Monitoring & Observability

**Error Tracking:**
- None (no Sentry or equivalent). Errors surface via plumber's JSON error responses and are logged to the `job_logs` table (per-job) or `backend.log` (raw stdout capture, present at repo root — not a structured logging service).

**Logs:**
- Application/job logs: written to the `job_logs` Postgres table via `add_log(job_id, message)` (`backend/db/connection.R`), retrieved per job via `get_job_logs()` and surfaced through `GET /jobs/<job_id>/log`
- Server process logs: plain stdout/stderr from the plumber process (captured to `backend.log`/`frontend.log` when run locally in the background per project conventions)

## CI/CD & Deployment

**Hosting:**
- JHU IDIES `k8s-dev` Kubernetes cluster (see `.planning/codebase/STACK.md` for full deployment details)
- Container registry: GitHub Container Registry (`ghcr.io/cliu238/comsa_dashboard-backend`, `ghcr.io/cliu238/comsa_dashboard-frontend`)

**CI Pipeline:**
- GitHub Actions, two workflows:
  - `.github/workflows/test.yml` - runs on PRs and pushes to `master`: frontend job (npm ci, vitest excluding `api/integration.test.js`, production build) and backend job (base-R-only tests: `tests/test_misclass_matrix.R`, `tests/test_auth_visibility.R`, `tests/test_input_persistence.R`)
  - `.github/workflows/deploy.yml` - runs on push to `master`: path-filtered Docker builds (only rebuilds the image whose directory changed), pushes to GHCR, then SSHs through a JHU bastion host to run `kubectl apply`/`kubectl rollout restart` against the `k8s-dev` cluster
- Deploy auth: `secrets.K8S_SSH_PRIVATE_KEY` (base64-encoded SSH private key, decoded and loaded into `ssh-agent` with agent forwarding), `secrets.GITHUB_TOKEN` for GHCR login

## Environment Configuration

**Required env vars (names only, no values read):**
- `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE` - PostgreSQL connection
- `JWT_SECRET` - JWT signing secret (hard requirement; server calls will fail without it)
- `PG_REMOTE_HOST`, `PG_REMOTE_PORT`, `SSH_HOST`, `SSH_USER`, `SSH_PASSWORD` - local-dev-only SSH tunnel to remote Postgres (`.env` only, not `.env.local`)
- `UAT_URL` - documented in project `CLAUDE.md` but not referenced anywhere in `backend/` or `frontend/src/`; appears unused/vestigial
- `VITE_API_BASE_URL` - frontend build-time API base path (`frontend/.env.production`)
- `PORT` - backend listen port, defaults to `8000` if unset (`backend/run.R`)
- `COMSA_WORKER` - internal flag (`"1"` for background job workers) that skips orphaned-job cleanup on pool init, so it only runs once from the main server (`backend/db/connection.R`)

**Secrets location:**
- Local development: `.env.local` (preferred) or `.env` (fallback), loaded via a hand-rolled parser in `backend/db/connection.R`; both files exist at repo root (not committed — confirm via `.gitignore`) and are excluded from this analysis's content review per policy
- Production (k8s): Kubernetes Secrets `comsa-db-credentials` and `comsa-jwt-secret`, referenced via `secretKeyRef` in `k8s/backend-deployment.yaml`; not created by any manifest in this repo (provisioned out-of-band by a cluster admin)
- CI: GitHub Actions repository secrets `K8S_SSH_PRIVATE_KEY`, `GITHUB_TOKEN` (the latter is the default Actions token)

## Webhooks & Callbacks

**Incoming:**
- None. No webhook receiver endpoints found in `backend/plumber.R`.

**Outgoing:**
- None. No outbound webhook calls found in `backend/` or `frontend/src/`.

---

*Integration audit: 2026-08-18*
