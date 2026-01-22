#!/usr/bin/env Rscript
# Generate frontend CSV samples from backend RDS files
# Ensures exact consistency between demo mode (.rds) and user upload mode (.csv)

library(openVA)

# Paths
sample_data_dir <- file.path("backend", "data", "sample_data")
frontend_public_dir <- file.path("frontend", "public")

cat("=== Generating Sample CSV Files ===\n\n")

# ============================================
# 1. Generate openVA CSV samples (WHO2016 format)
# ============================================

cat("1. Generating openVA CSV samples...\n")

# Neonate sample
neonate_rds_path <- file.path(sample_data_dir, "sample_neonate_openva.rds")
if (file.exists(neonate_rds_path)) {
  neonate_data <- readRDS(neonate_rds_path)

  # Export first 50 rows to CSV
  neonate_sample <- head(neonate_data, 50)
  neonate_csv_path <- file.path(frontend_public_dir, "sample_openva_neonate.csv")
  write.csv(neonate_sample, neonate_csv_path, row.names = FALSE)

  cat(sprintf("   ✓ Created %s (%d rows, %d cols)\n",
              neonate_csv_path, nrow(neonate_sample), ncol(neonate_sample)))
} else {
  cat(sprintf("   ✗ ERROR: %s not found\n", neonate_rds_path))
}

# Child sample
child_rds_path <- file.path(sample_data_dir, "sample_child_openva.rds")
if (file.exists(child_rds_path)) {
  child_data <- readRDS(child_rds_path)

  # Export first 50 rows to CSV
  child_sample <- head(child_data, 50)
  child_csv_path <- file.path(frontend_public_dir, "sample_openva_child.csv")
  write.csv(child_sample, child_csv_path, row.names = FALSE)

  cat(sprintf("   ✓ Created %s (%d rows, %d cols)\n",
              child_csv_path, nrow(child_sample), ncol(child_sample)))
} else {
  cat(sprintf("   ✗ ERROR: %s not found\n", child_rds_path))
}

cat("\n")

# ============================================
# 2. Generate vacalibration CSV samples
# ============================================

cat("2. Generating vacalibration CSV samples (ID + cause format)...\n")
cat("   This requires running openVA algorithms first...\n\n")

# Neonate vacalibration sample
if (file.exists(neonate_rds_path)) {
  cat("   Running InSilicoVA on neonate sample...\n")
  neonate_data <- readRDS(neonate_rds_path)

  # Run InSilicoVA
  result_neonate <- codeVA(
    data = neonate_data,
    data.type = "WHO2016",
    model = "InSilicoVA",
    Nsim = 4000,  # Reduced for faster generation
    auto.length = FALSE,
    write = FALSE
  )

  # Extract causes
  cod_neonate <- getTopCOD(result_neonate)
  vacal_neonate <- data.frame(
    ID = cod_neonate$ID,
    cause = cod_neonate$cause1,
    stringsAsFactors = FALSE
  )

  # Save to CSV
  vacal_neonate_csv_path <- file.path(frontend_public_dir, "sample_vacalibration_neonate.csv")
  write.csv(vacal_neonate, vacal_neonate_csv_path, row.names = FALSE)

  cat(sprintf("   ✓ Created %s (%d rows)\n",
              vacal_neonate_csv_path, nrow(vacal_neonate)))
  cat(sprintf("     Causes: %s\n",
              paste(unique(vacal_neonate$cause), collapse = ", ")))
} else {
  cat(sprintf("   ✗ ERROR: %s not found\n", neonate_rds_path))
}

cat("\n")

# Child vacalibration sample
if (file.exists(child_rds_path)) {
  cat("   Running InSilicoVA on child sample (first 50 rows)...\n")
  child_data <- readRDS(child_rds_path)
  child_data_subset <- head(child_data, 50)  # Use first 50 rows for faster generation

  # Run InSilicoVA
  result_child <- codeVA(
    data = child_data_subset,
    data.type = "WHO2016",
    model = "InSilicoVA",
    Nsim = 4000,  # Reduced for faster generation
    auto.length = FALSE,
    write = FALSE
  )

  # Extract causes
  cod_child <- getTopCOD(result_child)
  vacal_child <- data.frame(
    ID = cod_child$ID,
    cause = cod_child$cause1,
    stringsAsFactors = FALSE
  )

  # Save to CSV
  vacal_child_csv_path <- file.path(frontend_public_dir, "sample_vacalibration_child.csv")
  write.csv(vacal_child, vacal_child_csv_path, row.names = FALSE)

  cat(sprintf("   ✓ Created %s (%d rows)\n",
              vacal_child_csv_path, nrow(vacal_child)))
  cat(sprintf("     Causes: %s\n",
              paste(unique(vacal_child$cause), collapse = ", ")))
} else {
  cat(sprintf("   ✗ ERROR: %s not found\n", child_rds_path))
}

cat("\n=== Sample CSV Generation Complete ===\n\n")

cat("Generated files:\n")
cat("  - frontend/public/sample_openva_neonate.csv (WHO2016 format for neonate)\n")
cat("  - frontend/public/sample_openva_child.csv (WHO2016 format for child)\n")
cat("  - frontend/public/sample_vacalibration_neonate.csv (ID + cause for neonate)\n")
cat("  - frontend/public/sample_vacalibration_child.csv (ID + cause for child)\n\n")

cat("Next steps:\n")
cat("  1. Archive old sample_vacalibration.csv (mixed age groups)\n")
cat("  2. Test samples by uploading them to the platform\n")
cat("  3. Run validation script: Rscript backend/scripts/validate_samples.R\n")
