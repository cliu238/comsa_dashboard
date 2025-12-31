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

```bash
# Full pipeline with sample data (demo)
curl -X POST "http://localhost:8000/jobs/demo?job_type=pipeline&age_group=neonate"

# With custom data
curl -X POST "http://localhost:8000/jobs" \
  -F "file=@data.csv" \
  -F "job_type=pipeline" \
  -F "algorithm=InterVA" \
  -F "age_group=neonate" \
  -F "country=Mozambique"
```

**Parameters:**
| Parameter | Values | Default |
|-----------|--------|---------|
| `job_type` | `openva`, `vacalibration`, `pipeline` | `pipeline` |
| `algorithm` | `InterVA`, `InSilicoVA` | `InterVA` |
| `age_group` | `neonate`, `child` | `neonate` |
| `country` | CHAMPS countries or `other` | `Mozambique` |

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
