# Common Test Failures and Resolutions

Failure patterns observed from project logs, organized by test type.

## R Test Failures

### "could not find function 'vacalibration'"
- **Cause**: vacalibration R package not installed
- **Fix**: Install from the appropriate source (may be a custom/GitHub package, not CRAN)

### "Run this test from the project root or backend/ directory"
- **Cause**: Wrong working directory
- **Fix**: Run from `/Users/ericliu/projects5/comsa_dashboard/` or `backend/`

### "object 'fix_causes_for_vacalibration' not found"
- **Cause**: `backend/jobs/utils.R` failed to source
- **Fix**: Verify utils.R exists and has no syntax errors: `Rscript -e "parse('backend/jobs/utils.R'); cat('OK\n')"`

### Ensemble Calibration Errors
- **Error**: `"Ensemble calibration requires at least 2 algorithms"`
- **Cause**: Single-algorithm job submitted with `ensemble=TRUE`, or `run_vacalibration()` only processing the first algorithm instead of all
- **Resolution**: Backend must loop over ALL algorithms and build a multi-entry `va_data` list before calling `vacalibration()`

### Pareto k Diagnostic Warnings
- **Warning**: `"Some Pareto k diagnostic values are too high"`
- **Cause**: Expected statistical warning from the `loo` package during MCMC diagnostics
- **Resolution**: No action needed. This is informational, not an error. Tests should still pass.

### MCMC Convergence Warnings
- **Cause**: MCMC chains may show convergence warnings with small nMCMC values used in tests
- **Note**: Warnings are expected with test-sized MCMC runs (nMCMC=2000-5000); only errors are failures

### Sample Data Not Found
- **Cause**: Missing CSV files in `frontend/public/` or RDS files in `backend/data/sample_data/`
- **Fix**: Verify sample data files exist:
  - `frontend/public/sample_interva_neonate.csv`
  - `frontend/public/sample_insilicova_neonate.csv`
  - `frontend/public/sample_eava_neonate.csv`
  - `backend/data/sample_data/sample_vacalibration_interva_neonate.rds`
  - `backend/data/sample_data/sample_vacalibration_insilicova_neonate.rds`
  - `backend/data/sample_data/sample_vacalibration_eava_neonate.rds`

### R File Path/Parse Errors
- **Error**: `"cannot open the connection"` or `"unrecognized escape"`
- **Cause**: Wrong file paths or incorrect R string escaping in `-e` flag
- **Resolution**: Verify paths exist; use proper escaping in inline R code (avoid backslashes in `-e` strings)

## Backend API Test Failures

### "Backend appears to be down"
- **Cause**: R plumber server not running
- **Fix**: Start the backend: `cd /Users/ericliu/projects5/comsa_dashboard/backend && Rscript run.R`

### "Job did not complete within timeout"
- **Cause**: Job processing takes longer than 60s (common with vacalibration MCMC)
- **Fix**: Check backend logs (`tail backend.log`), verify R packages work correctly

### "Demo job submission returned status 500"
- **Cause**: Backend error during job creation
- **Fix**: Check `backend.log` for R errors, verify `demo_configs.json` is valid JSON

### 404 Resource Not Found
- **Error**: `"404 - Resource Not Found"` from API calls
- **Cause**: Wrong endpoint paths or parameter encoding issues
- **Resolution**: Use query parameters instead of JSON body for plumber endpoints; check route definitions in `plumber.R`

### Curl Escaping Issues
- **Error**: `"curl: option : blank argument where content is expected"`
- **Cause**: Backslash escaping in curl commands when run from Bash
- **Resolution**: Use single quotes around URLs and JSON data in curl commands

## Integration Check Failures

### "Frontend calls endpoints that don't exist in backend"
- **Cause**: Frontend references an endpoint not defined in plumber.R
- **Fix**: Add the missing endpoint to backend or update frontend API client

### "Backend file not found" / "Frontend file not found"
- **Cause**: Wrong project root or files moved
- **Fix**: Verify `--project-root` points to `/Users/ericliu/projects5/comsa_dashboard`

## Frontend Failures

### ESLint Errors
- **Fix**: Run `npm run lint` to see specific issues, then fix in source files

### Vite Build Errors
- **Common cause**: Import errors, missing dependencies
- **Fix**: Run `npm install` first, then check import paths

### JavaScript Runtime Errors (from browser testing)

**`log.join is not a function`** (in `JobDetail.jsx`)
- **Cause**: `unbox()` utility converts single-element arrays to scalars; `join()` fails on strings
- **Resolution**: Ensure `log` is always an array before calling `.join()`. Use `Array.isArray(log) ? log : [log]` pattern.

### MCMC Parameter Input Bugs
- **Symptom**: Cannot set MCMC iterations to certain values; burn-in shows unexpected values
- **Cause**: `max={50000}` constraint on number input; `min=100` with `step=500` creates misaligned grid
- **Resolution**: Remove `max` constraint; set `min=0` + `step=1000` for clean input grid

## Debugging Strategies

### Diagnosing vacalibration Computation Failures
1. Check if the R packages load: `Rscript -e "library(vacalibration); library(openVA)"`
2. Run the R unit test to see which section fails
3. Check if sample data exists at expected paths
4. Try running a minimal vacalibration call in R console to isolate the issue

### Diagnosing API Issues
1. Check server health: `curl -s http://localhost:8000/health`
2. Check backend logs: `tail /Users/ericliu/projects5/comsa_dashboard/backend.log`
3. Verify plumber route definitions match the URL being called
4. Log `req$args` in plumber endpoint to see what parameters arrive

### Diagnosing Frontend Rendering Errors
1. Check browser console for JavaScript errors
2. Use chrome-in-claude MCP to inspect page elements
3. Verify API responses are in expected format (arrays vs scalars)
4. Check `VITE_API_BASE_URL` in `.env.production` matches backend URL

### Interpreting R Warnings vs Errors
- **Warnings** (yellow text, "Warning message:"): Usually non-fatal. Pareto k diagnostics, MCMC convergence notes are expected.
- **Errors** (red text, stops execution): Actual failures that need fixing.
- The R test suite only counts errors as failures; warnings are logged but do not fail tests.
