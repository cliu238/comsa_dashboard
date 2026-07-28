# VA Calibration Platform - Backend

R plumber API for processing verbal autopsy data using openVA and vacalibration packages.

## Requirements

- R >= 4.0
- Required packages: `plumber`, `jsonlite`, `uuid`, `future`, `openVA`, `vacalibration`

```r
install.packages(c("plumber", "jsonlite", "uuid", "future"))
# openVA and vacalibration should already be installed
```

## Quick Start

```bash
cd backend
Rscript run.R
```

Server runs at `http://localhost:8000`

## API Endpoints

### Health Check

```bash
curl http://localhost:8000/health
```

### Submit Job

Only the CSV file is multipart (`-F`). **Every scalar parameter must go in the
query string.** A scalar sent as a multipart form field is silently discarded:
plumber gives a text part no Content-Type, so it is parsed with `parseQS`, and a
bare value like `child` (no `=`) becomes an empty list. That is what caused
issue #105 — a lost `age_group` was defaulted to `neonate`, and child data was
scored against the neonate cause list.

```bash
# Full pipeline with sample data (demo)
curl -X POST "http://localhost:8000/jobs/demo?job_type=pipeline&age_group=neonate"

# With custom data -- scalars in the query string, file as multipart
curl -X POST "http://localhost:8000/jobs?job_type=pipeline&algorithm=InterVA&age_group=neonate&country=Mozambique" \
  -F "file=@data.csv"

# Ensemble: algorithm accepts a JSON array. Per-algorithm file fields
# (file_interva/file_insilicova/file_eava) apply to vacalibration jobs only;
# a pipeline ensemble takes a single -F "file=@data.csv" instead.
curl -X POST "http://localhost:8000/jobs?job_type=vacalibration&algorithm=%5B%22InterVA%22,%22EAVA%22%5D&age_group=child&country=Kenya&ensemble=true" \
  -F "file_interva=@interva.csv" -F "file_eava=@eava.csv"
```

**Required parameters** — these determine what science is run, so a missing or
unrecognized value is rejected rather than defaulted:

| Parameter | Values |
|-----------|--------|
| `job_type` | `openva`, `vacalibration`, `pipeline` |
| `algorithm` | `InterVA`, `InSilicoVA`, `EAVA` — or a JSON array of them |
| `age_group` | `neonate`, `child` |
| `country` | `Bangladesh`, `Ethiopia`, `Kenya`, `Mali`, `Mozambique`, `Sierra Leone`, `South Africa`, `other` (pooled) |

**Optional parameters** — defaulted when omitted, but an invalid value is
rejected rather than coerced to `NA`:

| Parameter | Values | Default |
|-----------|--------|---------|
| `calib_model_type` | `Mmatprior`, `Mmatfixed` | `Mmatprior` |
| `ensemble` | `true`, `false` | `false` |
| `n_mcmc` | positive integer | `5000` |
| `n_burn` | positive integer | `2000` |
| `n_thin` | positive integer | `1` |

### Check Status

```bash
curl http://localhost:8000/jobs/{job_id}/status
```

Response:
```json
{
  "job_id": "abc-123",
  "type": "pipeline",
  "status": "completed",
  "created_at": "2025-01-01 10:00:00",
  "completed_at": "2025-01-01 10:01:30"
}
```

### Get Log

```bash
curl http://localhost:8000/jobs/{job_id}/log
```

### Get Results

```bash
curl http://localhost:8000/jobs/{job_id}/results
```

Response:
```json
{
  "n_records": 200,
  "algorithm": "interva",
  "age_group": "neonate",
  "country": "Mozambique",
  "uncalibrated_csmf": {
    "pneumonia": 0.025,
    "sepsis_meningitis_inf": 0.049,
    "ipre": 0.728,
    "prematurity": 0.012
  },
  "calibrated_csmf": {
    "pneumonia": 0.034,
    "sepsis_meningitis_inf": 0.059,
    "ipre": 0.700,
    "prematurity": 0.020
  }
}
```

### Download Output Files

```bash
curl -O http://localhost:8000/jobs/{job_id}/download/causes.csv
curl -O http://localhost:8000/jobs/{job_id}/download/calibration_summary.csv
```

### List All Jobs

```bash
curl http://localhost:8000/jobs
```

## Input Data Format

CSV file with WHO 2016 VA questionnaire format. Required columns depend on the questionnaire version but typically include `ID` and symptom columns (`i004a`, `i004b`, etc.).

For `vacalibration`-only jobs, input must have:
- `ID`: Death identifier
- `cause`: Cause of death string (e.g., "Birth asphyxia", "Neonatal sepsis")

## Output Files

| File | Description |
|------|-------------|
| `causes.csv` | Individual cause assignments (ID, cause) |
| `calibration_summary.csv` | CSMF comparison table |

## Job Types

1. **`openva`**: Run VA algorithm only, outputs cause assignments
2. **`vacalibration`**: Calibrate existing cause assignments
3. **`pipeline`**: Full workflow - openVA then vacalibration

## Supported Countries

CHAMPS network: Bangladesh, Ethiopia, Kenya, Mali, Mozambique, Sierra Leone, South Africa

Use `other` for countries outside CHAMPS.

## Broad Cause Categories

**Neonate (0-27 days):**
- `congenital_malformation`
- `pneumonia`
- `sepsis_meningitis_inf`
- `ipre` (intrapartum-related events)
- `prematurity`
- `other`

**Child (1-59 months):**
- `malaria`
- `pneumonia`
- `diarrhea`
- `severe_malnutrition`
- `hiv`
- `injury`
- `other_infections`
- `nn_causes` (neonatal causes)
- `other`

## Local Development Notes

### macOS/ARM64 Users: Stan Model Compilation

If you encounter Stan compilation errors when running vacalibration jobs locally, you may need to recompile the Stan models for your platform:

```r
library(rstan)
pkg_path <- find.package('vacalibration')
stan_dir <- file.path(pkg_path, 'stan')

# Compile seqcalib.stan
seqcalib <- stan_model(file.path(stan_dir, 'seqcalib.stan'))
saveRDS(seqcalib, file.path(stan_dir, 'seqcalib.rds'))

# Compile seqcalib_mmat.stan
seqcalib_mmat <- stan_model(file.path(stan_dir, 'seqcalib_mmat.stan'))
saveRDS(seqcalib_mmat, file.path(stan_dir, 'seqcalib_mmat.rds'))
```

This only needs to be done once after installing vacalibration.

**Note**: This is automatically handled in the Docker build for deployment.
