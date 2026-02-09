---
name: comsa-test
description: This skill provides comprehensive testing procedures for the COMSA Verbal Autopsy Calibration Platform (comsa_dashboard). It should be used when running tests, validating changes, debugging test failures, adding new tests, or checking test coverage. This skill covers R unit tests (vacalibration logic, 138 assertions), database integration tests, Python backend API tests, frontend-backend integration checks, frontend linting, build verification, and ad-hoc testing patterns.
---

# COMSA Test

## Overview

Testing skill for the COMSA Verbal Autopsy Calibration Platform (`comsa_dashboard`). Provides structured procedures for running all test types, diagnosing failures, and extending the test suite. The platform consists of an R plumber backend (using openVA and vacalibration packages for VA data processing and Bayesian calibration) and a React/Vite frontend.

## When to Use This Skill

- Running any tests ("run tests", "test backend", "check if tests pass")
- Validating code changes before commit or deployment
- Debugging test failures ("test failed", "debug test failure")
- Adding new test cases ("add test for...", "write a test...")
- Checking frontend-backend integration
- Verifying build pipeline
- Running vacalibration tests specifically

## Quick Start

Execute tests in this order. Steps 1-4 need no running server; step 5 requires the backend.

1. **R unit tests** (2-5 min):
   ```bash
   cd /Users/ericliu/projects5/comsa_dashboard && Rscript tests/test_vacalibration_backend.R
   ```

2. **Frontend lint** (< 5 sec):
   ```bash
   cd /Users/ericliu/projects5/comsa_dashboard/frontend && npm run lint
   ```

3. **Frontend build** (10-30 sec):
   ```bash
   cd /Users/ericliu/projects5/comsa_dashboard/frontend && npm run build
   ```

4. **Integration check** (instant):
   ```bash
   python3 /Users/ericliu/projects5/comsa_dashboard/.claude/skills/va-platform-test/scripts/check_integration.py --project-root /Users/ericliu/projects5/comsa_dashboard
   ```

5. **Backend API tests** (requires backend on :8000, ~60 sec):
   ```bash
   python3 /Users/ericliu/projects5/comsa_dashboard/.claude/skills/va-platform-test/scripts/test_backend.py
   ```

For full command details and options, consult `references/test_commands.md`.

## Test Categories

### 1. R Unit Tests -- vacalibration Logic

The primary test suite: 138 assertions across 13 sections covering input data validation, cause mapping, single/ensemble vacalibration computation, output structure, parameter correctness, country variations, calibration model types (Mmatprior/Mmatfixed), and edge cases.

**File**: `tests/test_vacalibration_backend.R`
**Command**: `Rscript tests/test_vacalibration_backend.R` (from project root)
**No running server required.** Runtime: 2-5 minutes (runs actual MCMC).

Uses a custom test framework (not testthat) with `test()` and `section()` helpers. Exit code 0 on all-pass, 1 on any failure.

### 2. Database Integration Tests

Tests PostgreSQL connectivity, schema validation, job CRUD operations.

**File**: `backend/test_db_integration.R`
**Command**: `Rscript test_db_integration.R` (from backend/)
**Requires**: PostgreSQL instance with credentials in `.env.local`

### 3. Backend API Tests (Python)

Validates all HTTP endpoints through the full job lifecycle: health check, job listing, demo job submission, status polling, log retrieval, results, error handling.

**Script**: `.claude/skills/va-platform-test/scripts/test_backend.py`
**Requires**: Backend running on localhost:8000. Start with `cd backend && Rscript run.R`
**Runtime**: ~60 seconds.

### 4. Frontend-Backend Integration Check (Python)

Static analysis of `backend/plumber.R` and `frontend/src/api/client.js` verifying endpoint coverage, parameter consistency, and API base URL. No servers needed.

**Script**: `.claude/skills/va-platform-test/scripts/check_integration.py`

### 5. Frontend Lint and Build

- **Lint**: `cd frontend && npm run lint` -- ESLint checks
- **Build**: `cd frontend && npm run build` -- Vite production build verification

### 6. Ad-hoc Testing

For quick checks without the full test suite:
- **Backend syntax check**: `Rscript -e "parse('plumber.R'); cat('OK\n')"` (from backend/)
- **Health check**: `curl -s http://localhost:8000/health`
- **Inline R test**: `Rscript -e "source('backend/jobs/utils.R'); ..."` (from project root)

For curl-based API testing patterns, consult `references/test_commands.md`.

## Test SOP (Standard Operating Procedures)

### Before Committing Code Changes

1. Run R unit tests to verify vacalibration logic is intact
2. Run frontend lint to catch style issues
3. Run integration check to verify frontend-backend alignment
4. If backend endpoints changed, run backend API tests with server running

### Before Deployment

1. Run all test categories in the Quick Start order
2. Verify frontend production build succeeds
3. Run database integration test if schema changes were made

### After Adding a New Backend Endpoint

1. Add the endpoint test to `va-platform-test/scripts/test_backend.py`
2. Run integration check to verify frontend coverage
3. Update `frontend/src/api/client.js` if frontend needs the new endpoint

### After Modifying vacalibration Logic

1. Run R unit tests first -- they validate computation correctness
2. If cause mapping changed, pay attention to sections 2 and 13
3. If new algorithms added, add test cases following the pattern in sections 5-7
4. For patterns on adding algorithm/country tests, consult `references/test_patterns.md`

### After Modifying Frontend

1. Run `npm run lint` and `npm run build`
2. Run integration check to verify API calls still match backend
3. If API client changed, run backend API tests to verify end-to-end

### Server Restart Pattern

When the backend port is stuck or server needs restart:
```bash
lsof -ti:8000 | xargs kill -9
sleep 2
cd /Users/ericliu/projects5/comsa_dashboard/backend && Rscript run.R
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

### Key Debugging Commands

- Check backend logs: `tail -f /Users/ericliu/projects5/comsa_dashboard/backend.log`
- Backend syntax check: `Rscript -e "parse('plumber.R'); cat('OK\n')"`
- Verify R packages: `Rscript -e "library(vacalibration); library(openVA)"`
- Browser console: Use chrome-in-claude MCP to inspect page for JavaScript errors

## Adding New Tests

For detailed patterns and code examples, consult `references/test_patterns.md`.

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

Add methods to `BackendTester` class in `va-platform-test/scripts/test_backend.py`, then call from `run_all_tests()`.

### Integration Checks

Add methods to `IntegrationChecker` class in `va-platform-test/scripts/check_integration.py`, then call from `run_all_checks()`.

## Key Project Files

| File | Purpose |
|------|---------|
| `tests/test_vacalibration_backend.R` | R unit test suite (138 assertions) |
| `backend/test_db_integration.R` | Database integration tests |
| `backend/plumber.R` | Backend API endpoints |
| `backend/jobs/processor.R` | Job processing logic |
| `backend/jobs/utils.R` | Utility functions (cause mapping, etc.) |
| `backend/data/demo_configs.json` | Demo job configurations |
| `frontend/src/api/client.js` | Frontend API client |
| `frontend/public/sample_*.csv` | Sample data files for tests |
| `backend/data/sample_data/*.rds` | Pre-processed sample data for fast tests |
| `.claude/skills/va-platform-test/scripts/` | Python test scripts (test_backend.py, check_integration.py) |

## Resources

### references/
- `test_commands.md` - Complete reference for all test commands, environment setup, server management, curl-based API testing, and test coverage reporting
- `common_failures.md` - Detailed failure patterns and resolutions observed from project logs, organized by test type, with debugging strategies
- `test_patterns.md` - Code patterns for writing new tests, domain knowledge (vacalibration parameters, expected outputs, neonate broad causes), and common testing workflows
