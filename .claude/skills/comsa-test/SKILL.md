---
name: comsa-test
description: Use when running tests, validating changes, debugging test failures, adding new tests, or checking test coverage for the COMSA Dashboard (comsa_dashboard). Also use when setting up test environments, investigating why a test broke, or determining which tests to run after a code change.
---

# COMSA Test

## Overview

Testing skill for the COMSA Verbal Autopsy Calibration Platform (`comsa_dashboard`). Provides structured procedures for running all test types, diagnosing failures, and extending the test suite. The platform consists of an R plumber backend (using openVA and vacalibration packages for VA data processing and Bayesian calibration) and a React/Vite frontend.

## Quick Start

Execute tests in this order. Steps 1-5 need no running server; steps 6-7 require the backend.

1. **Frontend unit tests** (< 5 sec):
   ```bash
   cd frontend && npm test
   ```

2. **R unit tests -- full** (2-5 min, includes MCMC):
   ```bash
   Rscript tests/test_vacalibration_backend.R
   ```

   **R unit tests -- input-only** (< 10 sec, no MCMC):
   ```bash
   Rscript tests/test_vacalibration_backend.R --input-only
   ```

3. **Frontend lint** (< 5 sec):
   ```bash
   cd frontend && npm run lint
   ```

4. **Frontend build** (10-30 sec):
   ```bash
   cd frontend && npm run build
   ```

5. **Integration check** (instant):
   ```bash
   python3 .claude/skills/comsa-test/scripts/check_integration.py --project-root .
   ```

6. **Backend API tests** (requires backend on :8000, ~60 sec):
   ```bash
   python3 .claude/skills/comsa-test/scripts/test_backend.py
   ```

7. **Playwright E2E tests** (requires backend on :8000, ~30 sec; auto-starts frontend):
   ```bash
   cd frontend && npm run test:e2e
   ```

For full command details and options, consult `references/test_commands.md`.

## Test Categories

### 1. Frontend Unit Tests (Vitest)

Pure-function unit tests for the React frontend. Tests `parseProgress()`, `getElapsedTime()`, `unbox()`, `generateFilename()`, `getCellColor()`, `isDiagonalCell()`, and `exportToPDF()`.

**Files**: `frontend/src/utils/progress.test.js`, `frontend/src/api/client.test.js`, `frontend/src/utils/export.test.js`, `frontend/src/components/MisclassificationMatrix.test.js`, `frontend/src/components/CSMFChart.test.js`
**Command**: `cd frontend && npm test`
**No running server required.** Runtime: < 5 seconds.
**~63 assertions** across 6 test files (+ 3 integration tests that auto-skip without backend).

### 2. R Unit Tests -- vacalibration Logic

The primary backend test suite: ~175 runtime assertions across 16 sections covering:
- Input data validation (CSV samples, RDS samples, openVA WHO2016 format)
- Cause mapping compatibility
- CSV-to-RDS consistency checks
- Parameter and configuration validation
- Single/ensemble vacalibration computation (with MCMC)
- Output structure validation
- Country variations, calibration model types (Mmatprior/Mmatfixed)
- new_test_data.csv expected-value validation
- Edge cases

**File**: `tests/test_vacalibration_backend.R`
**Command**: `Rscript tests/test_vacalibration_backend.R` (from project root)
**Input-only mode**: `Rscript tests/test_vacalibration_backend.R --input-only` (skips MCMC, < 10 sec)
**No running server required.** Full runtime: 2-5 minutes (runs actual MCMC).

Uses a custom test framework (not testthat) with `test()` and `section()` helpers. Exit code 0 on all-pass, 1 on any failure.

### 3. Database Integration Tests

Tests PostgreSQL connectivity, schema validation, job CRUD operations.

**File**: `backend/test_db_integration.R`
**Command**: `Rscript test_db_integration.R` (from backend/)
**Requires**: PostgreSQL instance with credentials in `.env.local`

### 4. Backend API Tests (Python)

Validates all HTTP endpoints through the full job lifecycle: health check, job listing, demo job submission, status polling, log retrieval, results, error handling.

**Script**: `.claude/skills/comsa-test/scripts/test_backend.py`
**Requires**: Backend running on localhost:8000. Start with `cd backend && Rscript run.R`
**Runtime**: ~60 seconds.

### 5. Frontend-Backend Integration Check (Python)

Static analysis of `backend/plumber.R` and `frontend/src/api/client.js` verifying endpoint coverage, parameter consistency, and API base URL. No servers needed.

**Script**: `.claude/skills/comsa-test/scripts/check_integration.py`

### 6. Frontend Lint and Build

- **Lint**: `cd frontend && npm run lint` -- ESLint checks
- **Build**: `cd frontend && npm run build` -- Vite production build verification

### 7. Playwright E2E Tests

Reproducible, scriptable E2E tests using Playwright (Chromium). Auto-starts the Vite dev server; requires backend running on :8000. Skips gracefully if backend is not available.

**Files**: `frontend/e2e/demo-gallery.spec.js`, `frontend/e2e/file-upload.spec.js`
**Config**: `frontend/playwright.config.js`
**Commands**:
- `cd frontend && npm run test:e2e` — headless run (~30 sec)
- `cd frontend && npm run test:e2e:ui` — interactive UI mode
**Requires**: Backend on localhost:8000. Frontend auto-started by Playwright.

Current test coverage (3 tests, 2 files):
- **Demo Gallery (openVA)**: Navigate → filter → launch "Neonate - InterVA - Mozambique" → verify CSMF table
- **Demo Gallery (vacalibration)**: Filter "Calibration" → launch "Sierra Leone - InterVA" → verify calibrated CSMF table (Uncalibrated/Calibrated/95% CI columns), misclassification matrix, bar chart
- **File upload**: Upload `sample_interva_neonate.csv` with defaults → submit → verify job completion + calibrated results

**Note**: Vitest uses `.test.js`, Playwright uses `.spec.js`. The `e2e/` directory is excluded from Vitest via `vite.config.js`.

### 8. Chrome E2E Browser Tests (Manual)

Manual E2E testing via Chrome browser automation (`mcp__claude-in-chrome__*` tools). Use Playwright (section 7) for reproducible tests; use Chrome E2E for exploratory or visual testing.

For detailed test procedures (Tests A-D), file upload scripts, and test data reference, consult `references/chrome_e2e.md`.

### 9. Ad-hoc Testing

For quick checks without the full test suite:
- **Backend syntax check**: `Rscript -e "parse('plumber.R'); cat('OK\n')"` (from backend/)
- **Health check**: `curl -s http://localhost:8000/health`
- **Inline R test**: `Rscript -e "source('backend/jobs/utils.R'); ..."` (from project root)

For curl-based API testing patterns, consult `references/test_commands.md`.

## Test SOP (Standard Operating Procedures)

### Before Committing Code Changes

1. Run frontend unit tests (`npm test`)
2. Run R unit tests (full or `--input-only` for quick check)
3. Run frontend lint to catch style issues
4. Run integration check to verify frontend-backend alignment
5. If backend endpoints changed, run backend API tests with server running

### Before Deployment

1. Run all test categories in the Quick Start order
2. Verify frontend production build succeeds
3. Run database integration test if schema changes were made
4. Run Playwright E2E tests (`npm run test:e2e`)
5. Run Chrome E2E tests for exploratory/visual testing (Test A + Test D at minimum, one test per session)

### After Adding a New Backend Endpoint

1. Add the endpoint test to `comsa-test/scripts/test_backend.py`
2. Run integration check to verify frontend coverage
3. Update `frontend/src/api/client.js` if frontend needs the new endpoint

### After Modifying vacalibration Logic

1. Run R unit tests first -- they validate computation correctness
2. If cause mapping changed, pay attention to sections 2 and 13
3. If new algorithms added, add test cases following the pattern in sections 5-7
4. For patterns on adding algorithm/country tests, consult `references/test_patterns.md`

### After Modifying Frontend

1. Run frontend unit tests (`npm test`)
2. Run `npm run lint` and `npm run build`
3. Run integration check to verify API calls still match backend
4. If API client changed, run backend API tests to verify end-to-end
5. If the change affects what the user sees or interacts with (new/changed UI elements, data display, interaction flows, error states), add or update Playwright E2E assertions — unit tests on logic alone do not catch rendering or integration regressions

### Server Restart Pattern

When the backend port is stuck or server needs restart:
```bash
lsof -ti:8000 | xargs kill -9
sleep 2
cd backend && Rscript run.R
```

## Debugging Test Failures

Quick-reference table. For detailed failure patterns and resolutions, consult `references/common_failures.md`.

| Symptom | Likely Cause | Quick Fix |
|---------|-------------|-----------|
| "could not find function 'vacalibration'" | R package missing | Install vacalibration package |
| "Ensemble calibration requires at least 2 algorithms" | Single algo with ensemble=TRUE | Fix backend to build multi-entry va_data |
| "Backend appears to be down" | Server not running | `cd backend && Rscript run.R` |
| "Job did not complete within timeout" | Slow MCMC or R error | Check `backend.log` |
| "404 - Resource Not Found" | Wrong endpoint path | Check plumber.R route definitions |
| `log.join is not a function` | Array vs scalar mismatch | Ensure arrays before `.join()` |
| "Pareto k diagnostic values too high" | Normal MCMC warning | No action needed (not an error) |
| Frontend lint/build errors | Code issues | Fix reported issues in source |
| Integration mismatches | Endpoint URL drift | Align plumber.R and client.js |
| Frontend vitest failures | Utility function changes | Check progress.js, client.js, export.js |
| "Request too large (max 20MB)" | Too many screenshots in one E2E session | Start a fresh session; run only one E2E test per session |

### Key Debugging Commands

- Check backend logs: `tail -f backend.log`
- Backend syntax check: `Rscript -e "parse('plumber.R'); cat('OK\n')"`
- Verify R packages: `Rscript -e "library(vacalibration); library(openVA)"`
- Browser console: Use chrome-in-claude MCP to inspect page for JavaScript errors

## Adding New Tests

For detailed patterns and code examples, consult `references/test_patterns.md`.

### Playwright E2E Tests

Add `.spec.js` files in `frontend/e2e/`. Import from `@playwright/test`:

```js
import { test, expect } from '@playwright/test';

test('my test', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('h1')).toHaveText('VA Calibration Platform');
});
```

Run with `cd frontend && npm run test:e2e`. Use `npm run test:e2e:ui` for interactive debugging.

### Frontend Unit Tests

Add `.test.js` files alongside source files. Import from `vitest`:

```js
import { describe, it, expect } from 'vitest'
import { myFunction } from './myModule.js'

describe('myFunction', () => {
  it('does something', () => {
    expect(myFunction(input)).toBe(expected)
  })
})
```

Run with `cd frontend && npm test`.

### R Unit Tests

Add to `tests/test_vacalibration_backend.R` before the SUMMARY block:

```r
section("N. New Section Name")

test("description of assertion", {
  result <- some_function()
  !is.null(result) && result$value == expected
})
```

The custom framework auto-counts pass/fail. Group related tests with `section()`.

### Backend API Tests

Add methods to `BackendTester` class in `comsa-test/scripts/test_backend.py`, then call from `run_all_tests()`.

### Integration Checks

Add methods to `IntegrationChecker` class in `comsa-test/scripts/check_integration.py`, then call from `run_all_checks()`.

## Key Project Files

| File | Purpose |
|------|---------|
| `frontend/src/utils/progress.test.js` | Frontend progress parsing tests (~20 assertions) |
| `frontend/src/api/client.test.js` | Frontend API client unbox tests (~12 assertions) |
| `frontend/src/utils/export.test.js` | Frontend export utility tests (~10 assertions) |
| `frontend/src/components/MisclassificationMatrix.test.js` | Matrix color gradient + diagonal detection tests (~9 assertions) |
| `frontend/src/components/CSMFChart.test.js` | CSMF chart data computation tests (~7 assertions) |
| `frontend/src/components/JobForm.test.js` | Source-level button/tab label tests (~6 assertions) |
| `frontend/src/api/integration.test.js` | Frontend API integration tests (auto-skip, 3 tests) |
| `frontend/e2e/demo-gallery.spec.js` | Playwright E2E — Demo Gallery (openVA + vacalibration) |
| `frontend/e2e/file-upload.spec.js` | Playwright E2E — File upload flow |
| `frontend/playwright.config.js` | Playwright configuration (Chromium-only, 3min timeout) |
| `tests/test_vacalibration_backend.R` | R unit test suite (~175 runtime assertions) |
| `backend/test_db_integration.R` | Database integration tests |
| `backend/plumber.R` | Backend API endpoints |
| `backend/jobs/processor.R` | Job processing logic |
| `backend/jobs/utils.R` | Utility functions (cause mapping, etc.) |
| `backend/data/demo_configs.json` | Demo job configurations |
| `backend/data/sample_data/new_test_data.csv` | Test data with hardcoded expected values |
| `frontend/src/api/client.js` | Frontend API client |
| `frontend/public/sample_*.csv` | Sample data files for tests |
| `backend/data/sample_data/*.rds` | Pre-processed sample data for fast tests |
| `.claude/skills/comsa-test/scripts/` | Python test scripts (test_backend.py, check_integration.py) |

## Resources

### references/
- `test_commands.md` - Complete reference for all test commands, environment setup, server management, curl-based API testing, and test coverage reporting
- `common_failures.md` - Detailed failure patterns and resolutions observed from project logs, organized by test type, with debugging strategies
- `test_patterns.md` - Code patterns for writing new tests, domain knowledge (vacalibration parameters, expected outputs, neonate broad causes), and common testing workflows
- `expected_values.md` - Expected CSMF values for each sample dataset/algorithm (deterministic uncalibrated, stochastic calibrated ranges), mathematical invariants, and new_test_data.csv baselines
- `sops.md` - Standard Operating Procedures for new sample data validation, post-algorithm-change validation, new country validation, ensemble configuration, and CSMF anomaly investigation
- `chrome_e2e.md` - Chrome E2E browser test procedures (Tests A-D), file upload scripts, test data reference, and context limit warnings
