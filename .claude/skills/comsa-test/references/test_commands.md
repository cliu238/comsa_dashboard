# Test Commands Reference

## Environment Setup

### Backend (R Plumber API)

Prerequisites:
- R (>= 4.0) with packages: `plumber`, `jsonlite`, `uuid`, `DBI`, `RPostgres`, `future`, `promises`, `vacalibration`, `openVA`
- PostgreSQL database for job persistence
- Environment variables in `.env.local`

Start the backend server:
```bash
cd /Users/ericliu/projects5/comsa_dashboard/backend
Rscript run.R
```
Alternative start:
```bash
cd /Users/ericliu/projects5/comsa_dashboard/backend
Rscript -e "library(plumber); pr <- plumb('plumber.R'); pr\$run(host='0.0.0.0', port=8000)"
```
The server runs on `http://localhost:8000` by default.

Server restart pattern (when port is stuck):
```bash
lsof -ti:8000 | xargs kill -9  # kill process on port 8000
sleep 2
cd /Users/ericliu/projects5/comsa_dashboard/backend && Rscript run.R
```

Check backend logs:
```bash
tail -f /Users/ericliu/projects5/comsa_dashboard/backend.log
```

### Frontend (React/Vite)

Prerequisites:
- Node.js (>= 18), npm
- Dependencies installed via `npm install`
- `.env.production` for API URL config (`VITE_API_BASE_URL`), default: `http://localhost:8000`

Start the frontend dev server:
```bash
cd /Users/ericliu/projects5/comsa_dashboard/frontend
npm run dev
```
The Vite dev server runs on `http://localhost:5173` by default.

Build for production:
```bash
cd /Users/ericliu/projects5/comsa_dashboard/frontend
npm run build
```

Lint check:
```bash
cd /Users/ericliu/projects5/comsa_dashboard/frontend
npm run lint
```

## Complete Test Commands

| Test Type | Command | Working Directory | Server Required |
|-----------|---------|-------------------|-----------------|
| R vacalibration tests | `Rscript tests/test_vacalibration_backend.R` | project root | No |
| DB integration | `Rscript test_db_integration.R` | backend/ | PostgreSQL |
| Backend API tests | `python3 .claude/skills/va-platform-test/scripts/test_backend.py` | project root | Backend on :8000 |
| Integration check | `python3 .claude/skills/va-platform-test/scripts/check_integration.py --project-root .` | project root | No |
| Frontend lint | `npm run lint` | frontend/ | No |
| Frontend build | `npm run build` | frontend/ | No |
| Backend syntax check | `Rscript -e "parse('plumber.R'); cat('OK\n')"` | backend/ | No |
| Health check | `curl -s http://localhost:8000/health` | any | Backend on :8000 |

## Test Category Details

### 1. R Unit Tests (vacalibration backend logic)

**What it tests**: Input data validation, cause mapping, vacalibration computation (single algorithm, ensemble 2-algo, ensemble 3-algo), output structure, parameter validation, edge cases, country parameter variations, and calibration model types (Mmatprior vs Mmatfixed).

**Command**:
```bash
cd /Users/ericliu/projects5/comsa_dashboard
Rscript tests/test_vacalibration_backend.R
```

**Runtime**: 2-5 minutes (runs actual MCMC computations).

**Test file**: `tests/test_vacalibration_backend.R`

**138 tests across 13 sections**:
1. Frontend sample CSV file existence and structure (InterVA, InSilicoVA, EAVA neonate samples)
2. Cause mapping compatibility with vacalibration::cause_map
3. Backend RDS sample data validation
4. Parameter and configuration validation (demo_configs.json)
5. Single-algorithm vacalibration computation (InterVA)
6. CSV-based vacalibration (simulating user upload, InSilicoVA)
7. EAVA algorithm vacalibration
8. Output structure validation (CSMF, credible intervals, misclassification matrix)
9. Country parameter validation (South Africa, Sierra Leone, other)
10. Mmatfixed calibration model
11. Ensemble vacalibration with 2 algorithms
12. Ensemble vacalibration with 3 algorithms
13. Edge cases (cause renaming, Undetermined mapping, sparse causes, invalid age_group)

**Expected output**: Summary line showing `Tests: 138 | Passed: 138 | Failed: 0` and "All tests passed!". Exit code 0 on success, 1 on failure.

### 2. Backend API Tests (Python)

**What it tests**: HTTP endpoint correctness -- health check, job listing, demo job submission, job status polling, job log retrieval, job results, and error handling for nonexistent jobs.

**Prerequisite**: Backend server must be running on localhost:8000.

**Command**:
```bash
python3 /Users/ericliu/projects5/comsa_dashboard/.claude/skills/va-platform-test/scripts/test_backend.py
```

With custom URL:
```bash
python3 /Users/ericliu/projects5/comsa_dashboard/.claude/skills/va-platform-test/scripts/test_backend.py --url http://localhost:8000
```

**Runtime**: ~60 seconds (submits a demo job and waits for completion).

**Endpoints tested**:
- `GET /health` - Server health check
- `GET /jobs` - List all jobs
- `POST /jobs/demo` - Submit demo job
- `GET /jobs/{id}/status` - Job status
- `GET /jobs/{id}/log` - Job log entries
- `GET /jobs/{id}/results` - Job results
- `GET /jobs/{fake_id}/status` - Error handling

### 3. API Testing with curl

For ad-hoc API testing without the Python script:

```bash
# Health check
curl -s http://localhost:8000/health | python3 -m json.tool

# Submit a demo job
JOB_ID=$(curl -s -X POST 'http://localhost:8000/jobs/demo?job_type=pipeline&algorithm=["InterVA"]&age_group=neonate&calib_model_type=Mmatprior&ensemble=FALSE' | python3 -c "import sys,json; print(json.load(sys.stdin)['job_id'])")

# Check job status
curl -s "http://localhost:8000/jobs/$JOB_ID/status" | python3 -m json.tool

# Get job results
curl -s "http://localhost:8000/jobs/$JOB_ID/results" | python3 -m json.tool

# Get job log
curl -s "http://localhost:8000/jobs/$JOB_ID/log" | python3 -m json.tool
```

### 4. Frontend-Backend Integration Check (Python)

**What it tests**: Static analysis of frontend `client.js` and backend `plumber.R` to verify endpoint coverage, parameter consistency, and API base URL configuration.

**Prerequisite**: No running servers needed (static file analysis).

**Command**:
```bash
python3 /Users/ericliu/projects5/comsa_dashboard/.claude/skills/va-platform-test/scripts/check_integration.py --project-root /Users/ericliu/projects5/comsa_dashboard
```

**Runtime**: Instant (< 1 second).

### 5. Database Integration Test (R)

**What it tests**: PostgreSQL database connectivity, schema validation, and CRUD operations for jobs.

**Command**:
```bash
cd /Users/ericliu/projects5/comsa_dashboard/backend
Rscript test_db_integration.R
```

**Prerequisite**: PostgreSQL database accessible with proper credentials in `.env.local`.

### 6. Ad-hoc R Testing

For quick one-off validation of R functions without the full test suite:

```bash
# Syntax check a file before restarting server
cd /Users/ericliu/projects5/comsa_dashboard/backend
Rscript -e "parse('plumber.R'); cat('OK\n')"

# Test a specific utility function
cd /Users/ericliu/projects5/comsa_dashboard
Rscript -e "source('backend/jobs/utils.R'); df <- data.frame(ID='t1', cause='Undetermined'); print(fix_causes_for_vacalibration(df))"

# Check if an R package is available
Rscript -e "library(vacalibration); cat('vacalibration loaded OK\n')"
```

## Test Coverage Reporting

### R Tests
The R test file uses a custom lightweight test framework that reports:
- Total test count
- Pass count
- Fail count
- List of failed test descriptions

Output appears at the end of the test run:
```
========================================
Tests: 138 | Passed: 138 | Failed: 0
========================================
All tests passed!
```

### Python Tests
The backend tester and integration checker each report:
- Passed count
- Failed count
- Warning count

### Full Coverage Run
To run all test types in sequence:
```bash
cd /Users/ericliu/projects5/comsa_dashboard

# 1. R unit tests (no server needed)
Rscript tests/test_vacalibration_backend.R

# 2. Frontend lint
cd frontend && npm run lint && cd ..

# 3. Frontend build check
cd frontend && npm run build && cd ..

# 4. Integration check (no server needed)
python3 .claude/skills/va-platform-test/scripts/check_integration.py --project-root .

# 5. Backend API tests (server must be running)
python3 .claude/skills/va-platform-test/scripts/test_backend.py
```
