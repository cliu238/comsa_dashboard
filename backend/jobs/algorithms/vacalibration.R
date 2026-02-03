# vacalibration Algorithm Implementation
# Calibrates VA results using Bayesian methods

# Run vacalibration
run_vacalibration <- function(job) {
  add_log(job$id, "Starting vacalibration")

  # Load data
  if (isTRUE(job$use_sample_data)) {
    add_log(job$id, "Loading sample vacalibration data")
    calib_sample <- load_vacalibration_sample(job$id)
    va_broad <- calib_sample$data
    algorithm_name <- calib_sample$va_algo
    if (is.null(algorithm_name) || length(algorithm_name) == 0) {
      algorithm_name <- "interva"
    }
  } else {
    add_log(job$id, paste("Loading data from:", job$input_file))
    input_data <- read.csv(job$input_file, stringsAsFactors = FALSE)

    # Expect columns: ID, cause
    if (!all(c("ID", "cause") %in% names(input_data))) {
      stop("Input file must have 'ID' and 'cause' columns")
    }

    # Ensure ID is character
    input_data$ID <- as.character(input_data$ID)

    add_log(job$id, paste("Loaded", nrow(input_data), "records with", length(unique(input_data$cause)), "unique causes"))
    add_log(job$id, paste("Causes:", paste(unique(input_data$cause), collapse = ", ")))

    # Fix causes that vacalibration::cause_map doesn't recognize
    add_log(job$id, "Mapping specific causes to broad categories...")
    input_data <- fix_causes_for_vacalibration(input_data)
    va_broad <- safe_cause_map(df = input_data, age_group = job$age_group)
    add_log(job$id, paste("Mapped to broad causes:", paste(colnames(va_broad), collapse = ", ")))

    # Map algorithm name
    algorithm_name <- tolower(gsub("VA$", "", job$algorithm))
    if (algorithm_name == "inter") algorithm_name <- "interva"
    if (algorithm_name == "insilico") algorithm_name <- "insilicova"
  }

  va_input <- setNames(list(va_broad), algorithm_name)

  # Extract parameters with defaults for backward compatibility
  calib_model_type <- if (!is.null(job$calib_model_type)) {
    job$calib_model_type
  } else {
    "Mmatprior"
  }

  ensemble_val <- if (!is.null(job$ensemble)) {
    as.logical(job$ensemble)
  } else {
    TRUE
  }

  add_log(job$id, paste("Running calibration for", job$age_group, "in", job$country))
  add_log(job$id, paste("calibmodel.type =", calib_model_type, ", ensemble =", ensemble_val))

  # Run vacalibration
  result <- run_with_capture(job$id, {
    vacalibration(
      va_data = va_input,
      age_group = job$age_group,
      country = job$country,
      calibmodel.type = calib_model_type,
      ensemble = ensemble_val,
      nMCMC = 5000,
      nBurn = 2000,
      plot_it = FALSE,
      verbose = TRUE
    )
  })

  add_log(job$id, "Calibration complete")

  # Extract results
  uncalibrated <- as.list(round(result$p_uncalib[1, ], 4))
  calibrated <- as.list(round(result$pcalib_postsumm[1, "postmean", ], 4))
  calibrated_low <- as.list(round(result$pcalib_postsumm[1, "lowcredI", ], 4))
  calibrated_high <- as.list(round(result$pcalib_postsumm[1, "upcredI", ], 4))

  # Extract misclassification matrix
  misclass_matrix <- NULL
  # Note: vacalibration 2.0 uses Mmat.asDirich (not Mmat_tomodel)
  mmat <- if (!is.null(result$Mmat.asDirich)) {
    result$Mmat.asDirich
  } else if (!is.null(result$Mmat_tomodel)) {
    result$Mmat_tomodel
  } else {
    NULL
  }
  if (!is.null(mmat)) {
    dnames <- dimnames(mmat)

    if (length(dim(mmat)) == 3) {
      # 3D: [algorithm, CHAMPS, VA]
      algorithms <- dnames[[1]]
      champs_causes <- dnames[[2]]
      va_causes <- dnames[[3]]

      misclass_matrix <- list()
      for (i in seq_along(algorithms)) {
        algo_name <- algorithms[i]
        algo_matrix <- mmat[i, , , drop = TRUE]

        misclass_matrix[[algo_name]] <- list(
          matrix = lapply(seq_len(nrow(algo_matrix)), function(row) {
            round(algo_matrix[row, ], 4)
          }),
          champs_causes = champs_causes,
          va_causes = va_causes
        )
      }
    } else if (length(dim(mmat)) == 2) {
      # 2D: [CHAMPS, VA] for single algorithm
      champs_causes <- dnames[[1]]
      va_causes <- dnames[[2]]
      algo_name <- if (is.character(algorithm_name)) algorithm_name else "combined"

      misclass_matrix <- list()
      misclass_matrix[[algo_name]] <- list(
        matrix = lapply(seq_len(nrow(mmat)), function(row) {
          round(mmat[row, ], 4)
        }),
        champs_causes = champs_causes,
        va_causes = va_causes
      )
    }
  }

  # Save outputs
  output_dir <- file.path("data", "outputs", job$id)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  # Create summary dataframe
  causes <- names(uncalibrated)
  summary_df <- data.frame(
    cause = causes,
    uncalibrated = unlist(uncalibrated),
    calibrated_mean = unlist(calibrated),
    calibrated_lower = unlist(calibrated_low),
    calibrated_upper = unlist(calibrated_high)
  )

  summary_file <- file.path(output_dir, "calibration_summary.csv")
  write.csv(summary_df, summary_file, row.names = FALSE)

  # Track output file in database
  add_job_file(job$id, "output", "calibration_summary.csv", summary_file, file.info(summary_file)$size)

  # Save misclassification matrices to CSV
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

  result_obj <- list(
    algorithm = algorithm_name,
    age_group = job$age_group,
    country = job$country,
    uncalibrated_csmf = uncalibrated,
    calibrated_csmf = calibrated,
    calibrated_ci_lower = calibrated_low,
    calibrated_ci_upper = calibrated_high,
    files = list(
      summary = "calibration_summary.csv"
    )
  )

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
