---
name: data-test
description: This skill validates data correctness and algorithm output for the COMSA Verbal Autopsy Calibration Platform. It should be used when verifying that input data formats are correct, algorithm outputs satisfy mathematical invariants (CSMF sums, credible intervals, cause counts), cause mapping works properly, and the vacalibration pipeline produces numerically correct results. This skill focuses exclusively on data and algorithm correctness, NOT frontend UI, deployment, or infrastructure.
---

# Data Test

## Overview

Data correctness validation for the COMSA Verbal Autopsy Calibration Platform. This skill provides R-based test scripts, standard operating procedures (SOPs), and expected-value references for verifying that the platform produces correct numerical results from input through output.

## When to Use This Skill

- Verifying sample data formats and column structures
- Validating cause mapping from specific causes to broad categories
- Testing that vacalibration CSMF outputs satisfy mathematical invariants
- Checking credible intervals, misclassification matrices, and ensemble outputs
- Adding new data correctness test cases
- Investigating numerical anomalies in calibration results
- Validating after changes to `backend/jobs/utils.R`, `backend/jobs/algorithms/vacalibration.R`, or `backend/jobs/processor.R`

## Test Categories

### 1. Input Data Validation

Verify that sample data files have correct formats, required columns, valid value ranges, and expected record counts.

**What is tested:**
- Frontend CSV files (`frontend/public/sample_*.csv`): ID and cause columns present, no NA/empty causes, expected record counts (1190 for neonate)
- Backend RDS files (`backend/data/sample_data/sample_vacalibration_*.rds`): `$data` and `$va_algo` fields present, binary indicator matrix structure (each row sums to 1), correct broad cause column names
- openVA RDS files (`backend/data/sample_data/sample_neonate_openva.rds`): WHO2016 format with ~350 columns, ID column, correct value encoding ("y", "n", ".")
- Cross-file consistency: all algorithm CSVs share identical ID sets

### 2. Cause Mapping Validation

Verify that `fix_causes_for_vacalibration()` and `safe_cause_map()` correctly transform specific cause names into broad cause binary indicator matrices.

**What is tested:**
- "Undetermined" maps to "other"
- All causes in sample CSVs map without error
- Output matrix has correct broad cause columns: neonate=6 (`congenital_malformation`, `pneumonia`, `sepsis_meningitis_inf`, `ipre`, `other`, `prematurity`), child=9 (`malaria`, `pneumonia`, `diarrhea`, `severe_malnutrition`, `hiv`, `injury`, `other`, `other_infections`, `nn_causes`)
- Binary indicator matrix: each row sums to exactly 1
- Total assignments equal total input records

### 3. Algorithm Output Validation

Verify that vacalibration produces mathematically correct outputs for single-algorithm and ensemble runs.

**What is tested:**
- **Uncalibrated CSMF**: sums to ~1.0 (tolerance 0.02), all values >= 0, has correct number of broad causes, matches raw input column means
- **Calibrated CSMF (posterior summary)**: mean sums to ~1.0 (tolerance 0.02), all values >= 0
- **Credible intervals**: lower <= mean <= upper for each cause, 0 <= lower, upper <= 1
- **Misclassification matrix**: all values >= 0, correct dimensions
- **Calibration effect**: calibrated values differ from uncalibrated (calibration actually changed something)
- **Ensemble mode**: requires >= 2 algorithms, produces per-algorithm + "ensemble" combined rows, per-algorithm misclassification matrices

### 4. Parameter Configuration Validation

Verify that algorithm parameter combinations are valid and defaults are applied correctly.

**What is tested:**
- `demo_configs.json` entries have valid country, age_group, algorithm, calib_model_type values
- Ensemble demos have >= 2 algorithms
- MCMC defaults: nMCMC=5000 >= 1000, nBurn=2000 < nMCMC, nThin >= 1
- Single-algorithm pipeline mode does not set ensemble=TRUE

## Running Tests

### Full Data Correctness Suite

Run the comprehensive R test script from the project root:

```bash
cd /Users/ericliu/projects5/comsa_dashboard && Rscript .claude/skills/data-test/scripts/test_data_correctness.R
```

Runtime: 3-8 minutes (runs actual MCMC sampling). Exit code 0 = all pass, 1 = failures.

### Quick Input-Only Validation (No MCMC)

To validate only input data and cause mapping without running vacalibration computation:

```bash
cd /Users/ericliu/projects5/comsa_dashboard && Rscript .claude/skills/data-test/scripts/test_data_correctness.R --input-only
```

Runtime: < 10 seconds.

### Ad-hoc Cause Mapping Check

To quickly test cause mapping for a specific CSV:

```bash
cd /Users/ericliu/projects5/comsa_dashboard && Rscript -e "
source('backend/jobs/utils.R')
library(vacalibration)
df <- read.csv('frontend/public/sample_interva_neonate.csv', stringsAsFactors=FALSE)
df <- fix_causes_for_vacalibration(df)
broad <- safe_cause_map(df, 'neonate')
cat('Columns:', paste(colnames(broad), collapse=', '), '\n')
cat('Row sums all 1:', all(rowSums(broad) == 1), '\n')
cat('Total records:', nrow(broad), '\n')
"
```

## Standard Operating Procedures (SOPs)

SOPs are documented in `references/sops.md`. Each SOP provides a step-by-step procedure for a specific validation scenario. SOPs are designed to be modified and extended by users.

**Available SOPs:**
1. **SOP-001: New Sample Data Validation** -- Validate a newly added sample CSV or RDS file
2. **SOP-002: Post-Algorithm-Change Validation** -- Full validation after modifying vacalibration logic
3. **SOP-003: New Country Validation** -- Verify vacalibration works for a newly added country
4. **SOP-004: Ensemble Configuration Validation** -- Verify multi-algorithm ensemble runs
5. **SOP-005: CSMF Anomaly Investigation** -- Investigate when CSMF values look suspicious

To add a new SOP, append to `references/sops.md` following the existing format.

## Expected Values Reference

Detailed expected output values for each sample dataset and algorithm configuration are documented in `references/expected_values.md`. This reference includes:

- Expected broad cause distributions for each algorithm's neonate sample data
- Expected CSMF ranges for standard configurations
- Known MCMC variability ranges
- Baseline uncalibrated CSMF values to compare against

Consult this reference when investigating whether specific output values are correct or anomalous.

## Adding New Test Cases

### Adding an R Test Assertion

Edit `scripts/test_data_correctness.R` and add assertions before the SUMMARY block:

```r
section("N. New Section Name")

test("description of what is being tested", {
  result <- some_function()
  !is.null(result) && abs(sum(result) - 1) < 0.01
})
```

### Adding a New SOP

Edit `references/sops.md` and append a new SOP following the template:

```markdown
### SOP-NNN: Title

**When to use:** Description of when this SOP applies
**Prerequisites:** What must be in place before starting
**Steps:**
1. Step one
2. Step two
...
**Expected outcome:** What success looks like
**If it fails:** Troubleshooting guidance
```

## Key Files

| File | Purpose |
|------|---------|
| `scripts/test_data_correctness.R` | Main R test script (input + algorithm validation) |
| `references/sops.md` | Modifiable Standard Operating Procedures |
| `references/expected_values.md` | Expected output values for sample data |
| `backend/jobs/utils.R` | Core utility functions under test |
| `backend/jobs/algorithms/vacalibration.R` | Vacalibration computation under test |
| `tests/test_vacalibration_backend.R` | Existing 138-assertion R test suite (complementary) |

## Relationship to comsa-test Skill

This skill focuses exclusively on **data and algorithm correctness**. The `comsa-test` skill covers the broader testing surface (API endpoints, frontend lint/build, integration checks, database tests). Use both skills together for comprehensive validation:

1. Run `data-test` to verify numerical correctness
2. Run `comsa-test` to verify system integration

## Resources

### scripts/
- `test_data_correctness.R` - Comprehensive R test script covering input validation, cause mapping, algorithm outputs, and mathematical invariants

### references/
- `sops.md` - Standard Operating Procedures for common validation scenarios, designed to be user-editable
- `expected_values.md` - Reference expected output values for each sample dataset and configuration
