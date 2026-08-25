# Testing Patterns

**Analysis Date:** 2026-08-18

## Test Framework

This codebase has **two independent test stacks** — a JS/Vitest stack for the frontend and a hand-rolled R test-runner stack for the backend. There is no `testthat` anywhere in the repo (verified: no `library(testthat)` in any `tests/*.R` or `backend/*.R` file).

**Frontend runner:**
- Vitest 4.0.18 (`frontend/package.json` devDependency), config embedded in `frontend/vite.config.js` under the `test:` key (no separate `vitest.config.js`).
- Assertion API: Vitest's built-in `expect` (Jest-compatible), plus `@testing-library/react` 16.3.2 for the DOM-rendering tests and `jsdom` 28.1.0 as the DOM environment.
- Config (`frontend/vite.config.js`):
  ```js
  test: {
    environment: 'node',
    globals: true,
    exclude: ['e2e/**', 'node_modules/**'],
  }
  ```
  Default environment is **`node`**, not `jsdom` — most `.test.js` files are pure-function tests that need no DOM. Files that render components opt into a DOM via a per-file pragma comment: `/** @vitest-environment jsdom */` at the top (see `JobForm.behavior.test.jsx`, `MisclassificationMatrix.issue104.behavior.test.jsx`).

**Backend runner:** A ~15-line hand-rolled `test(desc, expr)` / `section(title)` helper duplicated (with minor variations) at the top of each `tests/*.R` file — not a shared library, not testthat. Pattern:
  ```r
  .test_count <- 0L; .pass_count <- 0L; .fail_count <- 0L; .fail_msgs <- character()
  test <- function(desc, expr) {
    .test_count <<- .test_count + 1L
    result <- tryCatch({
      ok <- eval(expr, envir = parent.frame())
      if (!isTRUE(ok)) stop("assertion returned FALSE")
      .pass_count <<- .pass_count + 1L
      cat(sprintf("  PASS: %s\n", desc))
    }, error = function(e) {
      .fail_count <<- .fail_count + 1L
      .fail_msgs <<- c(.fail_msgs, sprintf("  FAIL: %s -- %s", desc, e$message))
      cat(.fail_msgs[length(.fail_msgs)], "\n")
    })
  }
  section <- function(title) cat(sprintf("\n=== %s ===\n", title))
  ```
  Exit code: `quit(status = 1)` on any failure, `quit(status = 0)` on all-pass — this is what lets `Rscript tests/test_X.R` be used as a CI/pre-commit gate without a separate assertion-parsing step.

**Run Commands:**
```bash
# Frontend — MUST be run from inside frontend/, see "Critical Gotcha" below
cd frontend && npm test              # vitest run — all *.test.js/.test.jsx, one-shot
cd frontend && npm run test:watch    # vitest (watch mode)
cd frontend && npm run lint          # eslint .
cd frontend && npm run build         # vite build (production build check)

# Playwright E2E (frontend/e2e/*.spec.js — separate from vitest)
cd frontend && npm run test:e2e      # playwright test, headless, requires backend on :8000
cd frontend && npm run test:e2e:ui   # playwright test --ui

# Backend — R, run from project root (or backend/, both paths are auto-detected)
Rscript tests/test_vacalibration_backend.R                # full, ~2-5 min (real MCMC)
Rscript tests/test_vacalibration_backend.R --input-only    # skips MCMC, <10s
Rscript tests/test_misclass_matrix.R
Rscript tests/test_auth_visibility.R
Rscript tests/test_input_persistence.R
Rscript backend/test_db_integration.R   # needs a live Postgres + backend/.env.local

# Cross-cutting checks
python3 .claude/skills/test/scripts/check_integration.py --project-root .   # static frontend/backend endpoint diff
python3 .claude/skills/test/scripts/test_backend.py                         # live HTTP tests, needs backend on :8000
```

## CRITICAL GOTCHA: `npx vitest run` must be invoked from inside `frontend/`

Confirmed by running both ways during this analysis:

- **`cd frontend && npx vitest run`** → resolves the project-local Vitest (`frontend/node_modules`), reads `frontend/vite.config.js` (whose `exclude: ['e2e/**']` keeps Playwright specs out), and correctly collects **34 test files / 315 tests, all passing**.
- **`npx vitest run` from the repo root** → npx cannot find a local `vitest` binary at the root, so it falls back to a *different, globally npx-cached* Vitest version. That version has no `vite.config.js` to read (so `e2e/**` is **not** excluded) and no local `jsdom`/`@testing-library` installed. Result: it tries to collect `frontend/e2e/*.spec.js` as Vitest tests and fails immediately (`Error: Playwright Test did not expect test.beforeAll() to be called here` — a `.spec.js` file using Playwright's `test.beforeAll` is being loaded by Vitest), and every `jsdom`-environment `.test.jsx` file also fails with `Cannot find package 'jsdom'`. Net effect from the root: **2 failed suites, 12 unhandled errors**, and the passing-test count silently drops because jsdom-dependent suites never load.

**Rule:** always `cd frontend` (or use `npm test` / `npm run test:watch`, which are already scoped via `package.json`) before invoking Vitest directly. Never run bare `npx vitest run` from the repository root.

CI (`.github/workflows/test.yml`) avoids this entirely by setting `working-directory: frontend` for the whole job and running `npx vitest run --exclude '**/api/integration.test.js'` (excludes only the live-backend integration test; e2e is already excluded by `vite.config.js`).

## Test File Organization

**Location:** Co-located — every `*.test.js`/`*.test.jsx` sits next to the source file it tests, in the same directory (`frontend/src/components/JobForm.jsx` + `JobForm.test.js` + several more `JobForm.*.test.js(x)` files). Playwright specs are the one exception, living in a dedicated `frontend/e2e/` directory (kept separate because they need a running dev server + backend, unlike everything else in `src/`).

**Naming:** Three suffix conventions, and they mean different things — check which one you're extending before assuming the pattern:
- `<Component>.test.js(x)` — the "main" or original test file for that source file (e.g. `JobForm.test.js`, `CSMFChart.test.js`, `JobDetail.test.js`).
- `<Component>.issueNN.test.js(x)` — a **new** test file added specifically to pin down a fix for GitHub issue #NN (e.g. `JobForm.issue68.test.js`, `client.issue105.test.js`, `MisclassificationMatrix.issue104.behavior.test.jsx`). These are never merged back into the main file — they stay as standalone regression markers referencing the issue.
- `.behavior.test.jsx` suffix — signals the file uses `@testing-library/react` to actually **render** the component and simulate user interaction (`fireEvent`), as opposed to a plain `.test.js` file that imports pure functions or does source-text assertions. `.jsx` extension also correlates with "renders JSX," `.js` with "no rendering."
- `<file>.source.test.js` — a source-assertion-only file, see next section.

**Structure:** No `__tests__/` directories; no separate `test/` or `tests/` tree inside `frontend/src`. Everything lives beside its source file, grouped by feature area (`components/`, `utils/`, `api/`, `pages/`, `content/`, and a few root-level files like `App.routes.test.js`, `branding.test.js`, `main.basename.test.js` next to `App.jsx`/`main.jsx`).

## Test Structure

**Suite organization** — standard `describe`/`it` nesting, grouped by feature/issue rather than by function-under-test when a change spans multiple behaviors:
```js
describe('Ensemble vs independent multi-algorithm indicator (issue #83)', () => {
  it('bases the ensemble indicator on the actual ensemble flag, not algorithm count', () => {
    expect(jobDetailSrc).toContain("results.ensemble === true")
    expect(jobDetailSrc).not.toMatch(/isEnsemble\s*=\s*Array\.isArray\(results\.algorithm\)\s*&&.../)
  })
  ...
})
```
(`frontend/src/components/JobDetail.test.js`)

R suites use `section("N. Title")` as a lightweight, numbered table-of-contents printed to stdout, with related `test()` calls grouped underneath — `tests/test_vacalibration_backend.R` has 38 numbered sections (1 through 28, several with letter suffixes like `2b`, `12c`, `14b` for sub-cases added later without renumbering everything).

**Patterns:**
- **Setup:** `beforeEach(() => { vi.clearAllMocks() })` when a suite mocks the API client (`JobForm.behavior.test.jsx`); `vi.hoisted(...)` + `vi.mock(...)` at module top-level for mocking third-party libraries so the mock is available before the `import` of the module under test runs (`export.test.js`).
- **Teardown:** `afterEach(() => { vi.unstubAllGlobals() })` after `vi.stubGlobal('alert', ...)`, specifically because Vitest reuses workers across test files and a leaked global stub can bleed into unrelated tests (`export.test.js:139`).
- **Assertion style:** plain `expect(...).toBe/toEqual/toContain/toMatch(...)`; no custom matchers or snapshot testing anywhere in the codebase (`toMatchSnapshot` does not appear).

## Mocking

**Framework:** Vitest's built-in `vi.mock` / `vi.fn` / `vi.hoisted` / `vi.stubGlobal` / `vi.useFakeTimers`. No separate mocking library (no `sinon`, no `msw`).

**Patterns:**

1. **Mocking the internal API client** (for UI-behavior tests that must not hit a network) — module-level `vi.mock` with inline fake implementations:
   ```js
   vi.mock('../api/client', () => ({
     submitJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
     submitDemoJob: vi.fn(() => Promise.resolve({ job_id: 'stub' })),
     getJobStatus: vi.fn(() => Promise.resolve({ status: 'completed' })),
     getJobLog: vi.fn(() => Promise.resolve({ log: [] })),
     previewMapping: vi.fn(() => Promise.resolve({ reports: {} })),
   }))
   ```
   (`frontend/src/components/JobForm.behavior.test.jsx`, repeated per-file rather than shared via a fixture — see Test Coverage Gaps below.)

2. **Mocking third-party libraries with call-order-sensitive setup** — `vi.hoisted()` lifts mock factories above the `import`, required because `vi.mock` calls are themselves hoisted by Vitest but a mock that needs a *reference* to a `vi.fn()` (to assert on calls later) must create that `vi.fn()` before the mock factory runs:
   ```js
   const { html2canvasMock } = vi.hoisted(() => ({ html2canvasMock: vi.fn() }))
   vi.mock('html2canvas', () => ({ default: html2canvasMock }))

   const { jsPDFMock, pdfInstance } = vi.hoisted(() => {
     const inst = { internal: { pageSize: { getWidth: () => 595, getHeight: () => 842 } },
                     addImage: vi.fn(), addPage: vi.fn(), save: vi.fn() }
     return { jsPDFMock: vi.fn(function () { return inst }), pdfInstance: inst }  // regular fn so `new` works
   })
   vi.mock('jspdf', () => ({ jsPDF: jsPDFMock }))
   ```
   (`frontend/src/utils/export.test.js:4-17`)

3. **Mocking `fetch` directly** for API-client unit tests (no MSW, just a raw `vi.fn()` assigned to `globalThis.fetch`):
   ```js
   const mockFetch = vi.fn().mockResolvedValue({
     ok: true, status: 200,
     json: () => Promise.resolve({ job_id: 'test-123', status: 'pending' })
   });
   globalThis.fetch = mockFetch;
   const { submitJob } = await import('./client.js');
   await submitJob({ ... });
   const [url, options] = mockFetch.mock.calls[0];
   ```
   (`frontend/src/api/client.test.js:78-107`) — dynamic `await import('./client.js')` after setting the mock ensures the module reads the mocked global.

4. **Fake timers** for deterministic date-based filenames:
   ```js
   vi.useFakeTimers()
   vi.setSystemTime(new Date('2024-06-15'))
   const result = generateFilename('csmf_table', 'InterVA', 'abcd1234-5678', 'csv')
   expect(result).toBe('csmf_table_InterVA_abcd1234_20240615.csv')
   vi.useRealTimers()
   ```
   (`frontend/src/utils/export.test.js:19-26`)

**What to mock:** External/browser-only APIs (`html2canvas`, `jspdf`, `fetch`, `alert`, `localStorage` via jsdom) and the internal `api/client` module when testing pure UI behavior that should not depend on network timing.

**What NOT to mock:** Pure utility/view-model functions (`unbox`, `formatCauseDisplay`, `buildCsmfTableRows`, `matrixUtils` helpers) are tested directly with real inputs/outputs — no mocking layer. The one live-backend suite (`integration.test.js`) deliberately does **not** mock the backend at all — it is the one test file whose entire purpose is to prove the real HTTP contract holds.

## Source-Assertion Testing (notable, non-standard pattern)

A significant fraction of the frontend suite does not render components at all. Instead it `readFileSync`s the component's own source file and asserts on its text content:

```js
import { readFileSync } from 'fs'
import { resolve, dirname } from 'path'
import { fileURLToPath } from 'url'

const __dir = dirname(fileURLToPath(import.meta.url))
const jobDetailSrc = readFileSync(resolve(__dir, 'JobDetail.jsx'), 'utf-8')

describe('CSMF full name display (issue #28)', () => {
  it('OpenVA results heading uses full name "Cause-Specific Mortality Fractions (CSMF)"', () => {
    expect(jobDetailSrc).toContain('Cause-Specific Mortality Fractions (CSMF)')
  })
})
```
(`frontend/src/components/JobDetail.test.js`, 23 tests, all of this style; also `JobForm.source.test.js`, and an equivalent R-side pattern in `tests/test_vacalibration_backend.R`'s final sections which `readLines()` and `grepl()` over `backend/jobs/algorithms/vacalibration.R` / `backend/jobs/processor.R`.)

**Why this pattern exists:** `JobDetail.jsx` needs real job-result data (a completed calibration run, or a fully-shaped mock of one) and a DOM harness to render meaningfully; several of the behaviors being pinned down (exact wording, section ordering, which refs are wired up for PDF export) are cheaper and more precise to assert as source-text checks than to reconstruct via a full render + a large results fixture. `tests/test_vacalibration_backend.R`'s equivalent block is explicit about the same tradeoff: *"Source assertions rather than a live run: reaching result_obj needs a DB and a multi-minute MCMC, so this is the same style used in JobDetail.test.js."*

**The risk — be aware of this when adding or modifying source-assertion tests:** a whole-file `toContain`/`grepl` check passes as long as the string exists **anywhere** in the file. It does not verify the string is reachable, rendered in the right branch, or even still live code (e.g. it would still pass if the string were moved into a comment, an unreachable `if (false)` branch, or a different, unrelated component that happens to share the file). When adding a new source-assertion test, prefer the stronger idioms already used in this file — comparing `indexOf` positions to assert ordering (`JobDetail.test.js:57-63`), or slicing a bounded window after a matched anchor before asserting on it (`JobDetail.test.js:132-135`, `unreliableBlock = jobDetailSrc.split('facet.ciUnreliable && (')[1].slice(0, 500)`) — rather than a bare `toContain` when precision matters.

## Fixtures and Factories

**No shared/dedicated fixtures directory.** Test data is inlined per-file:
- API-client tests build `File` objects inline: `new File(['data'], 'interva.csv')` (`client.test.js`).
- Component behavior tests use small inline mock result objects rather than a shared factory function.
- The R suite reads the **real** sample CSVs shipped to the app (`frontend/public/sample_interva_neonate.csv`, `sample_insilicova_neonate.csv`, `sample_eava_neonate.csv`) and the real RDS files under `backend/data/sample_data/` — these double as both demo-mode data and test fixtures, so a change to a sample file is implicitly a test-data change too (see `tests/test_vacalibration_backend.R` section 1, which asserts on exact row counts of these files, e.g. 1190 InterVA/InSilicoVA records, 940 EAVA records after "Unspecified" rows were removed for issue #92).

**Location:** N/A as a distinct concept — see above. `tests/files/` exists but currently holds untracked `.numbers` (Apple Numbers spreadsheet) source files, not consumed by any test script.

## Coverage

**Requirements:** No coverage tool configured (no `@vitest/coverage-v8`/`c8` in `devDependencies`, no `coverage` script in `package.json`). No enforced threshold anywhere in CI.

**View Coverage:** Not currently available; would require adding `@vitest/coverage-v8` and a `vitest run --coverage` script.

## Test Types

**Unit tests (frontend):** The majority of the suite — pure-function tests for `utils/*.js` (`progress.test.js`, `causeDisplay.test.js`, `labels.test.js`, `datetime.test.js`, `export.test.js`) and view-model builder tests for chart/table/matrix logic (`CSMFChart.test.js`, `MisclassificationMatrix.test.js`). No DOM.

**Component/behavior tests (frontend):** `@testing-library/react` render + `fireEvent` tests, environment pragma'd to `jsdom` (`JobForm.behavior.test.jsx` and its `.issueNN.behavior.test.jsx` siblings, `CausePreview.test.jsx`, `ProgressIndicator.test.jsx`, `VideosSection.test.jsx`, `AcknowledgmentPage.test.jsx`, `ResourcePage.test.jsx`).

**Source-assertion tests (frontend + backend):** See dedicated section above — `JobDetail.test.js`, `JobForm.source.test.js`, and the final sections of `tests/test_vacalibration_backend.R`.

**Integration tests (frontend→backend):** `frontend/src/api/integration.test.js` — the **only** frontend test file that talks to a real, running R plumber backend over HTTP. Auto-starts `Rscript run.R` in `backend/` if `GET {API_BASE}/health` isn't already responding, waits up to 30s, and tears the spawned process down in `afterAll`. Explicitly excluded from the CI unit-test run (`npx vitest run --exclude '**/api/integration.test.js'`) because CI has no R/vacalibration environment; run locally instead.

**Unit tests (backend, R):** `tests/test_vacalibration_backend.R` is the primary backend suite — input validation, cause-mapping compatibility, CSV/RDS consistency, actual vacalibration computation (single, ensemble, Mmatprior/Mmatfixed), output-structure and numeric-correctness checks against a golden dataset, edge cases, and several source-assertion regression sections. Supports `--input-only` to skip the MCMC-heavy sections (see `if (input_only) { ... } ... if (!input_only) { ... }` gating around line 803–1480).

Two smaller, deliberately dependency-free R suites exist specifically so they can run without the `vacalibration`/`rstan` toolchain (and therefore run in CI): `tests/test_auth_visibility.R` (job-visibility/authorization logic in `job_visibility()`) and `tests/test_input_persistence.R` (base64 file-persistence round-trip in `encode_file_b64`/`decode_b64_to_file`). Both `source()` only `backend/jobs/utils.R`, no DB, no JWT library, no plumber.

`tests/test_misclass_matrix.R` verifies the misclassification-matrix numbers emitted by the app against values obtained by running R directly (a "golden number" comparison), and checks for `NA`/`NaN`/`Inf`/serialization issues.

**Database integration tests:** `backend/test_db_integration.R` — needs a live PostgreSQL instance and `backend/.env.local` credentials; not run by CI (`.github/workflows/test.yml` has no DB job).

**Backend API tests (Python, not vitest/R):** `.claude/skills/test/scripts/test_backend.py` — a `requests`-based `BackendTester` class exercising every plumber endpoint end-to-end (health, job listing, demo submission, polling, log retrieval, results, error handling) against a live server on `localhost:8000`. Own pass/fail/warn counters, colored terminal output, no pytest.

**Frontend/backend contract check (Python, static):** `.claude/skills/test/scripts/check_integration.py` — parses `backend/plumber.R` and `frontend/src/api/client.js` directly (regex/text based, no servers needed) to catch endpoint or parameter drift between the two. As of this analysis it reports the check **FAILED**, but the single hard failure is a **false positive in the script, not an integration bug** (verified 2026-08-18): it flags `GET /admin/users/{param}` as uncalled, yet `frontend/src/api/client.js:190-196` sends it with `method: 'PUT'` and `backend/plumber.R:823` declares `#* @put /admin/users/<user_id>` — the two match. The script extracts URLs but does not parse the `method` field out of `fetchJson`'s options argument, so every non-GET call is misclassified as GET. The 6 "unused backend endpoint" warnings are similarly informational (e.g. `/health` is called via raw `fetch`, not through `client.js`). **Do not treat this script as a gate until it parses HTTP methods**; verify both ends by hand before acting on any hard failure.

**E2E tests (Playwright):** `frontend/e2e/demo-gallery.spec.js`, `frontend/e2e/file-upload.spec.js`. Config: `frontend/playwright.config.js` — Chromium only, 180s timeout, `webServer` auto-starts `npm run dev` if not already up (`reuseExistingServer: true`), `baseURL: 'http://localhost:5173/comsa-dashboard/'`. Both spec files gate on backend availability in `test.beforeAll` (skip gracefully, per the spec files' own comments, if `GET http://localhost:8000/health` doesn't respond) — **this is the one place in the repo where a graceful skip is intentional**, because Playwright is meant to run against a real backend and there is no way to auto-start one from within Playwright's config in this setup (unlike `integration.test.js`, which does auto-start via `spawn`).

**Browser/manual E2E (Chrome MCP):** Documented in `.claude/skills/test/references/chrome_e2e.md`, tests A–E, required for any new user-facing feature per the project's test SOP — not an automated CI gate, a manual/agent-driven pre-commit step.

## Real Assertion Counts (verified by running the suites during this analysis)

| Suite | Command | Result |
|---|---|---|
| Frontend vitest | `cd frontend && npx vitest run` | **34 test files, 315 tests, all passing** (7.85s) |
| R vacalibration (input-only) | `Rscript tests/test_vacalibration_backend.R --input-only` | **356 tests, 356 passed, 0 failed** |
| R misclassification matrix | `Rscript tests/test_misclass_matrix.R` | **52 tests, 52 passed, 0 failed** |
| R auth visibility | `Rscript tests/test_auth_visibility.R` | **32 tests, 32 passed, 0 failed** |
| R input persistence | `Rscript tests/test_input_persistence.R` | **18 tests, 18 passed, 0 failed** |
| ESLint | `cd frontend && npm run lint` | **4 pre-existing errors** (2× `no-undef` on `process` in `integration.test.js`; 1× `react-hooks/set-state-in-effect` + 1× `react-refresh/only-export-components` in `src/auth/AuthContext.jsx`) |
| Frontend/backend static contract check | `python3 .claude/skills/test/scripts/check_integration.py` | **FAILED — false positive**, the script does not parse HTTP methods so it reads the PUT `/admin/users/<id>` call as a GET. Not a gate; see the note above. |

These counts are higher than the numbers recorded in prior memory/skill notes (which cite ~206 R assertions/18 sections and ~180/90 frontend tests across fewer files) — the suite has grown substantially since those notes were last updated. Re-run the commands above rather than trusting cached counts when precision matters.

## Common Patterns

**Async testing:**
```js
it('sends per-algorithm file keys for ensemble vacalibration', async () => {
  const mockFetch = vi.fn().mockResolvedValue({ ok: true, status: 200, json: () => Promise.resolve({...}) });
  globalThis.fetch = mockFetch;
  const { submitJob } = await import('./client.js');
  await submitJob({ ... });
  const [url, options] = mockFetch.mock.calls[0];
  expect(formData.get('file_interva')).toBeTruthy();
});
```
(`frontend/src/api/client.test.js`)

**Error/failure-path testing:**
```js
it('does not crash on capture failure', async () => {
  html2canvasMock.mockRejectedValue(new Error('canvas boom'))
  await exportCombinedPDF([{ ref: makeRef() }], 'report.pdf')
  expect(pdfInstance.save).not.toHaveBeenCalled()
})
```
(`frontend/src/utils/export.test.js`) — asserts the *absence* of a side effect on failure, not a thrown/caught error, matching the export utilities' fail-soft design (see CONVENTIONS.md → Error Handling).

**R error-path testing:**
```r
result <- tryCatch(
  safe_cause_map(df = interva_fixed, age_group = "neonate"),
  error = function(e) NULL
)
test("InterVA causes map to broad categories without error", !is.null(result))
```
(`tests/test_vacalibration_backend.R`) — wrap the call under test in `tryCatch(..., error = function(e) NULL)` and assert on `!is.null(result)`, rather than asserting on the exception object directly.

---

*Testing analysis: 2026-08-18*
