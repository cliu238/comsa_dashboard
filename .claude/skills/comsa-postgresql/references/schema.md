# COMSA Dashboard Database Schema

## Overview

The COMSA Dashboard database tracks verbal autopsy (VA) job processing, including job parameters, execution logs, and file management. This schema replaces the file-based job tracking system in `backend/data/jobs/`.

**Database:** `comsa_dashboard`
**Schema Version:** 1.0 (Initial)
**Last Updated:** 2026-01-16

## Tables

### 1. jobs

Main job tracking table for VA pipeline jobs.

**Purpose:** Store job metadata, parameters, status, and results.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | NO | uuid_generate_v4() | Unique job identifier |
| type | VARCHAR(50) | NO | - | Job type: 'pipeline', 'openva_only', 'ensemble', etc. |
| status | VARCHAR(20) | NO | 'pending' | Current status: 'pending', 'running', 'completed', 'failed' |
| algorithm | VARCHAR(50) | YES | NULL | VA algorithm: 'InterVA', 'InSilicoVA', etc. |
| age_group | VARCHAR(50) | YES | NULL | Age group: 'neonate', 'child', 'adult' |
| country | VARCHAR(100) | YES | NULL | Country name for calibration |
| calib_model_type | VARCHAR(50) | YES | NULL | Calibration model: 'Mmatprior', etc. |
| ensemble | BOOLEAN | YES | FALSE | Whether ensemble mode is used |
| created_at | TIMESTAMP | NO | NOW() | Job creation timestamp |
| started_at | TIMESTAMP | YES | NULL | Job start timestamp |
| completed_at | TIMESTAMP | YES | NULL | Job completion timestamp |
| error | JSONB | YES | '{}' | Error details if job failed |
| result | JSONB | YES | '{}' | Job results: CSMF data, cause counts, etc. |
| input_file_path | TEXT | YES | NULL | Path to input file (relative to backend/data) |

**Indexes:**
- `jobs_pkey` (PRIMARY KEY on id)
- `idx_jobs_status` (status)
- `idx_jobs_created_at` (created_at DESC)
- `idx_jobs_algorithm` (algorithm)
- `idx_jobs_country` (country)

**Constraints:**
- `valid_status`: CHECK (status IN ('pending', 'running', 'completed', 'failed'))

**Result JSONB Structure:**
```json
{
  "n_records": 22,
  "algorithm": "interva",
  "age_group": "neonate",
  "country": "Mozambique",
  "openva_csmf": { ... },
  "cause_counts": { ... },
  "uncalibrated_csmf": { ... },
  "calibrated_csmf": { ... },
  "calibrated_ci_lower": { ... },
  "calibrated_ci_upper": { ... },
  "files": {
    "causes": "causes.csv",
    "summary": "calibration_summary.csv"
  }
}
```

### 2. job_logs

Log entries for job execution.

**Purpose:** Store individual log messages generated during job processing.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | SERIAL | NO | auto | Log entry ID |
| job_id | UUID | NO | - | Reference to jobs table |
| timestamp | TIMESTAMP | NO | NOW() | Log entry timestamp |
| message | TEXT | NO | - | Log message |

**Indexes:**
- `job_logs_pkey` (PRIMARY KEY on id)
- `idx_job_logs_job_id` (job_id, timestamp)

**Foreign Keys:**
- `job_id` REFERENCES jobs(id) ON DELETE CASCADE

### 3. job_files

File metadata for job inputs and outputs.

**Purpose:** Track input and output files associated with jobs.

| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | SERIAL | NO | auto | File record ID |
| job_id | UUID | NO | - | Reference to jobs table |
| file_type | VARCHAR(20) | NO | - | File type: 'input' or 'output' |
| file_name | VARCHAR(255) | NO | - | File name (e.g., 'input.csv', 'causes.csv') |
| file_path | TEXT | NO | - | Full path relative to backend/data |
| file_size | BIGINT | YES | NULL | File size in bytes |
| created_at | TIMESTAMP | NO | NOW() | File creation timestamp |

**Indexes:**
- `job_files_pkey` (PRIMARY KEY on id)
- `idx_job_files_job_id` (job_id)
- `idx_job_files_type` (job_id, file_type)

**Constraints:**
- `valid_file_type`: CHECK (file_type IN ('input', 'output'))

**Foreign Keys:**
- `job_id` REFERENCES jobs(id) ON DELETE CASCADE

## Common Queries

### List Recent Jobs

```sql
SELECT
    id,
    type,
    status,
    algorithm,
    country,
    created_at,
    completed_at - started_at as duration
FROM jobs
ORDER BY created_at DESC
LIMIT 20;
```

### Get Job Details with Logs

```sql
SELECT
    j.*,
    json_agg(
        json_build_object(
            'timestamp', l.timestamp,
            'message', l.message
        ) ORDER BY l.timestamp
    ) as logs
FROM jobs j
LEFT JOIN job_logs l ON j.id = l.job_id
WHERE j.id = 'YOUR-JOB-ID'
GROUP BY j.id;
```

### Get Job with Files

```sql
SELECT
    j.id,
    j.status,
    j.algorithm,
    json_agg(
        json_build_object(
            'type', f.file_type,
            'name', f.file_name,
            'path', f.file_path,
            'size', f.file_size
        )
    ) as files
FROM jobs j
LEFT JOIN job_files f ON j.id = f.job_id
WHERE j.id = 'YOUR-JOB-ID'
GROUP BY j.id;
```

### Count Jobs by Status

```sql
SELECT
    status,
    COUNT(*) as count
FROM jobs
GROUP BY status
ORDER BY count DESC;
```

### Jobs by Algorithm and Country

```sql
SELECT
    algorithm,
    country,
    COUNT(*) as job_count,
    AVG(EXTRACT(EPOCH FROM (completed_at - started_at))) as avg_duration_seconds
FROM jobs
WHERE status = 'completed'
GROUP BY algorithm, country
ORDER BY job_count DESC;
```

### Recent Failed Jobs

```sql
SELECT
    id,
    algorithm,
    country,
    created_at,
    error->>'message' as error_message
FROM jobs
WHERE status = 'failed'
ORDER BY created_at DESC
LIMIT 10;
```

## Schema Migrations

### Migration History

| Version | Date | File | Description |
|---------|------|------|-------------|
| 1.0 | 2026-01-16 | `001_initial_schema.sql` | Initial schema with jobs, job_logs, and job_files tables |

### Applying Migrations

```bash
# Apply a migration
source .env
PGPASSWORD=$PGPASSWORD psql -h $PGHOST -p $PGPORT -U $PGUSER -d $PGDATABASE -f backend/migrations/001_initial_schema.sql
```

## Relationships

```
jobs (1) ----< (many) job_logs
     (1) ----< (many) job_files
```

- One job can have many log entries
- One job can have many files (inputs and outputs)
- Deleting a job cascades to delete its logs and file records (files on disk remain)

## Indexes Summary

**Performance Optimizations:**
- Jobs are indexed by status for filtering active/completed jobs
- Jobs are indexed by creation date (DESC) for recent job queries
- Jobs are indexed by algorithm and country for analytics
- Logs are indexed by (job_id, timestamp) for efficient log retrieval
- Files are indexed by job_id and (job_id, file_type) for file queries

## Migration from File-Based System

The database schema replaces the following file structure:

**Old System:**
```
backend/data/
  jobs/{job_id}.json          → jobs table
  uploads/{job_id}/input.csv  → job_files (type='input')
  outputs/{job_id}/*.csv      → job_files (type='output')
```

**New System:**
- Job metadata stored in `jobs` table
- Log entries stored in `job_logs` table
- File metadata stored in `job_files` table
- Actual files remain on disk (for now)

**Benefits:**
- Faster queries (indexed database vs scanning JSON files)
- Better data integrity (foreign keys, constraints)
- Easier analytics (SQL queries vs file parsing)
- Atomic operations (transactions)
- Scalability (can move files to S3/object storage later)

## Notes

- **JSONB columns** (error, result): Store flexible/nested data structures
- **CASCADE deletes**: Deleting a job removes all related logs and file records
- **Files on disk**: Physical files still stored in backend/data; only metadata in DB
- **Timestamps**: All timestamps are without timezone (should migrate to timestamptz in future)
- **UUIDs**: Job IDs are UUIDs for global uniqueness and security
