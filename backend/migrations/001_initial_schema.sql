-- COMSA Dashboard Initial Schema Migration
-- This migration creates the core job tracking tables

-- Enable UUID extension for generating UUIDs
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Jobs table: Main job tracking
CREATE TABLE jobs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    type VARCHAR(50) NOT NULL,                          -- 'pipeline', 'openva_only', etc.
    status VARCHAR(20) NOT NULL DEFAULT 'pending',       -- 'pending', 'running', 'completed', 'failed'

    -- Algorithm parameters
    algorithm VARCHAR(50),                               -- 'InterVA', 'InSilicoVA', etc.
    age_group VARCHAR(50),                               -- 'neonate', 'child', 'adult'
    country VARCHAR(100),                                -- Country name
    calib_model_type VARCHAR(50),                        -- 'Mmatprior', etc.
    ensemble BOOLEAN DEFAULT FALSE,                      -- Whether ensemble mode is used

    -- Timestamps
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    started_at TIMESTAMP,
    completed_at TIMESTAMP,

    -- Error information (JSONB for flexibility)
    error JSONB DEFAULT '{}'::jsonb,

    -- Results (JSONB to handle varying result structures)
    result JSONB DEFAULT '{}'::jsonb,

    -- Input file path (relative to backend/data)
    input_file_path TEXT,

    -- Indexes for common queries
    CONSTRAINT valid_status CHECK (status IN ('pending', 'running', 'completed', 'failed'))
);

-- Create indexes for common query patterns
CREATE INDEX idx_jobs_status ON jobs(status);
CREATE INDEX idx_jobs_created_at ON jobs(created_at DESC);
CREATE INDEX idx_jobs_algorithm ON jobs(algorithm);
CREATE INDEX idx_jobs_country ON jobs(country);

-- Job logs table: Individual log entries for each job
CREATE TABLE job_logs (
    id SERIAL PRIMARY KEY,
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    timestamp TIMESTAMP NOT NULL DEFAULT NOW(),
    message TEXT NOT NULL,

    -- Index for querying logs by job
    CONSTRAINT fk_job_logs_job FOREIGN KEY (job_id) REFERENCES jobs(id) ON DELETE CASCADE
);

CREATE INDEX idx_job_logs_job_id ON job_logs(job_id, timestamp);

-- Job files table: Track input and output files
CREATE TABLE job_files (
    id SERIAL PRIMARY KEY,
    job_id UUID NOT NULL REFERENCES jobs(id) ON DELETE CASCADE,
    file_type VARCHAR(20) NOT NULL,                     -- 'input', 'output'
    file_name VARCHAR(255) NOT NULL,                    -- e.g., 'input.csv', 'causes.csv'
    file_path TEXT NOT NULL,                            -- Full path relative to backend/data
    file_size BIGINT,                                   -- File size in bytes
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),

    -- Constraints
    CONSTRAINT valid_file_type CHECK (file_type IN ('input', 'output'))
);

CREATE INDEX idx_job_files_job_id ON job_files(job_id);
CREATE INDEX idx_job_files_type ON job_files(job_id, file_type);

-- Comments for documentation
COMMENT ON TABLE jobs IS 'Main job tracking table for VA pipeline jobs';
COMMENT ON TABLE job_logs IS 'Log entries for job execution';
COMMENT ON TABLE job_files IS 'File metadata for job inputs and outputs';

COMMENT ON COLUMN jobs.type IS 'Job type: pipeline (full), openva_only, ensemble, etc.';
COMMENT ON COLUMN jobs.status IS 'Current job status: pending, running, completed, failed';
COMMENT ON COLUMN jobs.result IS 'JSONB containing CSMF data, cause counts, and other results';
COMMENT ON COLUMN jobs.error IS 'JSONB containing error details if job failed';
