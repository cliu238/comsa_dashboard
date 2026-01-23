# CLAUDE.md

> **Note:** ALWAYS Use uv to install packages and manage environment.
> **Note:** always use SIMPLEST code and structure, don't over enginnering
> **Note:** don't create unnecessary files. When creating new version of a file, archive or delete the legacy file
> **Note:** DO NOT ADD UNNECESSARY FEATURES! keep log simple

## Project: Verbal Autopsy Calibration Platform

### WHY
Web platform for processing verbal autopsy (VA) data and calibrating cause-of-death classifications. Enables researchers to submit jobs using openVA and vacalibration R packages, track job status, and retrieve results.

### WHAT
- **Backend**: R plumber API (required for openVA and vacalibration R packages)
- **Frontend**: React
- **Core packages**: openVA (VA data processing), vacalibration (Bayesian calibration of VA classifications)
- **Job system**: Long-running async jobs with status tracking and output management

### HOW
- Backend runs R plumber server exposing REST endpoints
- Frontend communicates with backend API for job submission, status polling, and result retrieval

## Development Principles

- **Simplicity first**: Use simplest code and structure possible. No over-engineering.
- **No feature creep**: Only implement what's explicitly requested. Keep logging minimal.
- **Clean codebase**: Delete or archive legacy files when creating new versions. Don't create unnecessary files.

## Folder Structure

```
comsa_dashboard/
├── backend/                 # R plumber API
│   ├── plumber.R           # Main API endpoints
│   ├── jobs/               # Job processing logic
│   └── data/               # Uploaded files & job outputs
├── frontend/               # React app
│   ├── src/
│   │   ├── components/     # React components
│   │   ├── pages/          # Page components (Jobs, Results)
│   │   └── api/            # API client functions
│   └── public/
```

## Documentation References
