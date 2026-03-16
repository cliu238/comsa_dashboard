# Multi-Upload Ensemble Calibration Design

**Issues**: #27 (ensemble uploads), #17 (algorithm selection + multi-upload UX)
**Date**: 2026-03-12

## Summary

Support uploading separate VA data files per algorithm for ensemble calibration. Applies to both "Calibration Only" and "Full Pipeline" job types.

## Frontend UI

### Calibration Only — Non-ensemble
- One upload row: `[Algorithm Dropdown] [Choose File] [filename.csv]`
- Algorithm options: InterVA, InSilicoVA, EAVA
- Sample CSV download link updates based on selected algorithm

### Calibration Only — Ensemble
- Starts with 2 upload rows (minimum for ensemble)
- Each row: `[Algorithm Dropdown] [Choose File] [filename.csv] [Remove]`
- `+ Add Algorithm` button (max 3 rows — 3 algorithms exist)
- Remove button hidden when only 2 rows remain
- Each dropdown filters out already-selected algorithms
- Validation: all rows must have file + unique algorithm

### Pipeline — Non-ensemble
- Single algorithm dropdown + single file input (raw VA data)

### Pipeline — Ensemble
- Multi-select algorithm checkboxes (2+ required)
- Single file input (one raw VA file)
- No per-algorithm file uploads — openVA processes the single file per algorithm

### openVA Only
- No changes

### State Shape
```js
const [uploads, setUploads] = useState([{ algorithm: '', file: null }]);
// Ensemble vacalibration: [{algorithm: 'InterVA', file: File}, ...]
// Non-ensemble or pipeline: single entry
```

## Backend API

### POST /jobs

Ensemble vacalibration: multiple file fields keyed by algorithm name.
- `file_interva`, `file_insilicova`, `file_eava` in FormData
- `algorithm` param: JSON array (e.g., `["InterVA","InSilicoVA"]`)

Non-ensemble / pipeline: single `file` field (backward compatible).

### File Storage
```
data/uploads/{job_id}/
  input_interva.csv      # ensemble vacalibration
  input_insilicova.csv
  input_eava.csv
  input.csv              # non-ensemble or pipeline raw VA
```

### Validation
- Ensemble vacalibration: file must exist for each algorithm in array
- Pipeline ensemble: single file + 2+ algorithms required
- 400 error naming which algorithm's file is missing

## Processing

### run_vacalibration() changes
- Load per-algorithm files (`input_{algo}.csv`) for ensemble
- Pass multi-algorithm data to vacalibration package

### run_pipeline() changes
- Run openVA once per selected algorithm (from single raw VA file)
- Feed all openVA outputs into vacalibration with ensemble=TRUE
- Save intermediate openVA outputs

## Frontend API Client

```js
// Ensemble vacalibration:
uploads.forEach(({ algorithm, file }) => {
  formData.append(`file_${algorithm.toLowerCase()}`, file);
});

// Single file:
formData.append('file', file);
```

## Testing

### Frontend (JobForm.test.js)
- Ensemble checkbox shows multi-upload rows for vacalibration
- + Add button adds row, max 3; Remove works, min 2
- Algorithm dropdowns filter already-selected values
- Pipeline ensemble: checkboxes + single file
- Validation: missing file or duplicate algo blocks submit

### Frontend (client.test.js)
- Multi-file FormData for ensemble vacalibration
- Single file for pipeline ensemble

### Backend (test_vacalibration_backend.R)
- Multi-file loading from input_{algo}.csv
- Missing file errors clearly
- Pipeline ensemble: openVA per algo, feeds vacalibration

## What's NOT Changing
- Demo/sample data flow (already handles ensemble internally)
- Results display (already handles ensemble output)
- MCMC settings, country, age group
- Database schema (algorithm column already stores arrays)
