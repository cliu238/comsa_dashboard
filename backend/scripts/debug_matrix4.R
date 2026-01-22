#!/usr/bin/env Rscript
# Debug script to test the full extraction process

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

cat("\n=== Testing matrix extraction (mimicking processor.R) ===\n")

# Extract using the same logic as processor.R
mmat <- if (!is.null(result$Mmat.asDirich)) {
  result$Mmat.asDirich
} else if (!is.null(result$Mmat_tomodel)) {
  result$Mmat_tomodel
} else {
  NULL
}

if (!is.null(mmat)) {
  dnames <- dimnames(mmat)
  cat("mmat dimensions:", dim(mmat), "\n")
  cat("mmat is 3D?", length(dim(mmat)) == 3, "\n\n")

  if (length(dim(mmat)) == 3) {
    algorithms <- dnames[[1]]
    champs_causes <- dnames[[2]]
    va_causes <- dnames[[3]]

    cat("Algorithms:", algorithms, "\n")
    cat("CHAMPS causes:", champs_causes, "\n")
    cat("VA causes:", va_causes, "\n\n")

    misclass_matrix <- list()
    for (i in seq_along(algorithms)) {
      algo_name <- algorithms[i]
      cat("Extracting for algorithm:", algo_name, "\n")

      algo_matrix <- mmat[i, , , drop = TRUE]
      cat("algo_matrix class:", class(algo_matrix), "\n")
      cat("algo_matrix dimensions:", dim(algo_matrix), "\n")
      cat("algo_matrix preview:\n")
      print(algo_matrix[1:min(3, nrow(algo_matrix)), 1:min(3, ncol(algo_matrix))])

      misclass_matrix[[algo_name]] <- list(
        matrix = lapply(seq_len(nrow(algo_matrix)), function(row) {
          as.list(round(algo_matrix[row, ], 4))
        }),
        champs_causes = champs_causes,
        va_causes = va_causes
      )

      cat("\nConverted matrix to list format\n")
      cat("Number of rows:", length(misclass_matrix[[algo_name]]$matrix), "\n")
      cat("First row:", unlist(misclass_matrix[[algo_name]]$matrix[[1]]), "\n\n")
    }

    # Now try to create CSV like processor does
    cat("=== Creating CSV ===\n")
    algo_name <- algorithms[1]
    algo_data <- misclass_matrix[[algo_name]]

    cat("algo_data$matrix length:", length(algo_data$matrix), "\n")
    cat("Attempting rbind...\n")

    mmat_df <- as.data.frame(do.call(rbind, algo_data$matrix))
    cat("Data frame created. Dimensions:", dim(mmat_df), "\n")

    colnames(mmat_df) <- algo_data$va_causes
    mmat_df <- cbind(CHAMPS_Cause = algo_data$champs_causes, mmat_df)

    cat("Final data frame:\n")
    print(head(mmat_df))

    # Try writing
    write.csv(mmat_df, "/tmp/test_matrix.csv", row.names = FALSE)
    cat("\n✓ CSV written successfully to /tmp/test_matrix.csv\n")
  }
} else {
  cat("ERROR: mmat is NULL\n")
}
