#!/usr/bin/env Rscript
# Debug script to check if Mmat_tomodel is present in vacalibration results

library(openVA)
library(vacalibration)

cat("Loading sample data...\n")
neonate_data <- readRDS("backend/data/sample_data/sample_neonate_openva.rds")

cat("Running InterVA...\n")
result_interva <- codeVA(
  data = neonate_data,
  data.type = "WHO2016",
  model = "InterVA",
  version = "5.0",
  HIV = "l",
  Malaria = "l",
  write = FALSE
)

cat("Extracting causes and probabilities...\n")
cod <- getTopCOD(result_interva)
probs <- getIndivProb(result_interva)

# Prepare for vacalibration
probs[probs == 0] <- .0000001
probs <- t(apply(probs, 1, function(x) (x/sum(x))))

# Map to broad causes
cat("Mapping to broad causes...\n")
df_causes <- data.frame(ID = cod$ID, cause = cod$cause1, stringsAsFactors = FALSE)

# Add dummy records to ensure all categories present
dummy_causes <- c(
  "congenital malformation",
  "neonatal pneumonia",
  "neonatal sepsis",
  "birth asphyxia",
  "other",
  "prematurity"
)
dummy_df <- data.frame(
  ID = paste0("__dummy_", seq_along(dummy_causes), "__"),
  cause = dummy_causes,
  stringsAsFactors = FALSE
)
df_with_dummies <- rbind(df_causes, dummy_df)

# Call cause_map
va_broad <- vacalibration::cause_map(df = df_with_dummies, age_group = "neonate")

# Remove dummies
va_broad <- va_broad[!rownames(va_broad) %in% dummy_df$ID, , drop = FALSE]

cat("Running vacalibration...\n")
va_list <- list("interva" = va_broad)

calib_result <- vacalibration::vacalibration(
  va_data = va_list,
  age_group = "neonate",
  country = "Ethiopia",
  missmat_type = "prior",
  ensemble = FALSE
)

cat("\n=== Checking vacalibration result structure ===\n")
cat("Names in result:\n")
print(names(calib_result))

cat("\nMmat_tomodel present?", !is.null(calib_result$Mmat_tomodel), "\n")

if (!is.null(calib_result$Mmat_tomodel)) {
  cat("Mmat_tomodel dimensions:", dim(calib_result$Mmat_tomodel), "\n")
  cat("Mmat_tomodel dimnames:\n")
  print(dimnames(calib_result$Mmat_tomodel))
} else {
  cat("ERROR: Mmat_tomodel is NULL!\n")
  cat("\nAvailable matrix-related fields:\n")
  matrix_fields <- names(calib_result)[grepl("mat|matrix|Mmat", names(calib_result), ignore.case = TRUE)]
  print(matrix_fields)

  if (length(matrix_fields) > 0) {
    for (field in matrix_fields) {
      cat("\n", field, ":\n", sep = "")
      obj <- calib_result[[field]]
      if (is.null(obj)) {
        cat("  NULL\n")
      } else {
        cat("  Class:", class(obj), "\n")
        if (is.array(obj) || is.matrix(obj)) {
          cat("  Dimensions:", dim(obj), "\n")
        }
      }
    }
  }
}
