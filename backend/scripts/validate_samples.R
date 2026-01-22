#!/usr/bin/env Rscript
# Validate that frontend CSV samples match backend RDS samples
# Ensures consistency between demo mode (.rds) and user upload mode (.csv)

# Paths
sample_data_dir <- file.path("backend", "data", "sample_data")
frontend_public_dir <- file.path("frontend", "public")

cat("=== Validating Sample Data Consistency ===\n\n")

validation_passed <- TRUE

# ============================================
# Helper function to compare datasets
# ============================================
compare_datasets <- function(rds_path, csv_path, expected_rows = NULL) {
  cat(sprintf("Comparing:\n  RDS: %s\n  CSV: %s\n", rds_path, csv_path))

  if (!file.exists(rds_path)) {
    cat(sprintf("  ✗ ERROR: RDS file not found\n\n"))
    return(FALSE)
  }

  if (!file.exists(csv_path)) {
    cat(sprintf("  ✗ ERROR: CSV file not found\n\n"))
    return(FALSE)
  }

  # Load data
  rds_data <- readRDS(rds_path)
  csv_data <- read.csv(csv_path, stringsAsFactors = FALSE)

  # If expected_rows specified, compare only those rows
  if (!is.null(expected_rows)) {
    rds_data <- head(rds_data, expected_rows)
  }

  issues <- c()

  # Check dimensions
  if (nrow(rds_data) != nrow(csv_data)) {
    issues <- c(issues, sprintf("Row count mismatch: RDS=%d, CSV=%d",
                                nrow(rds_data), nrow(csv_data)))
  }

  if (ncol(rds_data) != ncol(csv_data)) {
    issues <- c(issues, sprintf("Column count mismatch: RDS=%d, CSV=%d",
                                ncol(rds_data), ncol(csv_data)))
  }

  # Check column names
  if (!identical(names(rds_data), names(csv_data))) {
    missing_in_csv <- setdiff(names(rds_data), names(csv_data))
    missing_in_rds <- setdiff(names(csv_data), names(rds_data))

    if (length(missing_in_csv) > 0) {
      issues <- c(issues, sprintf("Columns in RDS but not CSV: %s",
                                  paste(head(missing_in_csv, 5), collapse = ", ")))
    }
    if (length(missing_in_rds) > 0) {
      issues <- c(issues, sprintf("Columns in CSV but not RDS: %s",
                                  paste(head(missing_in_rds, 5), collapse = ", ")))
    }
  }

  # Check data types for key columns
  common_cols <- intersect(names(rds_data), names(csv_data))
  if (length(common_cols) > 0) {
    sample_cols <- head(common_cols, 10)
    for (col in sample_cols) {
      rds_class <- class(rds_data[[col]])[1]
      csv_class <- class(csv_data[[col]])[1]

      if (rds_class != csv_class) {
        issues <- c(issues, sprintf("Column '%s' type mismatch: RDS=%s, CSV=%s",
                                    col, rds_class, csv_class))
      }
    }
  }

  # Check for NA values in ID column
  if ("ID" %in% names(csv_data)) {
    if (any(is.na(csv_data$ID))) {
      issues <- c(issues, "CSV has NA values in ID column")
    }
  }

  # Report results
  if (length(issues) == 0) {
    cat("  ✓ PASS: Datasets match\n")
    cat(sprintf("    Rows: %d, Columns: %d\n", nrow(csv_data), ncol(csv_data)))
    cat("\n")
    return(TRUE)
  } else {
    cat("  ✗ FAIL: Issues found:\n")
    for (issue in issues) {
      cat(sprintf("    - %s\n", issue))
    }
    cat("\n")
    return(FALSE)
  }
}

# ============================================
# Validate vacalibration format
# ============================================
validate_vacalibration <- function(csv_path, expected_age_group) {
  cat(sprintf("Validating vacalibration format: %s\n", csv_path))

  if (!file.exists(csv_path)) {
    cat(sprintf("  ✗ ERROR: File not found\n\n"))
    return(FALSE)
  }

  data <- read.csv(csv_path, stringsAsFactors = FALSE)
  issues <- c()

  # Check required columns
  if (!all(c("ID", "cause") %in% names(data))) {
    issues <- c(issues, "Missing required columns (ID, cause)")
  }

  # Check for NA values
  if (any(is.na(data$ID))) {
    issues <- c(issues, "NA values in ID column")
  }
  if (any(is.na(data$cause))) {
    issues <- c(issues, "NA values in cause column")
  }

  # Check for mixed age groups (basic heuristic)
  causes <- unique(data$cause)
  neonate_indicators <- c("Neonatal", "Birth asphyxia", "Prematurity", "stillbirth")
  child_indicators <- c("Malaria", "Measles", "Road traffic", "Drowning", "Accid fall")

  has_neonate <- any(sapply(neonate_indicators, function(x) any(grepl(x, causes, ignore.case = TRUE))))
  has_child <- any(sapply(child_indicators, function(x) any(grepl(x, causes, ignore.case = TRUE))))

  if (expected_age_group == "neonate" && has_child) {
    issues <- c(issues, sprintf("Neonate sample contains child-specific causes: %s",
                                paste(causes[grepl("Road traffic|Drowning|Accid fall", causes)], collapse = ", ")))
  }

  # Report results
  if (length(issues) == 0) {
    cat("  ✓ PASS: Vacalibration format valid\n")
    cat(sprintf("    Rows: %d\n", nrow(data)))
    cat(sprintf("    Unique causes: %d\n", length(causes)))
    cat(sprintf("    Causes: %s\n", paste(head(causes, 5), collapse = ", ")))
    if (length(causes) > 5) cat(sprintf("            ... and %d more\n", length(causes) - 5))
    cat("\n")
    return(TRUE)
  } else {
    cat("  ✗ FAIL: Issues found:\n")
    for (issue in issues) {
      cat(sprintf("    - %s\n", issue))
    }
    cat("\n")
    return(FALSE)
  }
}

# ============================================
# Run validations
# ============================================

cat("1. Validating openVA CSV samples...\n\n")

# Neonate openVA
result1 <- compare_datasets(
  file.path(sample_data_dir, "sample_neonate_openva.rds"),
  file.path(frontend_public_dir, "sample_openva_neonate.csv"),
  expected_rows = 50
)
validation_passed <- validation_passed && result1

# Child openVA
result2 <- compare_datasets(
  file.path(sample_data_dir, "sample_child_openva.rds"),
  file.path(frontend_public_dir, "sample_openva_child.csv"),
  expected_rows = 50
)
validation_passed <- validation_passed && result2

cat("2. Validating vacalibration CSV samples...\n\n")

# Neonate vacalibration
result3 <- validate_vacalibration(
  file.path(frontend_public_dir, "sample_vacalibration_neonate.csv"),
  expected_age_group = "neonate"
)
validation_passed <- validation_passed && result3

# Child vacalibration
result4 <- validate_vacalibration(
  file.path(frontend_public_dir, "sample_vacalibration_child.csv"),
  expected_age_group = "child"
)
validation_passed <- validation_passed && result4

# ============================================
# Summary
# ============================================

cat("=== Validation Summary ===\n\n")

if (validation_passed) {
  cat("✓ ALL VALIDATIONS PASSED\n\n")
  cat("Sample CSV files are consistent with backend RDS files.\n")
  cat("Users can download and upload these samples with confidence.\n\n")
  cat("Next steps:\n")
  cat("  1. Test uploading samples to the platform\n")
  cat("  2. Verify demo mode and CSV upload produce identical results\n")
  cat("  3. Test pipeline jobs to verify misclassification matrix display\n")
  quit(status = 0)
} else {
  cat("✗ SOME VALIDATIONS FAILED\n\n")
  cat("Please review issues above and regenerate samples if needed.\n")
  cat("Run: Rscript backend/scripts/generate_sample_csvs.R\n")
  quit(status = 1)
}
