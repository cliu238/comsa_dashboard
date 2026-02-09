# Standard Operating Procedures (SOPs)

These SOPs provide step-by-step procedures for common data validation scenarios. Each SOP is designed to be modified and extended. To add a new SOP, append it at the bottom following the same format.

---

### SOP-001: New Sample Data Validation

**When to use:** A new sample CSV or RDS file has been added to the project (e.g., a new algorithm's sample data, a new age group, or updated sample records).

**Prerequisites:**
- The new file is placed in `frontend/public/` (for CSV) or `backend/data/sample_data/` (for RDS)
- R environment with `vacalibration` package installed

**Steps:**

1. **Verify file existence and format**
   ```bash
   # For CSV
   head -5 frontend/public/sample_newalgo_neonate.csv
   # Check: first row is header with ID,cause (or ID,cause1)
   # Check: subsequent rows have non-empty values
   ```

2. **Check CSV structure in R**
   ```r
   df <- read.csv("frontend/public/sample_newalgo_neonate.csv", stringsAsFactors=FALSE)
   stopifnot("ID" %in% names(df))
   stopifnot("cause" %in% names(df) || "cause1" %in% names(df))
   stopifnot(!any(is.na(df$cause)))
   stopifnot(!any(df$cause == ""))
   cat("Records:", nrow(df), "\n")
   cat("Unique causes:", paste(sort(unique(df$cause)), collapse=", "), "\n")
   ```

3. **Test cause mapping**
   ```r
   source("backend/jobs/utils.R")
   library(vacalibration)
   df_fixed <- fix_causes_for_vacalibration(df)
   broad <- safe_cause_map(df_fixed, "neonate")  # or "child"
   stopifnot(all(rowSums(broad) == 1))
   cat("Broad cause columns:", paste(colnames(broad), collapse=", "), "\n")
   ```

4. **For RDS files, verify internal structure**
   ```r
   rds <- readRDS("backend/data/sample_data/sample_vacalibration_newalgo_neonate.rds")
   stopifnot(!is.null(rds$data))
   stopifnot(!is.null(rds$va_algo))
   stopifnot(all(rowSums(rds$data) == 1))
   cat("Algorithm:", rds$va_algo, "\n")
   cat("Records:", nrow(rds$data), "\n")
   cat("Columns:", paste(colnames(rds$data), collapse=", "), "\n")
   ```

5. **Run full test suite to confirm no regressions**
   ```bash
   Rscript .claude/skills/data-test/scripts/test_data_correctness.R
   ```

**Expected outcome:** All checks pass. New file integrates cleanly with existing test infrastructure.

**If it fails:**
- Missing columns: Check CSV header row for typos
- Cause mapping errors: Compare cause names against known mappings in `safe_cause_map()`
- Row sums != 1: Some causes may not map to any broad category -- check `fix_causes_for_vacalibration()` for missing mappings

---

### SOP-002: Post-Algorithm-Change Validation

**When to use:** After modifying `backend/jobs/algorithms/vacalibration.R`, `backend/jobs/utils.R`, or `backend/jobs/processor.R`.

**Prerequisites:**
- Changes have been saved to the source files
- R environment with `vacalibration` package installed

**Steps:**

1. **Verify R files parse without errors**
   ```bash
   Rscript -e "parse('backend/jobs/utils.R'); cat('utils.R OK\n')"
   Rscript -e "parse('backend/jobs/processor.R'); cat('processor.R OK\n')"
   ```

2. **Run input-only validation (fast check)**
   ```bash
   Rscript .claude/skills/data-test/scripts/test_data_correctness.R --input-only
   ```

3. **Run full test suite including MCMC computation**
   ```bash
   Rscript .claude/skills/data-test/scripts/test_data_correctness.R
   ```

4. **Compare key outputs against expected values**
   - Consult `references/expected_values.md` for baseline CSMF ranges
   - Uncalibrated CSMFs should match input data column means exactly
   - Calibrated CSMFs should differ from uncalibrated (calibration effect)

5. **Run the existing 138-assertion test suite for additional coverage**
   ```bash
   Rscript tests/test_vacalibration_backend.R
   ```

**Expected outcome:** All assertions pass. CSMF values fall within expected ranges documented in `references/expected_values.md`.

**If it fails:**
- Parse errors: Syntax issue in modified file -- fix and retry
- CSMF sum != 1: Check for normalization bugs in modified code
- Credible interval violations: MCMC convergence issue -- try increasing nMCMC
- Calibration effect missing: Calibration logic may be bypassed

---

### SOP-003: New Country Validation

**When to use:** Verifying that vacalibration works for a country not yet tested, or after a new country is added to the supported list.

**Prerequisites:**
- Country name follows exact spelling: "Bangladesh", "Ethiopia", "Kenya", "Mali", "Mozambique", "Sierra Leone", "South Africa", "other"
- Sample data available (any algorithm)

**Steps:**

1. **Run vacalibration for the new country**
   ```r
   source("backend/jobs/utils.R")
   library(vacalibration)
   sample <- readRDS("backend/data/sample_data/sample_vacalibration_interva_neonate.rds")
   va_input <- setNames(list(sample$data), sample$va_algo)

   result <- vacalibration(
     va_data = va_input,
     age_group = "neonate",
     country = "NewCountryName",
     calibmodel.type = "Mmatprior",
     ensemble = TRUE,
     nMCMC = 5000, nBurn = 2000,
     plot_it = FALSE, verbose = FALSE
   )
   ```

2. **Validate CSMF mathematical invariants**
   ```r
   uncalib <- result$p_uncalib[1, ]
   cat("Uncalibrated CSMF sum:", sum(uncalib), "\n")
   stopifnot(abs(sum(uncalib) - 1) < 0.02)
   stopifnot(all(uncalib >= 0))

   calib_mean <- result$pcalib_postsumm[1, "postmean", ]
   cat("Calibrated CSMF sum:", sum(calib_mean), "\n")
   stopifnot(abs(sum(calib_mean) - 1) < 0.02)

   calib_low <- result$pcalib_postsumm[1, "lowcredI", ]
   calib_high <- result$pcalib_postsumm[1, "upcredI", ]
   stopifnot(all(calib_low <= calib_mean + 1e-6))
   stopifnot(all(calib_high >= calib_mean - 1e-6))
   ```

3. **Check misclassification matrix**
   ```r
   mmat <- result$Mmat.asDirich
   stopifnot(all(mmat >= 0))
   cat("Misclass matrix dimensions:", paste(dim(mmat), collapse="x"), "\n")
   ```

4. **Compare against Mozambique baseline** (the default test country)
   - Uncalibrated CSMFs should be identical (same input data)
   - Calibrated CSMFs will differ (country-specific calibration model)
   - Both should satisfy all mathematical invariants

**Expected outcome:** All invariants hold. Country-specific calibration produces different calibrated values than default Mozambique baseline.

**If it fails:**
- Error in `vacalibration()`: Country name may be misspelled or not supported
- CSMF violations: Country-specific calibration model may have convergence issues -- try increasing nMCMC
- Identical calibrated/uncalibrated: Country calibration data may be missing

---

### SOP-004: Ensemble Configuration Validation

**When to use:** Testing multi-algorithm ensemble runs or verifying that ensemble mode produces combined results correctly.

**Prerequisites:**
- At least 2 algorithm sample datasets available
- R environment with `vacalibration` package installed

**Steps:**

1. **Load multiple algorithm samples**
   ```r
   source("backend/jobs/utils.R")
   library(vacalibration)
   interva <- readRDS("backend/data/sample_data/sample_vacalibration_interva_neonate.rds")
   insilico <- readRDS("backend/data/sample_data/sample_vacalibration_insilicova_neonate.rds")

   va_input <- list(
     "InterVA" = interva$data,
     "InSilicoVA" = insilico$data
   )
   ```

2. **Run ensemble vacalibration**
   ```r
   result <- vacalibration(
     va_data = va_input,
     age_group = "neonate",
     country = "Mozambique",
     calibmodel.type = "Mmatprior",
     ensemble = TRUE,
     nMCMC = 5000, nBurn = 2000,
     plot_it = FALSE, verbose = FALSE
   )
   ```

3. **Validate ensemble-specific outputs**
   ```r
   # p_uncalib should have N+1 rows (N algorithms + "ensemble")
   cat("p_uncalib rows:", nrow(result$p_uncalib), "\n")
   stopifnot(nrow(result$p_uncalib) == 3)  # InterVA + InSilicoVA + ensemble

   # Each row sums to ~1
   for (i in 1:nrow(result$p_uncalib)) {
     s <- sum(result$p_uncalib[i, ])
     cat(sprintf("  Row %d (%s) sum: %.4f\n", i, rownames(result$p_uncalib)[i], s))
     stopifnot(abs(s - 1) < 0.02)
   }

   # pcalib_postsumm first dimension should also be N+1
   cat("pcalib_postsumm dim[1]:", dim(result$pcalib_postsumm)[1], "\n")
   stopifnot(dim(result$pcalib_postsumm)[1] == 3)

   # Misclassification matrix should be 3D for ensemble
   cat("Mmat dimensions:", paste(dim(result$Mmat.asDirich), collapse="x"), "\n")
   ```

4. **Verify single-algorithm fails with ensemble=TRUE**
   ```r
   single_input <- list("InterVA" = interva$data)
   err <- tryCatch(
     vacalibration(va_data = single_input, age_group = "neonate",
                   country = "Mozambique", ensemble = TRUE,
                   nMCMC = 2000, nBurn = 1000, plot_it = FALSE, verbose = FALSE),
     error = function(e) e$message
   )
   cat("Single algo + ensemble error:", err, "\n")
   # Should fail with "at least 2 algorithms" message
   ```

**Expected outcome:** Ensemble produces N+1 rows in outputs. Each algorithm's CSMF and the combined "ensemble" row all satisfy mathematical invariants.

**If it fails:**
- Wrong number of rows: Check that va_data list has correct named entries
- Ensemble row missing: vacalibration package may not support ensemble for this configuration
- 3D matrix issues: Misclassification matrix dimensions depend on ensemble mode

---

### SOP-005: CSMF Anomaly Investigation

**When to use:** When CSMF values look suspicious (e.g., one cause dominates, sum is far from 1, negative values, or results don't match expectations).

**Prerequisites:**
- The anomalous result (either from a test failure or from inspecting job output)

**Steps:**

1. **Check input data quality**
   ```r
   df <- read.csv("path/to/input.csv", stringsAsFactors=FALSE)
   cat("Total records:", nrow(df), "\n")
   cat("Unique causes:", length(unique(df$cause)), "\n")
   print(table(df$cause))
   # Look for: very skewed distributions, unexpected cause names, NA values
   ```

2. **Verify cause mapping**
   ```r
   source("backend/jobs/utils.R")
   library(vacalibration)
   df_fixed <- fix_causes_for_vacalibration(df)
   broad <- safe_cause_map(df_fixed, "neonate")
   cat("Column sums (expected CSMF before calibration):\n")
   print(colMeans(broad))
   # These column means ARE the uncalibrated CSMF
   ```

3. **Compare uncalibrated CSMF to column means**
   ```r
   # Run vacalibration
   va_input <- list("algo" = broad)
   result <- vacalibration(va_data = va_input, age_group = "neonate",
                           country = "Mozambique", calibmodel.type = "Mmatprior",
                           ensemble = TRUE, nMCMC = 5000, nBurn = 2000,
                           plot_it = FALSE, verbose = FALSE)

   uncalib <- result$p_uncalib[1, ]
   expected <- colMeans(broad)
   diff <- uncalib - expected
   cat("Uncalib vs column means difference:\n")
   print(round(diff, 6))
   # Should be essentially zero -- if not, there is a bug
   ```

4. **Check MCMC convergence**
   - If calibrated values are extremely different from uncalibrated, MCMC may not have converged
   - Try increasing nMCMC (e.g., 10000) and nBurn (e.g., 5000)
   - Pareto k diagnostic warnings are common but usually benign
   - If results change dramatically with more MCMC iterations, convergence was insufficient

5. **Compare against baseline expected values**
   - Consult `references/expected_values.md` for known-good CSMF ranges
   - If values fall outside expected ranges, the anomaly is real

**Expected outcome:** Root cause of CSMF anomaly identified. Either input data issue, cause mapping bug, or MCMC convergence problem.

**If it fails:**
- Column means do not match uncalibrated CSMF: Bug in vacalibration's uncalibrated computation
- Calibrated values out of [0,1] range: MCMC convergence failure
- Sum far from 1.0: Normalization bug -- check if any causes were dropped during processing

---

## Template for New SOPs

Copy this template to add a new SOP:

```markdown
### SOP-NNN: Title

**When to use:** Description of when this SOP applies

**Prerequisites:** What must be in place before starting

**Steps:**

1. **Step title**
   ```bash or r
   code
   ```

2. **Next step**
   ...

**Expected outcome:** What success looks like

**If it fails:** Troubleshooting guidance
```
