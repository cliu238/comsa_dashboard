-- Test insert to verify schema works
-- Using data from 760e77d6-1224-4eaa-a84e-e13f380584f7.json

BEGIN;

-- Insert a test job
INSERT INTO jobs (
    id,
    type,
    status,
    algorithm,
    age_group,
    country,
    calib_model_type,
    ensemble,
    created_at,
    started_at,
    completed_at,
    error,
    result,
    input_file_path
) VALUES (
    '760e77d6-1224-4eaa-a84e-e13f380584f7'::uuid,
    'pipeline',
    'completed',
    'InterVA',
    'neonate',
    'Mozambique',
    'Mmatprior',
    false,
    '2026-01-08 12:33:16'::timestamp,
    '2026-01-08 12:33:22'::timestamp,
    '2026-01-08 12:33:46'::timestamp,
    '{}'::jsonb,
    '{"n_records": 22, "algorithm": "interva", "age_group": "neonate", "country": "Mozambique", "files": {"causes": "causes.csv", "summary": "calibration_summary.csv"}}'::jsonb,
    'data/uploads/760e77d6-1224-4eaa-a84e-e13f380584f7/input.csv'
);

-- Insert log entries
INSERT INTO job_logs (job_id, timestamp, message) VALUES
    ('760e77d6-1224-4eaa-a84e-e13f380584f7'::uuid, '2026-01-08 12:33:22', '[2026-01-08 12:33:22] Starting full pipeline: openVA -> vacalibration'),
    ('760e77d6-1224-4eaa-a84e-e13f380584f7'::uuid, '2026-01-08 12:33:22', '[2026-01-08 12:33:22] === Step 1: openVA ==='),
    ('760e77d6-1224-4eaa-a84e-e13f380584f7'::uuid, '2026-01-08 12:33:22', '[2026-01-08 12:33:22] Loading data from: data/uploads/760e77d6-1224-4eaa-a84e-e13f380584f7/input.csv'),
    ('760e77d6-1224-4eaa-a84e-e13f380584f7'::uuid, '2026-01-08 12:33:22', '[2026-01-08 12:33:22] Data loaded: 50 records'),
    ('760e77d6-1224-4eaa-a84e-e13f380584f7'::uuid, '2026-01-08 12:33:22', '[2026-01-08 12:33:22] Running InterVA'),
    ('760e77d6-1224-4eaa-a84e-e13f380584f7'::uuid, '2026-01-08 12:33:26', '[2026-01-08 12:33:26] openVA complete: 22 causes assigned'),
    ('760e77d6-1224-4eaa-a84e-e13f380584f7'::uuid, '2026-01-08 12:33:46', '[2026-01-08 12:33:46] Calibration complete'),
    ('760e77d6-1224-4eaa-a84e-e13f380584f7'::uuid, '2026-01-08 12:33:46', '[2026-01-08 12:33:46] All results saved');

-- Insert file records
INSERT INTO job_files (job_id, file_type, file_name, file_path, file_size) VALUES
    ('760e77d6-1224-4eaa-a84e-e13f380584f7'::uuid, 'input', 'input.csv', 'data/uploads/760e77d6-1224-4eaa-a84e-e13f380584f7/input.csv', 73720),
    ('760e77d6-1224-4eaa-a84e-e13f380584f7'::uuid, 'output', 'causes.csv', 'data/outputs/760e77d6-1224-4eaa-a84e-e13f380584f7/causes.csv', NULL),
    ('760e77d6-1224-4eaa-a84e-e13f380584f7'::uuid, 'output', 'calibration_summary.csv', 'data/outputs/760e77d6-1224-4eaa-a84e-e13f380584f7/calibration_summary.csv', NULL);

COMMIT;

-- Verify the insert
SELECT
    id,
    type,
    status,
    algorithm,
    country,
    created_at,
    (SELECT COUNT(*) FROM job_logs WHERE job_id = jobs.id) as log_count,
    (SELECT COUNT(*) FROM job_files WHERE job_id = jobs.id) as file_count
FROM jobs
WHERE id = '760e77d6-1224-4eaa-a84e-e13f380584f7'::uuid;
