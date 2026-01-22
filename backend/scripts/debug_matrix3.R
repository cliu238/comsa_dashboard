#!/usr/bin/env Rscript
# Debug script to inspect Mmat.asDirich structure

library(vacalibration)

cat("Loading sample vacalibration data...\n")
calib_sample <- readRDS("backend/data/sample_data/sample_vacalibration_broad.rds")

va_list <- setNames(list(calib_sample$data), calib_sample$va_algo)

cat("Running vacalibration...\n")
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

cat("\n=== Inspecting Mmat.asDirich ===\n")
if (!is.null(result$Mmat.asDirich)) {
  mmat <- result$Mmat.asDirich
  cat("Class:", class(mmat), "\n")
  cat("Dimensions:", dim(mmat), "\n")
  cat("Dimnames:\n")
  print(dimnames(mmat))
  cat("\nFirst few values:\n")
  print(mmat[1:min(3, nrow(mmat)), 1:min(3, ncol(mmat))])

  cat("\nChecking if it's a 2D or 3D array:\n")
  cat("Number of dimensions:", length(dim(mmat)), "\n")

  if (length(dim(mmat)) == 2) {
    cat("\n2D matrix detected\n")
    cat("Rows (CHAMPS causes):", dimnames(mmat)[[1]], "\n")
    cat("Cols (VA causes):", dimnames(mmat)[[2]], "\n")
  } else if (length(dim(mmat)) == 3) {
    cat("\n3D array detected\n")
    cat("Dim 1 (algorithms):", dimnames(mmat)[[1]], "\n")
    cat("Dim 2 (CHAMPS causes):", dimnames(mmat)[[2]], "\n")
    cat("Dim 3 (VA causes):", dimnames(mmat)[[3]], "\n")
  }
} else {
  cat("ERROR: Mmat.asDirich is NULL\n")
}
