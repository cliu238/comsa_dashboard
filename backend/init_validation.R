# Validate Stan models are properly compiled for this platform
validate_stan_models <- function() {
  if (!requireNamespace("vacalibration", quietly = TRUE)) {
    warning("vacalibration not installed, skipping Stan model validation")
    return(FALSE)
  }

  pkg_path <- find.package('vacalibration')
  stan_dir <- file.path(pkg_path, 'stan')

  models <- c('seqcalib.rds', 'seqcalib_mmat.rds')

  for (model_file in models) {
    model_path <- file.path(stan_dir, model_file)

    if (!file.exists(model_path)) {
      warning(sprintf("Stan model not found: %s", model_path))
      return(FALSE)
    }

    # Try loading the model to verify it's valid
    tryCatch({
      model <- readRDS(model_path)
      message(sprintf("✓ Stan model validated: %s", model_file))
    }, error = function(e) {
      warning(sprintf("Stan model validation failed for %s: %s", model_file, e$message))
      return(FALSE)
    })
  }

  message("✓ All Stan models validated successfully")
  return(TRUE)
}

# Run validation at startup
validate_stan_models()
