# Coding Conventions

**Analysis Date:** 2026-08-18

## Project-Wide Rules (from `CLAUDE.md`)

These are stated, binding rules for this repository — treat them as the highest-priority conventions when writing or reviewing any code here:

- **Use `uv`** to install packages and manage the Python environment (applies to the Python test/skill scripts under `.claude/skills/`).
- **Simplest code and structure — no over-engineering.** Prefer the smallest change that solves the stated problem.
- **No unnecessary files.** When creating a new version of a file, archive or delete the legacy one rather than leaving both.
- **No feature creep.** Only implement what's explicitly requested. Keep logging minimal (see `add_log()` calls in `backend/jobs/processor.R` for the expected level of verbosity — one line per pipeline step, not per-record).
- **No silent test skips.** A test that needs an external dependency (backend, DB) must auto-start it or fail loudly — never silently skip. `frontend/src/api/integration.test.js` is the canonical example: its `beforeAll` auto-starts the R backend with `spawn('Rscript', ['run.R'], ...)` if `/health` isn't already responding, and throws if it fails to come up within 30s.
- **Write the edge-case test before the fix.** When a plan identifies edge cases or boundary conditions, add a unit test for each before implementing. "All tests pass" only proves existing tests pass.
- **Verify, don't trust.** Do not rely on documentation or assumptions for critical values (service names, data formats, API behavior) — check actual source or runtime output. Many source-level comments in this codebase exist specifically to record such a verified fact (e.g. the plumber form-parsing behavior noted in `frontend/src/api/client.js:104-109`).

## Naming Patterns

**Frontend files (`frontend/src/`):**
- React components: PascalCase `.jsx` — `JobForm.jsx`, `MisclassificationMatrix.jsx`, `CausePreview.jsx`.
- Pure-JS view-model / utility modules: PascalCase or camelCase `.js` with no JSX — `CSMFChart.js` (chart data builders), `matrixUtils.js`, `causeDisplay.js`, `labels.js`, `datetime.js`, `export.js`.
- Test files: `<SourceName>.test.js` / `.test.jsx` (vitest) — see [Test File Organization](#test-file-organization) in TESTING.md for the full naming scheme including `.issueNN.` and `.behavior.` suffixes.
- Playwright E2E specs: `<flow-name>.spec.js` under `frontend/e2e/` — kebab-case, distinct extension from vitest's `.test.js` so `vite.config.js`'s `exclude: ['e2e/**']` and glob-based tooling can tell them apart.

**Backend files (`backend/`):**
- R scripts: snake_case — `plumber.R`, `jobs/processor.R`, `jobs/algorithms/vacalibration.R`, `auth/middleware.R`.
- R test scripts: `test_<subject>.R` — `tests/test_vacalibration_backend.R`, `tests/test_misclass_matrix.R`, `tests/test_auth_visibility.R`, `tests/test_input_persistence.R`, `backend/test_db_integration.R`.

**Functions:**
- **JavaScript:** camelCase — `formatAlgorithmList`, `buildCsmfTableRows`, `getCellColor`, `exportCombinedPDF`. Async API-client functions are verbs: `submitJob`, `getJobStatus`, `previewMapping`.
- **R:** snake_case — `fix_causes_for_vacalibration`, `safe_cause_map`, `build_stall_fields`, `extract_misclass_matrix`. A leading dot marks an internal/private helper not meant to be called from outside its module, e.g. `.declared_not_calibrated`, `.passthrough_not_calibrated`, `.keep_causes`, `.build_misclass_entry` in `backend/jobs/utils.R`.
- **R parameter-validation helpers** follow a `<verb>_<noun>` pattern that also documents their contract: `param_scalar`, `require_enum`, `optional_enum`, `optional_count`, `optional_flag`, `require_algorithms` (`backend/jobs/utils.R`). Use this pattern for any new POST `/jobs`-style parameter rather than inlining ad hoc `if`/`stop()` checks.

**Variables:**
- JS: camelCase for local/state variables; `useState` pairs follow `[thing, setThing]` — `const [algorithms, setAlgorithms] = useState(['InterVA'])` (`frontend/src/components/JobForm.jsx`).
- Constants that are lookup tables/enums are `UPPER_SNAKE_CASE` at module scope: `ALGORITHM_DISPLAY_ORDER`, `SUPPORTED_CAUSES`, `JOB_TYPE` (`frontend/src/components/JobForm.jsx`); `ALGORITHM_NAMES`, `AGE_GROUP_LABELS` (`frontend/src/utils/labels.js`).
- R: snake_case throughout — `job_id`, `age_group`, `calib_model_type`, `n_mcmc`.

**Types:** No TypeScript in this codebase — plain JS/JSX with no `PropTypes` either (grep across `frontend/src` for `PropTypes` returns nothing). Component contracts are documented by usage/comments, not by a type-checking layer. Match this — do not introduce TypeScript or PropTypes for a single component; it would be inconsistent with the rest of the codebase and violates the "simplest code" rule.

## Code Style

**Formatting:**
- No Prettier config present (`frontend/.prettierrc*` does not exist). Formatting is whatever ESLint's `js.configs.recommended` allows plus 2-space indentation observed throughout `frontend/src`. Follow the surrounding file's indentation rather than introducing a new formatter.

**Linting:**
- Tool: ESLint 9 flat config, `frontend/eslint.config.js`.
- Extends `js.configs.recommended`, `reactHooks.configs.flat.recommended`, `reactRefresh.configs.vite`.
- Custom rule: `'no-unused-vars': ['error', { varsIgnorePattern: '^[A-Z_]' }]` — an unused variable starting with an uppercase letter or underscore (e.g. a placeholder destructure) will not fail lint.
- Run: `cd frontend && npm run lint`.
- As of this analysis, `npm run lint` reports 4 errors (2 `no-undef` on `process` in `src/api/integration.test.js`, 1 `react-hooks/set-state-in-effect` and 1 `react-refresh/only-export-components` in `src/auth/AuthContext.jsx`) — treat a clean `npm run lint` as the bar for new/touched files, but note these pre-existing failures are not yet fixed elsewhere.

**R style:** No `styler`/`lintr` config found. Convention observed in `backend/jobs/utils.R` and `backend/plumber.R`: 2-space indent, `<-` for assignment (not `=`), `sprintf()` for formatted error/log strings, explicit `call. = FALSE` on most `stop()` calls used for user-facing validation errors (keeps the traceback out of the message returned to the API caller).

## Import Organization

**JS import order** (observed in `frontend/src/components/JobForm.jsx`, `JobDetail.jsx`):
1. React / external packages — `import { useState, useEffect } from 'react'`
2. Sibling/local module imports — API client (`'../api/client'`), then components (`'./ProgressIndicator'`, `'./CustomSelect'`)
3. No path aliases are configured (no `jsconfig.json`/`vite.config.js` `resolve.alias`) — all internal imports use relative paths (`../api/client`, `./export.js`).

**R "imports"** are `library()` calls at the top of `plumber.R`, followed by `source()` calls for local modules in dependency order (db connection → job processor → auth):
```r
library(plumber)
library(jsonlite)
library(uuid)
source("db/connection.R")
source("jobs/processor.R")
source("auth/users.R")
source("auth/middleware.R")
```
New backend modules should be `source()`d from `plumber.R` in the same place other modules of their kind are (db helpers near other db helpers, job logic near `jobs/processor.R`, etc.) rather than added ad hoc.

## Error Handling

**Frontend:**
- `frontend/src/api/client.js`'s `fetchJson()` is the single chokepoint for API errors: on `res.status === 401` it clears the stored token and dispatches a `window.dispatchEvent(new Event('auth:logout'))`; on any non-OK response it throws `new Error(data.error || `Request failed (${res.status})`)`. Callers catch this in a component-local `try/catch` and set an `error` state variable that's rendered inline (see `JobForm.jsx`, `JobDetail.jsx`).
- Component-level failures are caught and logged with `console.error('<Verb phrase>:', err)` (no logging library) then surfaced to the user via state, never left to bubble to an unhandled rejection. See `frontend/src/components/JobDetail.jsx:23,33,44`, `JobForm.jsx:74`, `JobList.jsx:30,48`.
- Utility functions that talk to browser APIs (canvas/PDF export) fail soft: `frontend/src/utils/export.js` catches internally, `console.error`s a specific message, and returns/no-ops rather than throwing into the calling component — this is why `exportToPDF(null, ...)` "rejects" without throwing (see `frontend/src/utils/export.test.js` `'rejects with invalid element ref'`).

**Backend (R):**
- Parameter validation uses `stop(sprintf(...), call. = FALSE)` with a message written for the end API caller (states the parameter name, what was received, and what's valid) — see `require_enum`, `optional_count`, `require_algorithms` in `backend/jobs/utils.R:427-519`. Follow this exact style — actionable, specific, no stack trace — for any new required/optional job parameter.
- Plumber endpoint handlers wrap parameter resolution in `tryCatch(list(value = ...), error = function(e) list(error = conditionMessage(e)))` and check `if (!is.null(resolved$error)) return(list(error = resolved$error))` **after** the `tryCatch` returns, rather than calling `return()` from inside the error handler itself. This is a deliberate, commented pattern (`backend/plumber.R:218-238`) — `return()` inside a plumber handler's inner error callback only exits that callback, not the whole handler, so this shape must be preserved when adding new POST `/jobs`-style endpoints.
- Computation-layer errors (openVA/vacalibration failures) are recorded via `add_log(job$id, ...)` (`backend/db/connection.R:306`) so they're visible in the job's log stream, not just the process's stdout.

## Logging

**Frontend:** `console.error(...)` only, no logging library. Used exclusively for caught exceptions that are also surfaced to the user via component state — not for routine tracing.

**Backend:** Two channels, used for different audiences:
- `add_log(job_id, message)` (`backend/db/connection.R`) — persists a line to the `job_logs` DB table, shown to the end user in the job's progress/log view. Used throughout `backend/jobs/processor.R` for pipeline milestones (`"Starting pipeline: openVA -> vacalibration"`, `"=== Step 1: openVA ==="`, `"Calibration complete"`). One line per pipeline stage, not per record — matches the "keep logging minimal" rule in `CLAUDE.md`.
- `message(...)` — R's base stderr logging, used for process/operator-facing diagnostics that are not part of a specific job's log (e.g. `"Failed to start background runner: ..."` in `backend/jobs/run_job.R`, or the `File save error: ` fallback in `backend/plumber.R:50`).

## Comments

**When to comment:** Comments in this codebase are overwhelmingly "why", not "what" — nearly every non-trivial block references the GitHub issue number that motivated it and explains the bug or constraint being guarded against, not just what the code does. Examples:
- `frontend/src/components/JobForm.jsx:9-11`: explains *why* individual-record input/output was removed (issue #79), not just that it was.
- `frontend/src/api/client.js:104-109`: documents a verified, non-obvious fact about plumber's multipart form parser (age_group must go in the query string, not the form body) with the issue number (#105) that surfaced it.
- `backend/plumber.R:210-220`: explains why job-defining parameters are never given silent defaults, referencing issue #105.
- R test files open with a block comment stating the specific defect being regression-tested and why the suite is written the way it is (e.g. `tests/test_auth_visibility.R:1-9` explains the exact `curl` command and response that proved the bug, and why the suite is "deliberately dependency-free").

New code that fixes a bug or closes an issue should follow this pattern: comment references the issue number and explains the failure mode being prevented, not just describes the fix.

**JSDoc/TSDoc:** Used sparingly, only on a handful of utility modules, as a short header describing the module's single responsibility rather than per-function `@param`/`@returns` blocks:
```js
/**
 * Display-label helpers for algorithm and age-group names.
 * Single source of truth so the summary, figures, and tables stay consistent.
 */
```
(`frontend/src/utils/labels.js:1-4`). Individual exported functions get a one-line `/** ... */` only when the name alone doesn't convey intent, e.g. `/** Format one algorithm or an array of them as a comma-separated proper-name list. */` above `formatAlgorithmList`. Do not add full JSDoc param/return blocks — it's inconsistent with the rest of the codebase.

## Function Design

**Size:** Functions are kept small and single-purpose on the R side (most under ~30 lines in `backend/jobs/utils.R`); React components are larger (`JobForm.jsx`, `JobDetail.jsx` are several hundred lines) because they hold all of a page's local state and handlers — sub-behavior is extracted into plain-function helpers in `utils/` (e.g. `matrixUtils.js`, `causeDisplay.js`, `labels.js`) rather than into further sub-components, keeping one component per "page section."

**Parameters:** JS API-layer functions take a single destructured options object rather than positional args — `submitJob({ uploads, jobType, algorithms, ageGroup, country, calibModelType, ensemble, nMCMC, nBurn, nThin })` (`frontend/src/api/client.js:52`). Pure utility functions take positional args when there are few of them (`formatCauseDisplay(cause, displayNames)`, `getCellColor(value)`).

**Return values:** R validation helpers return the validated/coerced value directly (not a status object) and signal failure by throwing via `stop()` — callers do not need to check a boolean. Functions that must report a soft failure without throwing (e.g. `build_stall_fields`) return a plain list with a `warning` field the caller checks explicitly (`if (!is.null(stall_fields$warning)) add_log(...)`).

## Module Design

**Exports:**
- JS utility/API modules use **named exports** exclusively (`export function unbox(...)`, `export async function submitJob(...)`) — no default export except for React components (`export default function JobForm(...)`).
- No barrel files (`index.js` re-export aggregators) — every import references the concrete file directly (`import { submitJob } from '../api/client'`, not from a package-style index). Keep this — do not add an `index.js` aggregator to `components/`, `utils/`, or `api/`.

**R modules:** Each `.R` file under `backend/jobs/`, `backend/auth/`, `backend/db/` is `source()`d directly into the plumber process's global environment (no package structure, no namespacing) — function names must therefore be unique across the whole backend. Check `backend/jobs/utils.R` before naming a new top-level helper to avoid a silent override.

---

*Convention analysis: 2026-08-18*
