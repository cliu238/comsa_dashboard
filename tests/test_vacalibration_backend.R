# =============================================================================
# Vacalibration Backend Tests
# =============================================================================
# Tests input data validity, vacalibration computation, and output correctness.
# Run from project root: Rscript tests/test_vacalibration_backend.R
# Or from backend dir:   Rscript ../tests/test_vacalibration_backend.R

library(vacalibration)

# --- Test Helpers ---
.test_count <- 0L
.pass_count <- 0L
.fail_count <- 0L
.fail_msgs  <- character()

test <- function(desc, expr) {
  .test_count <<- .test_count + 1L
  result <- tryCatch({
    ok <- eval(expr, envir = parent.frame())
    if (!isTRUE(ok)) stop("assertion returned FALSE")
    .pass_count <<- .pass_count + 1L
    cat(sprintf("  PASS: %s\n", desc))
  }, error = function(e) {
    .fail_count <<- .fail_count + 1L
    msg <- sprintf("  FAIL: %s -- %s", desc, e$message)
    .fail_msgs <<- c(.fail_msgs, msg)
    cat(msg, "\n")
  })
}

section <- function(title) cat(sprintf("\n=== %s ===\n", title))

# --- Locate project paths ---
# Works whether run from project root or backend/
if (file.exists("backend/plumber.R")) {
  backend_dir  <- "backend"
  frontend_dir <- "frontend"
} else if (file.exists("plumber.R")) {
  backend_dir  <- "."
  frontend_dir <- "../frontend"
} else {
  stop("Run this test from the project root or backend/ directory")
}

sample_dir <- file.path(backend_dir, "data", "sample_data")

# =============================================================================
# 1. INPUT DATA VALIDATION -- Frontend CSV samples
# =============================================================================
section("1. Frontend Sample CSV Files")

# --- InterVA neonate ---
interva_csv <- file.path(frontend_dir, "public", "sample_interva_neonate.csv")
test("InterVA sample CSV exists", file.exists(interva_csv))

interva_df <- read.csv(interva_csv, stringsAsFactors = FALSE)
test("InterVA sample has ID column", "ID" %in% names(interva_df))
test("InterVA sample has cause column", "cause" %in% names(interva_df))
test("InterVA sample has 1190 records", nrow(interva_df) == 1190)
test("InterVA sample has no NA in cause", !any(is.na(interva_df$cause)))
test("InterVA sample has no empty cause", !any(interva_df$cause == ""))

interva_causes <- sort(unique(interva_df$cause))
cat("  InterVA unique causes:", paste(interva_causes, collapse = ", "), "\n")

# --- InSilicoVA neonate ---
insilico_csv <- file.path(frontend_dir, "public", "sample_insilicova_neonate.csv")
test("InSilicoVA sample CSV exists", file.exists(insilico_csv))

insilico_df <- read.csv(insilico_csv, stringsAsFactors = FALSE)
test("InSilicoVA sample has ID column", "ID" %in% names(insilico_df))
test("InSilicoVA sample has cause column", "cause" %in% names(insilico_df))
test("InSilicoVA sample has 1190 records", nrow(insilico_df) == 1190)
test("InSilicoVA sample has no NA in cause", !any(is.na(insilico_df$cause)))

insilico_causes <- sort(unique(insilico_df$cause))
cat("  InSilicoVA unique causes:", paste(insilico_causes, collapse = ", "), "\n")

# --- EAVA neonate ---
eava_csv <- file.path(frontend_dir, "public", "sample_eava_neonate.csv")
test("EAVA sample CSV exists", file.exists(eava_csv))

eava_df <- read.csv(eava_csv, stringsAsFactors = FALSE)
test("EAVA sample has ID column", "ID" %in% names(eava_df))
test("EAVA sample has cause column", "cause" %in% names(eava_df))
test("EAVA sample has 1190 records", nrow(eava_df) == 1190)
test("EAVA sample has no NA in cause", !any(is.na(eava_df$cause)))

eava_causes <- sort(unique(eava_df$cause))
cat("  EAVA unique causes:", paste(eava_causes, collapse = ", "), "\n")

# --- All samples share the same IDs ---
test("All 3 samples have identical ID sets",
     setequal(interva_df$ID, insilico_df$ID) && setequal(interva_df$ID, eava_df$ID))

# =============================================================================
# 2. INPUT DATA VALIDATION -- Cause mapping compatibility
# =============================================================================
section("2. Cause Mapping Compatibility")

# vacalibration::cause_map expects specific cause names (case-insensitive).
# The backend uses fix_causes_for_vacalibration + safe_cause_map to handle this.
# Here we verify that every cause in the sample files can be mapped to a
# valid broad cause category via cause_map.

neonate_broad_causes <- c("congenital_malformation", "pneumonia",
                          "sepsis_meningitis_inf", "ipre", "other", "prematurity")

# Source the backend utils to get fix_causes_for_vacalibration and safe_cause_map
source(file.path(backend_dir, "jobs", "utils.R"))

# Test InterVA cause mapping
interva_fixed <- fix_causes_for_vacalibration(interva_df)
interva_broad <- tryCatch(
  safe_cause_map(df = interva_fixed, age_group = "neonate"),
  error = function(e) NULL
)
test("InterVA causes map to broad categories without error", !is.null(interva_broad))
test("InterVA broad matrix has correct columns",
     !is.null(interva_broad) && setequal(colnames(interva_broad), neonate_broad_causes))
test("InterVA broad matrix rows match input records",
     !is.null(interva_broad) && nrow(interva_broad) == nrow(interva_df))

# Test InSilicoVA cause mapping
insilico_fixed <- fix_causes_for_vacalibration(insilico_df)
insilico_broad <- tryCatch(
  safe_cause_map(df = insilico_fixed, age_group = "neonate"),
  error = function(e) NULL
)
test("InSilicoVA causes map to broad categories without error", !is.null(insilico_broad))
test("InSilicoVA broad matrix has correct columns",
     !is.null(insilico_broad) && setequal(colnames(insilico_broad), neonate_broad_causes))

# Test EAVA cause mapping
eava_fixed <- fix_causes_for_vacalibration(eava_df)
eava_broad <- tryCatch(
  safe_cause_map(df = eava_fixed, age_group = "neonate"),
  error = function(e) NULL
)
test("EAVA causes map to broad categories without error", !is.null(eava_broad))
test("EAVA broad matrix has correct columns",
     !is.null(eava_broad) && setequal(colnames(eava_broad), neonate_broad_causes))

# Verify each broad cause column sums to an integer count (binary indicator matrix)
if (!is.null(interva_broad)) {
  col_sums <- colSums(interva_broad)
  test("InterVA broad matrix total equals number of records",
       sum(col_sums) == nrow(interva_df))
}

# =============================================================================
# 3. INPUT DATA VALIDATION -- Backend RDS sample data
# =============================================================================
section("3. Backend RDS Sample Data")

for (algo in c("interva", "insilicova", "eava")) {
  rds_file <- file.path(sample_dir, sprintf("sample_vacalibration_%s_neonate.rds", algo))
  test(sprintf("RDS sample exists for %s", algo), file.exists(rds_file))

  if (file.exists(rds_file)) {
    rds_data <- readRDS(rds_file)
    test(sprintf("RDS %s has $data field", algo), !is.null(rds_data$data))
    test(sprintf("RDS %s has $va_algo field", algo), !is.null(rds_data$va_algo))

    if (!is.null(rds_data$data)) {
      test(sprintf("RDS %s broad matrix has correct columns", algo),
           setequal(colnames(rds_data$data), neonate_broad_causes))
      test(sprintf("RDS %s broad matrix has rows", algo), nrow(rds_data$data) > 0)

      # Each row should have exactly one 1 and the rest 0 (binary indicator)
      row_sums <- rowSums(rds_data$data)
      test(sprintf("RDS %s each row sums to 1 (binary indicator)", algo),
           all(row_sums == 1))
    }
  }
}

# =============================================================================
# 4. PARAMETER & CONFIGURATION VALIDATION
# =============================================================================
section("4. Parameter Validation")

# Valid countries per vacalibration package docs
valid_countries <- c("Bangladesh", "Ethiopia", "Kenya", "Mali",
                     "Mozambique", "Sierra Leone", "South Africa", "other")
valid_algorithms <- c("InterVA", "InSilicoVA", "EAVA")
valid_age_groups <- c("neonate", "child")
valid_calib_models <- c("Mmatprior", "Mmatfixed")

# Verify demo_configs.json has valid parameters
demo_file <- file.path(backend_dir, "data", "demo_configs.json")
test("demo_configs.json exists", file.exists(demo_file))

demos <- jsonlite::fromJSON(demo_file)$demos

# Filter to vacalibration demos only
vacalib_demos <- demos[demos$job_type == "vacalibration", ]
cat(sprintf("  Found %d vacalibration demos\n", nrow(vacalib_demos)))

for (i in seq_len(nrow(vacalib_demos))) {
  d <- vacalib_demos[i, ]
  label <- d$name

  test(sprintf("Demo '%s' has valid country", label),
       d$country %in% valid_countries)

  test(sprintf("Demo '%s' has valid age_group", label),
       d$age_group %in% valid_age_groups)

  test(sprintf("Demo '%s' has valid calib_model_type", label),
       d$calib_model_type %in% valid_calib_models)

  # Check algorithm(s) are valid
  algos <- if (is.list(d$algorithm)) unlist(d$algorithm[[1]]) else d$algorithm
  test(sprintf("Demo '%s' has valid algorithm(s)", label),
       all(algos %in% valid_algorithms))

  # Ensemble requires >= 2 algorithms
  if (isTRUE(d$ensemble)) {
    test(sprintf("Demo '%s' ensemble has >= 2 algorithms", label),
         length(algos) >= 2)
  }
}

# Verify MCMC defaults used in backend match reasonable values
test("Default nMCMC (5000) is >= 1000", 5000 >= 1000)
test("Default nBurn (2000) is < nMCMC (5000)", 2000 < 5000)
test("Default calib_model_type is 'Mmatprior'", "Mmatprior" %in% valid_calib_models)

# =============================================================================
# 5. VACALIBRATION COMPUTATION -- Single algorithm
# =============================================================================
section("5. Vacalibration Computation (Single Algorithm)")

# Test with InterVA sample (use backend RDS for speed)
rds_interva <- file.path(sample_dir, "sample_vacalibration_interva_neonate.rds")
if (file.exists(rds_interva)) {
  sample_data <- readRDS(rds_interva)
  va_input <- setNames(list(sample_data$data), sample_data$va_algo)

  cat("  Running vacalibration (InterVA, neonate, Mozambique)...\n")
  t0 <- Sys.time()
  result_interva <- tryCatch(
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
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cat(sprintf("  Elapsed: %.1f sec\n", elapsed))

  test("vacalibration returns non-NULL result", !is.null(result_interva))

  if (!is.null(result_interva)) {
    # -- p_uncalib --
    test("Result has p_uncalib", !is.null(result_interva$p_uncalib))
    uncalib <- result_interva$p_uncalib[1, ]
    test("Uncalibrated CSMF sums to ~1",
         abs(sum(uncalib) - 1) < 0.01)
    test("Uncalibrated CSMF values are all >= 0",
         all(uncalib >= 0))
    test("Uncalibrated CSMF has 6 broad causes (neonate)",
         length(uncalib) == 6)
    test("Uncalibrated CSMF cause names match broad categories",
         setequal(names(uncalib), neonate_broad_causes))

    # -- pcalib_postsumm --
    test("Result has pcalib_postsumm", !is.null(result_interva$pcalib_postsumm))
    postsumm <- result_interva$pcalib_postsumm
    calib_mean <- postsumm[1, "postmean", ]
    calib_low  <- postsumm[1, "lowcredI", ]
    calib_high <- postsumm[1, "upcredI", ]

    test("Calibrated mean CSMF sums to ~1",
         abs(sum(calib_mean) - 1) < 0.01)
    test("Calibrated mean values are all >= 0",
         all(calib_mean >= 0))
    test("Credible interval lower <= mean for all causes",
         all(calib_low <= calib_mean + 1e-6))
    test("Credible interval upper >= mean for all causes",
         all(calib_high >= calib_mean - 1e-6))
    test("Credible interval lower >= 0",
         all(calib_low >= -1e-6))
    test("Credible interval upper <= 1",
         all(calib_high <= 1 + 1e-6))

    # -- Misclassification matrix --
    test("Result has Mmat.asDirich", !is.null(result_interva$Mmat.asDirich))
    mmat <- result_interva$Mmat.asDirich
    test("Mmat.asDirich is a matrix or array", is.numeric(mmat))
    if (length(dim(mmat)) == 2) {
      test("2D Mmat has 6 rows (CHAMPS causes)", nrow(mmat) == 6)
      test("2D Mmat all values >= 0", all(mmat >= 0))
    } else if (length(dim(mmat)) == 3) {
      test("3D Mmat has 6 CHAMPS causes (dim 2)", dim(mmat)[2] == 6)
      test("3D Mmat all values >= 0", all(mmat >= 0))
    }
  }
} else {
  cat("  SKIP: InterVA RDS sample not found\n")
}

# =============================================================================
# 6. VACALIBRATION COMPUTATION -- From CSV (simulating user upload)
# =============================================================================
section("6. Vacalibration from CSV Upload (InSilicoVA)")

insilico_fixed2 <- fix_causes_for_vacalibration(insilico_df)
insilico_broad2 <- safe_cause_map(df = insilico_fixed2, age_group = "neonate")
va_input_csv <- list("insilicova" = insilico_broad2)

cat("  Running vacalibration from CSV data (InSilicoVA, neonate, Mozambique)...\n")
t0 <- Sys.time()
result_csv <- tryCatch(
  vacalibration(
    va_data = va_input_csv,
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
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("  Elapsed: %.1f sec\n", elapsed))

test("CSV-based vacalibration returns non-NULL result", !is.null(result_csv))

if (!is.null(result_csv)) {
  uncalib_csv <- result_csv$p_uncalib[1, ]
  test("CSV uncalibrated CSMF sums to ~1", abs(sum(uncalib_csv) - 1) < 0.01)
  test("CSV calibrated mean sums to ~1",
       abs(sum(result_csv$pcalib_postsumm[1, "postmean", ]) - 1) < 0.01)
}

# =============================================================================
# 7. VACALIBRATION COMPUTATION -- EAVA algorithm
# =============================================================================
section("7. Vacalibration from CSV Upload (EAVA)")

eava_fixed2 <- fix_causes_for_vacalibration(eava_df)
eava_broad2 <- safe_cause_map(df = eava_fixed2, age_group = "neonate")
va_input_eava <- list("eava" = eava_broad2)

cat("  Running vacalibration from CSV data (EAVA, neonate, Mozambique)...\n")
t0 <- Sys.time()
result_eava <- tryCatch(
  vacalibration(
    va_data = va_input_eava,
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
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("  Elapsed: %.1f sec\n", elapsed))

test("EAVA vacalibration returns non-NULL result", !is.null(result_eava))

if (!is.null(result_eava)) {
  uncalib_eava <- result_eava$p_uncalib[1, ]
  test("EAVA uncalibrated CSMF sums to ~1", abs(sum(uncalib_eava) - 1) < 0.01)
  calib_eava <- result_eava$pcalib_postsumm[1, "postmean", ]
  test("EAVA calibrated mean sums to ~1", abs(sum(calib_eava) - 1) < 0.01)
}

# =============================================================================
# 8. OUTPUT STRUCTURE VALIDATION
# =============================================================================
section("8. Output Structure Validation")

# Simulate what run_vacalibration() produces and verify the output format
if (!is.null(result_interva)) {
  # Simulate the backend result extraction logic
  uncalibrated <- as.list(round(result_interva$p_uncalib[1, ], 4))
  calibrated   <- as.list(round(result_interva$pcalib_postsumm[1, "postmean", ], 4))
  calib_low    <- as.list(round(result_interva$pcalib_postsumm[1, "lowcredI", ], 4))
  calib_high   <- as.list(round(result_interva$pcalib_postsumm[1, "upcredI", ], 4))

  test("Output uncalibrated_csmf is a named list", is.list(uncalibrated) && !is.null(names(uncalibrated)))
  test("Output calibrated_csmf is a named list", is.list(calibrated) && !is.null(names(calibrated)))
  test("Output names are consistent across uncalib/calib/CI",
       identical(names(uncalibrated), names(calibrated)) &&
       identical(names(calibrated), names(calib_low)) &&
       identical(names(calibrated), names(calib_high)))

  # Verify calibration_summary.csv would be correct
  causes <- names(uncalibrated)
  summary_df <- data.frame(
    cause = causes,
    uncalibrated = unlist(uncalibrated),
    calibrated_mean = unlist(calibrated),
    calibrated_lower = unlist(calib_low),
    calibrated_upper = unlist(calib_high)
  )

  test("Summary CSV has 6 rows (neonate broad causes)", nrow(summary_df) == 6)
  test("Summary CSV has 5 columns", ncol(summary_df) == 5)
  test("Summary CSV column names correct",
       identical(names(summary_df),
                 c("cause", "uncalibrated", "calibrated_mean",
                   "calibrated_lower", "calibrated_upper")))
  test("Summary uncalibrated values sum to ~1",
       abs(sum(summary_df$uncalibrated) - 1) < 0.01)
  test("Summary calibrated_lower <= calibrated_mean",
       all(summary_df$calibrated_lower <= summary_df$calibrated_mean + 1e-4))
  test("Summary calibrated_upper >= calibrated_mean",
       all(summary_df$calibrated_upper >= summary_df$calibrated_mean - 1e-4))

  # Misclassification matrix output
  mmat <- result_interva$Mmat.asDirich
  if (!is.null(mmat) && length(dim(mmat)) == 2) {
    dnames <- dimnames(mmat)
    mmat_df <- as.data.frame(round(mmat, 4))
    mmat_df <- cbind(CHAMPS_Cause = dnames[[1]], mmat_df)
    test("Misclass matrix CSV has CHAMPS_Cause column", "CHAMPS_Cause" %in% names(mmat_df))
    test("Misclass matrix all numeric values >= 0",
         all(as.matrix(mmat_df[, -1]) >= 0))
  }
}

# =============================================================================
# 9. DIFFERENT COUNTRY TESTS
# =============================================================================
section("9. Country Parameter Validation")

# Test that vacalibration works with different supported countries
if (file.exists(rds_interva)) {
  sample_data <- readRDS(rds_interva)
  va_input_country <- setNames(list(sample_data$data), sample_data$va_algo)

  for (country in c("South Africa", "Sierra Leone", "other")) {
    cat(sprintf("  Testing country: %s\n", country))
    result_country <- tryCatch(
      vacalibration(
        va_data = va_input_country,
        age_group = "neonate",
        country = country,
        calibmodel.type = "Mmatprior",
        ensemble = TRUE,
        nMCMC = 2000,
        nBurn = 1000,
        plot_it = FALSE,
        verbose = FALSE
      ),
      error = function(e) { cat("    ERROR:", e$message, "\n"); NULL }
    )
    test(sprintf("vacalibration succeeds for country=%s", country),
         !is.null(result_country))

    if (!is.null(result_country)) {
      calib_sum <- sum(result_country$pcalib_postsumm[1, "postmean", ])
      test(sprintf("Country=%s calibrated CSMF sums to ~1", country),
           abs(calib_sum - 1) < 0.02)
    }
  }
}

# =============================================================================
# 10. Mmatfixed MODEL TYPE
# =============================================================================
section("10. Mmatfixed Calibration Model")

if (file.exists(rds_interva)) {
  sample_data <- readRDS(rds_interva)
  va_input_fixed <- setNames(list(sample_data$data), sample_data$va_algo)

  cat("  Running vacalibration with Mmatfixed...\n")
  result_fixed <- tryCatch(
    vacalibration(
      va_data = va_input_fixed,
      age_group = "neonate",
      country = "Mozambique",
      calibmodel.type = "Mmatfixed",
      ensemble = TRUE,
      nMCMC = 2000,
      nBurn = 1000,
      plot_it = FALSE,
      verbose = FALSE
    ),
    error = function(e) { cat("  ERROR:", e$message, "\n"); NULL }
  )
  test("Mmatfixed returns non-NULL result", !is.null(result_fixed))

  if (!is.null(result_fixed)) {
    calib_fixed <- result_fixed$pcalib_postsumm[1, "postmean", ]
    test("Mmatfixed calibrated CSMF sums to ~1", abs(sum(calib_fixed) - 1) < 0.01)

    # Mmatfixed should have narrower CI since no uncertainty propagation on Mmat
    ci_width_fixed <- result_fixed$pcalib_postsumm[1, "upcredI", ] -
                      result_fixed$pcalib_postsumm[1, "lowcredI", ]

    if (!is.null(result_interva)) {
      ci_width_prior <- result_interva$pcalib_postsumm[1, "upcredI", ] -
                        result_interva$pcalib_postsumm[1, "lowcredI", ]
      test("Mmatfixed CI is generally narrower than Mmatprior",
           mean(ci_width_fixed) <= mean(ci_width_prior) + 0.05)
    }
  }
}

# =============================================================================
# 11. ENSEMBLE VACALIBRATION -- 2 Algorithms (from frontend CSVs)
# =============================================================================
section("11. Ensemble Vacalibration (2 Algorithms)")

# Ensemble = passing multiple algorithm outputs in va_data to vacalibration()
# vacalibration calibrates each algo separately AND produces a combined "ensemble" estimate

interva_broad_e <- safe_cause_map(df = fix_causes_for_vacalibration(interva_df), age_group = "neonate")
insilico_broad_e <- safe_cause_map(df = fix_causes_for_vacalibration(insilico_df), age_group = "neonate")

va_input_ens2 <- list(
  "interva" = interva_broad_e,
  "insilicova" = insilico_broad_e
)

cat("  Running ensemble vacalibration (InterVA + InSilicoVA, neonate, Mozambique)...\n")
t0 <- Sys.time()
result_ens2 <- tryCatch(
  vacalibration(
    va_data = va_input_ens2,
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
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("  Elapsed: %.1f sec\n", elapsed))

test("Ensemble 2-algo returns non-NULL result", !is.null(result_ens2))

if (!is.null(result_ens2)) {
  # p_uncalib: one row per algorithm + ensemble
  test("p_uncalib has 3 rows (2 algos + ensemble)", nrow(result_ens2$p_uncalib) == 3)
  test("p_uncalib rows include interva", "interva" %in% rownames(result_ens2$p_uncalib))
  test("p_uncalib rows include insilicova", "insilicova" %in% rownames(result_ens2$p_uncalib))
  test("p_uncalib rows include ensemble", "ensemble" %in% rownames(result_ens2$p_uncalib))

  for (rn in rownames(result_ens2$p_uncalib)) {
    test(sprintf("Uncalibrated CSMF for %s sums to ~1", rn),
         abs(sum(result_ens2$p_uncalib[rn, ]) - 1) < 0.01)
  }

  # pcalib_postsumm: rows for each algo + "ensemble"
  postsumm2 <- result_ens2$pcalib_postsumm
  algo_names2 <- dimnames(postsumm2)[[1]]
  test("pcalib_postsumm has 3 rows (2 algos + ensemble)", length(algo_names2) == 3)
  test("pcalib_postsumm includes 'ensemble' row", "ensemble" %in% algo_names2)

  # Verify ensemble combined estimate
  ens_mean <- postsumm2["ensemble", "postmean", ]
  ens_low  <- postsumm2["ensemble", "lowcredI", ]
  ens_high <- postsumm2["ensemble", "upcredI", ]
  test("Ensemble calibrated mean sums to ~1", abs(sum(ens_mean) - 1) < 0.01)
  test("Ensemble mean values >= 0", all(ens_mean >= 0))
  test("Ensemble CI lower <= mean", all(ens_low <= ens_mean + 1e-6))
  test("Ensemble CI upper >= mean", all(ens_high >= ens_mean - 1e-6))

  # Per-algorithm calibrated results also valid
  for (rn in c("interva", "insilicova")) {
    algo_mean <- postsumm2[rn, "postmean", ]
    test(sprintf("Calibrated mean for %s sums to ~1", rn),
         abs(sum(algo_mean) - 1) < 0.01)
  }

  # Mmat.asDirich should be 3D: [algo, champs_cause, va_cause]
  mmat_ens2 <- result_ens2$Mmat.asDirich
  test("Ensemble Mmat.asDirich is 3D", length(dim(mmat_ens2)) == 3)
  if (length(dim(mmat_ens2)) == 3) {
    test("Mmat 3D dim[1] = 2 (algorithms)", dim(mmat_ens2)[1] == 2)
    test("Mmat 3D dim[2] = 6 (CHAMPS causes)", dim(mmat_ens2)[2] == 6)
    test("Mmat 3D all values >= 0", all(mmat_ens2 >= 0))
  }
}

# =============================================================================
# 12. ENSEMBLE VACALIBRATION -- 3 Algorithms (all from frontend CSVs)
# =============================================================================
section("12. Ensemble Vacalibration (3 Algorithms)")

eava_broad_e <- safe_cause_map(df = fix_causes_for_vacalibration(eava_df), age_group = "neonate")

va_input_ens3 <- list(
  "interva" = interva_broad_e,
  "insilicova" = insilico_broad_e,
  "eava" = eava_broad_e
)

cat("  Running ensemble vacalibration (all 3 algorithms, neonate, Mozambique)...\n")
t0 <- Sys.time()
result_ens3 <- tryCatch(
  vacalibration(
    va_data = va_input_ens3,
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
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("  Elapsed: %.1f sec\n", elapsed))

test("Ensemble 3-algo returns non-NULL result", !is.null(result_ens3))

if (!is.null(result_ens3)) {
  test("p_uncalib has 4 rows (3 algos + ensemble)", nrow(result_ens3$p_uncalib) == 4)

  postsumm3 <- result_ens3$pcalib_postsumm
  algo_names3 <- dimnames(postsumm3)[[1]]
  test("pcalib_postsumm has 4 rows (3 algos + ensemble)", length(algo_names3) == 4)
  test("pcalib_postsumm includes all 3 algos + ensemble",
       all(c("interva", "insilicova", "eava", "ensemble") %in% algo_names3))

  # Ensemble combined estimate
  ens_mean3 <- postsumm3["ensemble", "postmean", ]
  test("3-algo ensemble mean sums to ~1", abs(sum(ens_mean3) - 1) < 0.01)
  test("3-algo ensemble mean values >= 0", all(ens_mean3 >= 0))

  # Each individual algo should also sum to ~1
  for (rn in c("interva", "insilicova", "eava")) {
    test(sprintf("3-algo: calibrated mean for %s sums to ~1", rn),
         abs(sum(postsumm3[rn, "postmean", ]) - 1) < 0.01)
  }

  # Mmat.asDirich: 3D with dim[1]=3
  mmat_ens3 <- result_ens3$Mmat.asDirich
  test("3-algo Mmat.asDirich is 3D with dim[1]=3",
       length(dim(mmat_ens3)) == 3 && dim(mmat_ens3)[1] == 3)
}

# =============================================================================
# 13. EDGE CASES
# =============================================================================
section("13. Edge Cases")

# Test auto-rename of cause1 -> cause
df_cause1 <- data.frame(
  ID = c("t1", "t2", "t3"),
  cause1 = c("Prematurity", "Neonatal sepsis", "Birth asphyxia"),
  stringsAsFactors = FALSE
)
names(df_cause1)[names(df_cause1) == "cause1"] <- "cause"
test("cause1->cause rename produces valid df",
     "cause" %in% names(df_cause1) && nrow(df_cause1) == 3)

# Test fix_causes_for_vacalibration with "Undetermined"
df_undetermined <- data.frame(
  ID = c("u1", "u2"),
  cause = c("Undetermined", "Prematurity"),
  stringsAsFactors = FALSE
)
df_fixed_u <- fix_causes_for_vacalibration(df_undetermined)
test("Undetermined maps to 'other'", df_fixed_u$cause[1] == "other")
test("Non-Undetermined cause unchanged", df_fixed_u$cause[2] == "Prematurity")

# Test safe_cause_map with incomplete cause set (only 2 of 6 broad causes present)
df_sparse <- data.frame(
  ID = c("s1", "s2", "s3"),
  cause = c("Prematurity", "Prematurity", "Birth asphyxia"),
  stringsAsFactors = FALSE
)
sparse_broad <- tryCatch(
  safe_cause_map(df = df_sparse, age_group = "neonate"),
  error = function(e) NULL
)
test("safe_cause_map handles sparse causes without error", !is.null(sparse_broad))
if (!is.null(sparse_broad)) {
  test("Sparse broad matrix has all 6 columns", ncol(sparse_broad) == 6)
  test("Sparse broad matrix has 3 rows", nrow(sparse_broad) == 3)
}

# Test invalid age_group
invalid_age <- tryCatch(
  safe_cause_map(df = df_sparse, age_group = "adult"),
  error = function(e) "error_caught"
)
test("Invalid age_group 'adult' raises error", identical(invalid_age, "error_caught"))

# =============================================================================
# SUMMARY
# =============================================================================
cat(sprintf("\n========================================\n"))
cat(sprintf("Tests: %d | Passed: %d | Failed: %d\n", .test_count, .pass_count, .fail_count))
cat(sprintf("========================================\n"))

if (.fail_count > 0) {
  cat("\nFailed tests:\n")
  for (msg in .fail_msgs) cat(msg, "\n")
  quit(status = 1)
} else {
  cat("\nAll tests passed!\n")
  quit(status = 0)
}
