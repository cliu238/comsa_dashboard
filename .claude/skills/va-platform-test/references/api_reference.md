# VA Platform API Reference

This document describes the expected API endpoints and their behavior for testing purposes.

## Backend Endpoints (Plumber API)

### Health Check
- **Endpoint**: `GET /health`
- **Response**: `{ "status": "ok", "timestamp": "<ISO timestamp>" }`
- **Purpose**: Verify backend is running

### Job Management

#### List All Jobs
- **Endpoint**: `GET /jobs`
- **Response**: `{ "jobs": [{ "job_id": "...", "type": "...", "status": "...", "created_at": "..." }] }`

#### Submit New Job
- **Endpoint**: `POST /jobs?job_type=...&algorithm=...&age_group=...&country=...&calib_model_type=...&ensemble=...`
- **Body**: FormData with optional `file` field
- **Response**: `{ "job_id": "...", "status": "pending", "message": "..." }`

#### Submit Demo Job
- **Endpoint**: `POST /jobs/demo?job_type=...&algorithm=...&age_group=...&calib_model_type=...&ensemble=...`
- **Response**: `{ "job_id": "...", "status": "pending", "message": "..." }`
- **Purpose**: Test with sample data (no file upload needed)

#### Get Job Status
- **Endpoint**: `GET /jobs/<job_id>/status`
- **Response**: `{ "job_id": "...", "type": "...", "status": "...", "algorithm": "...", "created_at": "...", ... }`
- **Status values**: `"pending"`, `"running"`, `"completed"`, `"failed"`

#### Get Job Log
- **Endpoint**: `GET /jobs/<job_id>/log`
- **Response**: `{ "job_id": "...", "log": ["[timestamp] message", ...] }`

#### Get Job Results
- **Endpoint**: `GET /jobs/<job_id>/results`
- **Response**: Varies by job type:
  - **Pipeline**: `{ "algorithm": "...", "age_group": "...", "country": "...", "calibrated_csmf": {...}, "files": {...} }`
  - **Error if not complete**: `{ "error": "Job not completed", "status": "..." }`

#### Download Result File
- **Endpoint**: `GET /jobs/<job_id>/download/<filename>`
- **Response**: Binary file content

#### Rerun Job
- **Endpoint**: `POST /jobs/<job_id>/rerun`
- **Response**: `{ "job_id": "<new_id>", "status": "pending", "message": "...", "original_job_id": "..." }`

## Job Types

### openva
- Runs openVA algorithm only
- Outputs: cause assignments, CSMF

### vacalibration
- Runs vacalibration only (requires pre-processed data)
- Outputs: calibrated CSMF with confidence intervals

### pipeline
- Runs full pipeline: openVA → vacalibration
- Outputs: both openVA results and calibrated CSMF

## Algorithms

- **InterVA**: InterVA 5.0
- **InSilicoVA**: Bayesian network approach
- **EAVA**: Enhanced algorithm (requires specific data format)

## Age Groups

- **neonate**: Neonatal deaths
- **child**: Child deaths

## Parameters

### job_type
- Values: `"openva"`, `"vacalibration"`, `"pipeline"`

### algorithm
- Single: `"InterVA"` or `"InSilicoVA"` or `"EAVA"`
- Multiple (for ensemble): `["InterVA", "InSilicoVA"]` (JSON string)

### age_group
- Values: `"neonate"`, `"child"`

### country
- Example: `"Mozambique"`

### calib_model_type
- Values: `"Mmatprior"`, etc.

### ensemble
- Values: `"TRUE"`, `"FALSE"`
- Requires 2+ algorithms when enabled

## Frontend API Client

### Functions

- `submitJob({ file, jobType, algorithms, ageGroup, country, calibModelType, ensemble })`
- `submitDemoJob({ jobType, algorithms, ageGroup, calibModelType, ensemble })`
- `getJobStatus(jobId)`
- `getJobLog(jobId)`
- `getJobResults(jobId)`
- `listJobs()`
- `getDownloadUrl(jobId, filename)`

### Parameter Mapping (Frontend → Backend)

| Frontend (camelCase) | Backend (snake_case) |
|---------------------|---------------------|
| jobType | job_type |
| algorithms | algorithm |
| ageGroup | age_group |
| country | country |
| calibModelType | calib_model_type |
| ensemble | ensemble |

## Expected Behavior for Testing

1. **Health check** should always return 200 with status "ok"
2. **Demo job** submission should return pending status with job_id
3. **Job status** should progress: pending → running → completed/failed
4. **Job log** should accumulate entries as job progresses
5. **Job results** should return error if job not completed
6. **Nonexistent job** should return error message
7. **Ensemble mode** requires 2+ algorithms (validation enforced)
