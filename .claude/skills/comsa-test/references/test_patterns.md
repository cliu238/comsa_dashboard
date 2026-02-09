# Test Patterns and Adding New Tests

## Domain Knowledge for Tests

### Vacalibration Parameters
- **Algorithms**: InterVA, InSilicoVA, EAVA
- **Age groups**: neonate, child
- **Countries**: Bangladesh, Ethiopia, Kenya, Mali, Mozambique, Sierra Leone, South Africa, other
- **Calibration model types**: Mmatprior (default, Bayesian prior on misclassification), Mmatfixed (fixed misclassification)
- **MCMC settings**: nMCMC (default 5000), nBurn (default 2000), nThin (default 1)

### Expected Output Structure
- `p_uncalib`: uncalibrated CSMF (cause-specific mortality fractions), each row sums to ~1
- `pcalib_postsumm`: calibrated posterior summary with dimensions [algorithm, statistic, cause]
  - Statistics: postmean, lowcredI, upcredI
- `Mmat.asDirich`: misclassification matrix (2D for single algo, 3D for ensemble)
- Ensemble results: rows for each algorithm + "ensemble" combined estimate

### Neonate Broad Causes (6)
`congenital_malformation`, `pneumonia`, `sepsis_meningitis_inf`, `ipre`, `other`, `prematurity`

### Key Validation Rules
- Uncalibrated CSMF values must sum to ~1 (tolerance: 0.01)
- Calibrated mean values must sum to ~1 (tolerance: 0.01)
- All CSMF values must be >= 0
- Credible interval: lower <= mean <= upper
- Ensemble requires >= 2 algorithms
- Ensemble p_uncalib has N+1 rows (N algorithms + "ensemble")

## R Unit Test Framework

The project uses a custom lightweight test framework (NOT testthat). The helpers are defined at the top of `tests/test_vacalibration_backend.R`.

### Helper Functions

**`test(desc, expr)`** - Run a single assertion:
```r
test("description of what is being tested", {
  result <- some_function()
  !is.null(result) && result$value == expected
})
```
The expression must return `TRUE` for the test to pass. Any error or `FALSE` return counts as failure.

**`section(title)`** - Group related tests:
```r
section("N. Section Title")
```

### Adding a New R Test Section

1. Open `tests/test_vacalibration_backend.R`
2. Add a new section before the SUMMARY block at the end:

```r
# =============================================================================
# N. DESCRIPTIVE SECTION NAME
# =============================================================================
section("N. Descriptive Section Name")

# Setup for this section
data <- prepare_test_data()

# Individual assertions
test("data has expected columns", all(c("ID", "cause") %in% names(data)))

test("computation returns valid result", {
  result <- run_computation(data)
  !is.null(result) && abs(sum(result) - 1) < 0.01
})

test("edge case handled correctly", {
  edge_result <- tryCatch(
    problematic_function(bad_input),
    error = function(e) "error_caught"
  )
  identical(edge_result, "error_caught")
})
```

3. The test framework auto-counts pass/fail. No registration needed.

### Testing Patterns for vacalibration

**Testing a new algorithm**:
```r
section("N. New Algorithm Test")

# Load or create input data
new_algo_csv <- file.path(frontend_dir, "public", "sample_newalgo_neonate.csv")
test("New algo sample CSV exists", file.exists(new_algo_csv))

new_df <- read.csv(new_algo_csv, stringsAsFactors = FALSE)
test("New algo has ID column", "ID" %in% names(new_df))
test("New algo has cause column", "cause" %in% names(new_df))

# Fix causes and map to broad categories
new_fixed <- fix_causes_for_vacalibration(new_df)
new_broad <- safe_cause_map(df = new_fixed, age_group = "neonate")

# Run vacalibration
va_input <- list("newalgo" = new_broad)
result <- tryCatch(
  vacalibration(
    va_data = va_input,
    age_group = "neonate",
    country = "Mozambique",
    calibmodel.type = "Mmatprior",
    ensemble = TRUE,
    nMCMC = 5000,
    nBurn = 2000,
    plot_it = FALSE,
    verbose = FALSE
  ),
  error = function(e) { cat("  ERROR:", e$message, "\n"); NULL }
)

test("New algo vacalibration returns non-NULL result", !is.null(result))
if (!is.null(result)) {
  test("Uncalibrated CSMF sums to ~1", abs(sum(result$p_uncalib[1, ]) - 1) < 0.01)
  test("Calibrated mean sums to ~1",
       abs(sum(result$pcalib_postsumm[1, "postmean", ]) - 1) < 0.01)
}
```

**Testing a new country**:
```r
result_new_country <- tryCatch(
  vacalibration(
    va_data = va_input,
    age_group = "neonate",
    country = "NewCountry",
    calibmodel.type = "Mmatprior",
    ensemble = TRUE,
    nMCMC = 2000,
    nBurn = 1000,
    plot_it = FALSE,
    verbose = FALSE
  ),
  error = function(e) { cat("  ERROR:", e$message, "\n"); NULL }
)
test("vacalibration succeeds for NewCountry", !is.null(result_new_country))
```

**Testing error handling**:
```r
invalid_result <- tryCatch(
  some_function(invalid_input),
  error = function(e) "error_caught"
)
test("Invalid input raises error", identical(invalid_result, "error_caught"))
```

## Backend API Test Patterns

### Adding a New Endpoint Test

Edit `.claude/skills/va-platform-test/scripts/test_backend.py`:

```python
def test_new_endpoint(self) -> bool:
    """Test GET /new-endpoint"""
    self.log_info("Testing GET /new-endpoint")
    try:
        response = requests.get(f"{self.base_url}/new-endpoint", timeout=5)
        if response.status_code != 200:
            self.log_fail(f"Returned status {response.status_code}")
            return False

        data = response.json()
        # Validate response structure
        required_fields = ["field1", "field2"]
        missing = [f for f in required_fields if f not in data]
        if missing:
            self.log_fail(f"Response missing fields: {missing}")
            return False

        self.log_pass("New endpoint working correctly")
        return True
    except requests.exceptions.RequestException as e:
        self.log_fail(f"Failed: {e}")
        return False
```

Then call from `run_all_tests()`.

### API Testing Flow Pattern

The standard API test flow follows the job lifecycle:
1. Health check (verify server is up)
2. List jobs (verify endpoint works)
3. Submit demo job (create a job)
4. Poll status (wait for completion)
5. Check log (verify logging)
6. Get results (verify output)
7. Test error handling (nonexistent job)

## Integration Check Patterns

### Adding a New Check

Edit `.claude/skills/va-platform-test/scripts/check_integration.py`:

```python
def check_new_feature(self):
    """Check new feature alignment"""
    self.log_info("Checking new feature...")
    backend_content = self.backend_file.read_text()
    frontend_content = self.frontend_file.read_text()

    # Parse and compare specific patterns
    if "expected_pattern" in backend_content and "expected_pattern" in frontend_content:
        self.log_pass("New feature aligned between frontend and backend")
    else:
        self.log_warn("New feature may be misaligned")
```

Then call from `run_all_checks()`.

## Common Testing Workflows from Logs

### Ad-hoc R Testing
Write inline `Rscript -e '...'` commands to test specific functions quickly:
```bash
Rscript -e "source('backend/jobs/utils.R'); df <- data.frame(ID='t1', cause='Undetermined'); print(fix_causes_for_vacalibration(df))"
```

### Backend Syntax Check Before Restart
Always verify R files parse correctly before restarting the server:
```bash
cd /Users/ericliu/projects5/comsa_dashboard/backend
Rscript -e "parse('plumber.R'); cat('OK\n')"
Rscript -e "parse('jobs/processor.R'); cat('OK\n')"
Rscript -e "parse('jobs/utils.R'); cat('OK\n')"
```

### API Testing Flow
```bash
# 1. Start server
cd /Users/ericliu/projects5/comsa_dashboard/backend && Rscript run.R &

# 2. Wait and health check
sleep 5
curl -s http://localhost:8000/health

# 3. Submit demo job
curl -s -X POST 'http://localhost:8000/jobs/demo?job_type=pipeline&algorithm=["InterVA"]&age_group=neonate&calib_model_type=Mmatprior&ensemble=FALSE'

# 4. Poll status (replace JOB_ID)
curl -s "http://localhost:8000/jobs/$JOB_ID/status"

# 5. Get results when complete
curl -s "http://localhost:8000/jobs/$JOB_ID/results"
```

### Build Verification After Frontend Changes
Always run build after frontend changes to catch production issues:
```bash
cd /Users/ericliu/projects5/comsa_dashboard/frontend
npm run lint && npm run build
```
