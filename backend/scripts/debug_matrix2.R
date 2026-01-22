#!/usr/bin/env Rscript
# Debug script - simpler test using sample_vacalibration_broad.rds directly

library(vacalibration)

cat("Loading sample vacalibration data...\n")
calib_sample <- readRDS("backend/data/sample_data/sample_vacalibration_broad.rds")

va_list <- setNames(list(calib_sample$data), calib_sample$va_algo)

cat("Running vacalibration...\n")
cat("  Algorithm:", calib_sample$va_algo, "\n")
cat("  Age group:", calib_sample$age_group, "\n")
cat("  Country: Ethiopia\n")
cat("  calibmodel.type: Mmatprior\n")
cat("  ensemble: FALSE\n\n")

result <- vacalibration(
  va_data = va_list,
  age_group = calib_sample$age_group,
  country = "Ethiopia",
  calibmodel.type = "Mmatprior",
  ensemble = FALSE,
  nMCMC = 5000,
  nBurn = 2000,
  plot_it = FALSE,
  verbose = FALSE
)

cat("\n=== Checking result structure ===\n")
cat("Names in result:\n")
print(names(result))

cat("\nMmat_tomodel present?", !is.null(result$Mmat_tomodel), "\n")

if (!is.null(result$Mmat_tomodel)) {
  cat("✓ SUCCESS: Mmat_tomodel found!\n")
  cat("  Dimensions:", dim(result$Mmat_tomodel), "\n")
  cat("  Dimnames:\n")
  print(dimnames(result$Mmat_tomodel))
} else {
  cat("✗ ERROR: Mmat_tomodel is NULL!\n")
  cat("\nAll field names:\n")
  print(names(result))
}
