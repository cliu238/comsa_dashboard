# vacalibration Algorithm Implementation
# Calibrates VA results using Bayesian methods

# Normalize algorithm name to vacalibration format (lowercase)
normalize_algo_name <- function(algo) {
  a <- tolower(algo)
  switch(a, "interva" = "interva", "insilicova" = "insilicova", "eava" = "eava", "insilicova")
}

# Run vacalibration
run_vacalibration <- function(job) {
  add_log(job$id, "Starting vacalibration")

  # Parse algorithm(s) into normalized lowercase names
  algorithms <- if (is.character(job$algorithm)) job$algorithm else as.character(job$algorithm)
  algo_names <- unique(vapply(algorithms, normalize_algo_name, character(1), USE.NAMES = FALSE))

  # Ensemble: auto-detect from algorithm count if not specified
  ensemble_val <- if (!is.null(job$ensemble)) as.logical(job$ensemble) else (length(algo_names) >= 2)
  if (ensemble_val && length(algo_names) < 2) {
    add_log(job$id, "Ensemble disabled: requires >= 2 algorithms")
    ensemble_val <- FALSE
  }

  calib_model_type <- if (!is.null(job$calib_model_type)) job$calib_model_type else "Mmatprior"
  n_mcmc <- if (!is.null(job$n_mcmc)) as.integer(job$n_mcmc) else 5000L
  n_burn <- if (!is.null(job$n_burn)) as.integer(job$n_burn) else 2000L
  n_thin <- if (!is.null(job$n_thin)) as.integer(job$n_thin) else 1L

  # Build va_input: named list with one entry per algorithm
  va_input <- list()

  if (isTRUE(job$use_sample_data)) {
    # Sample data: load for EACH algorithm
    for (algo in algo_names) {
      add_log(job$id, paste("Loading sample data for", toupper(algo)))
      calib_sample <- load_vacalibration_sample(algo, job$age_group, job$id)
      va_input[[algo]] <- calib_sample$data
    }
  } else {
    # User upload: single CSV file -> single algorithm
    add_log(job$id, paste("Loading data from:", job$input_file))
    input_data <- read.csv(job$input_file, stringsAsFactors = FALSE)

    # Auto-rename cause1 to cause (openVA output uses cause1)
    if ("cause1" %in% names(input_data) && !"cause" %in% names(input_data)) {
      names(input_data)[names(input_data) == "cause1"] <- "cause"
      add_log(job$id, "Auto-renamed 'cause1' to 'cause' (openVA format detected)")
    }

    if (!all(c("ID", "cause") %in% names(input_data))) {
      stop("Input file must have 'ID' and 'cause' columns (or 'ID' and 'cause1')")
    }

    input_data$ID <- as.character(input_data$ID)
    add_log(job$id, paste("Loaded", nrow(input_data), "records with",
                          length(unique(input_data$cause)), "unique causes"))
    add_log(job$id, paste("Causes:", paste(unique(input_data$cause), collapse = ", ")))

    add_log(job$id, "Mapping specific causes to broad categories...")
    input_data <- fix_causes_for_vacalibration(input_data)
    va_broad <- safe_cause_map(df = input_data, age_group = job$age_group)
    add_log(job$id, paste("Mapped to broad causes:", paste(colnames(va_broad), collapse = ", ")))

    # Single file upload can only calibrate one algorithm
    va_input[[algo_names[1]]] <- va_broad
    if (length(algo_names) > 1) {
      add_log(job$id, "Warning: Single file upload only supports one algorithm, ensemble disabled")
      algo_names <- algo_names[1]
      ensemble_val <- FALSE
    }
  }

  add_log(job$id, paste("Algorithms:", paste(names(va_input), collapse = ", ")))
  add_log(job$id, paste("calibmodel.type =", calib_model_type, ", ensemble =", ensemble_val))
  add_log(job$id, paste("MCMC: nMCMC =", n_mcmc, ", nBurn =", n_burn, ", nThin =", n_thin))

  # Run vacalibration with plot capture
  output_dir <- file.path("data", "outputs", job$id)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)
  plot_file <- file.path(output_dir, "calibration_plot.pdf")

  pdf(plot_file, width = 20, height = 12)
  result <- tryCatch({
    run_with_capture(job$id, {
      vacalibration(
        va_data = va_input,
        age_group = job$age_group,
        country = job$country,
        calibmodel.type = calib_model_type,
        ensemble = ensemble_val,
        nMCMC = n_mcmc,
        nBurn = n_burn,
        nThin = n_thin,
        plot_it = TRUE,
        verbose = TRUE
      )
    })
  }, error = function(e) {
    dev.off()
    stop(e)
  })
  dev.off()

  add_log(job$id, "Calibration complete")

  # Extract results
  # For ensemble: use "ensemble" row as primary; for single algo: use that algo's row
  result_labels <- dimnames(result$pcalib_postsumm)[[1]]
  primary <- if ("ensemble" %in% result_labels) "ensemble" else result_labels[1]

  uncalibrated   <- as.list(round(result$p_uncalib[primary, ], 4))
  calibrated     <- as.list(round(result$pcalib_postsumm[primary, "postmean", ], 4))
  calibrated_low <- as.list(round(result$pcalib_postsumm[primary, "lowcredI", ], 4))
  calibrated_high <- as.list(round(result$pcalib_postsumm[primary, "upcredI", ], 4))

  # Per-algorithm breakdown (for ensemble mode)
  per_algorithm <- NULL
  if (ensemble_val && length(result_labels) > 1) {
    per_algorithm <- list()
    for (label in result_labels) {
      per_algorithm[[label]] <- list(
        uncalibrated_csmf   = as.list(round(result$p_uncalib[label, ], 4)),
        calibrated_csmf     = as.list(round(result$pcalib_postsumm[label, "postmean", ], 4)),
        calibrated_ci_lower = as.list(round(result$pcalib_postsumm[label, "lowcredI", ], 4)),
        calibrated_ci_upper = as.list(round(result$pcalib_postsumm[label, "upcredI", ], 4))
      )
    }
  }

  # Extract misclassification matrix
  mmat <- if (!is.null(result$Mmat.asDirich)) result$Mmat.asDirich
          else if (!is.null(result$Mmat_tomodel)) result$Mmat_tomodel
          else NULL

  misclass_matrix <- NULL
  if (!is.null(mmat)) {
    dnames <- dimnames(mmat)

    if (length(dim(mmat)) == 3) {
      # 3D: [algorithm, CHAMPS, VA]
      misclass_matrix <- list()
      for (i in seq_len(dim(mmat)[1])) {
        algo_name <- dnames[[1]][i]
        algo_matrix <- mmat[i, , , drop = TRUE]
        misclass_matrix[[algo_name]] <- list(
          matrix = lapply(seq_len(nrow(algo_matrix)), function(row) round(algo_matrix[row, ], 4)),
          champs_causes = dnames[[2]],
          va_causes = dnames[[3]]
        )
      }
    } else if (length(dim(mmat)) == 2) {
      # 2D: [CHAMPS, VA] for single algorithm
      algo_name <- if (length(algo_names) == 1) algo_names[1] else "combined"
      misclass_matrix <- list()
      misclass_matrix[[algo_name]] <- list(
        matrix = lapply(seq_len(nrow(mmat)), function(row) round(mmat[row, ], 4)),
        champs_causes = dnames[[1]],
        va_causes = dnames[[2]]
      )
    }
  }

  # Save outputs (output_dir already created above for plot capture)

  # Save calibration plot
  if (file.exists(plot_file) && file.info(plot_file)$size > 0) {
    add_job_file(job$id, "output", "calibration_plot.pdf", plot_file, file.info(plot_file)$size)
    add_log(job$id, "Calibration plot saved")
  }

  # Save calibration summary (primary result: ensemble or single algo)
  summary_df <- data.frame(
    cause = names(uncalibrated),
    uncalibrated = unlist(uncalibrated),
    calibrated_mean = unlist(calibrated),
    calibrated_lower = unlist(calibrated_low),
    calibrated_upper = unlist(calibrated_high)
  )
  summary_file <- file.path(output_dir, "calibration_summary.csv")
  write.csv(summary_df, summary_file, row.names = FALSE)
  add_job_file(job$id, "output", "calibration_summary.csv", summary_file, file.info(summary_file)$size)

  # Save misclassification matrices
  if (!is.null(misclass_matrix)) {
    for (algo_name in names(misclass_matrix)) {
      algo_data <- misclass_matrix[[algo_name]]
      mmat_df <- as.data.frame(do.call(rbind, algo_data$matrix))
      colnames(mmat_df) <- algo_data$va_causes
      mmat_df <- cbind(CHAMPS_Cause = algo_data$champs_causes, mmat_df)

      filename <- if (length(names(misclass_matrix)) > 1) {
        paste0("misclass_matrix_", algo_name, ".csv")
      } else {
        "misclass_matrix.csv"
      }

      mmat_file <- file.path(output_dir, filename)
      write.csv(mmat_df, mmat_file, row.names = FALSE)
      add_job_file(job$id, "output", filename, mmat_file, file.info(mmat_file)$size)
    }
  }

  add_log(job$id, "Results saved")

  # Build result object
  result_obj <- list(
    algorithm = algo_names,
    age_group = job$age_group,
    country = job$country,
    ensemble = ensemble_val,
    uncalibrated_csmf = uncalibrated,
    calibrated_csmf = calibrated,
    calibrated_ci_lower = calibrated_low,
    calibrated_ci_upper = calibrated_high,
    files = list(summary = "calibration_summary.csv", plot = "calibration_plot.pdf")
  )

  if (!is.null(per_algorithm)) {
    result_obj$per_algorithm <- per_algorithm
  }

  if (!is.null(misclass_matrix)) {
    result_obj$misclassification_matrix <- misclass_matrix
    for (algo_name in names(misclass_matrix)) {
      filename <- if (length(names(misclass_matrix)) > 1) {
        paste0("misclass_matrix_", algo_name, ".csv")
      } else {
        "misclass_matrix.csv"
      }
      result_obj$files[[paste0("misclass_", algo_name)]] <- filename
    }
  }

  return(result_obj)
}
