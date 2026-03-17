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
- **No silent test skips**: Tests must never silently skip. If a test needs an external dependency (backend, DB), auto-start it or fail loudly.

## Behavior

> **Note:** Do not trust documentation or assumptions for critical values (service names, data formats, API behavior). Verify against actual source code or runtime output before using.
> **Note:** Do not ask questions whose answers are obvious from context or irrelevant to the task. If the user gave clear instructions, execute them.

## Testing

> **Note:** When a plan identifies edge cases or boundary conditions, write a unit test for each BEFORE implementing. "All tests pass" only proves existing tests pass — missing tests hide bugs.
> **Note:** IMPORTANT: Before running tests that require the backend (API tests, Playwright E2E), check if the server is running with `lsof -ti:8000`. If not running, start it with `cd backend && Rscript run.R &`. **DO NOT ask for permission — just check and start it.** If the backend cannot be started, check other options. NEVER skip tests because the server is not running.

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

## Environment Variables

- `UAT_URL`: Defined in `.env`

## Documentation References
