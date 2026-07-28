-- 003_input_file_storage.sql
-- Issue #110: uploaded input CSVs lived only on the pod's ephemeral filesystem
-- and were wiped on every deploy/restart, breaking rerun and downloads. Mirror
-- their bytes here (base64 in a TEXT column) so a fresh pod can restore them.
--
-- This is applied AUTOMATICALLY and idempotently at backend startup by
-- ensure_input_file_storage() in backend/db/connection.R, using the pod's own DB
-- credentials — there is no manual migration step. This file is the canonical
-- record of the schema; the CREATE ... IF NOT EXISTS below is safe to run by hand
-- as well.

CREATE TABLE IF NOT EXISTS job_input_files (
    id          SERIAL PRIMARY KEY,
    job_id      UUID NOT NULL,
    filename    TEXT NOT NULL,
    content_b64 TEXT NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    UNIQUE (job_id, filename)
);

CREATE INDEX IF NOT EXISTS idx_job_input_files_job_id ON job_input_files(job_id);

COMMENT ON TABLE job_input_files IS 'Base64-encoded uploaded input CSVs, mirrored from disk so they survive pod replacement (issue #110)';
