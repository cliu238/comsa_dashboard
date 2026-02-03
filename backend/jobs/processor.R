# Job Processor - Main orchestration and job management
# Entry point for job processing system

# Source dependencies
source("jobs/config.R")
source("jobs/utils.R")
source("jobs/algorithms/openva.R")
source("jobs/algorithms/vacalibration.R")
source("jobs/algorithms/ensemble.R")

# Start job processing asynchronously
start_job_async <- function(job_id) {
  # Use background Rscript process instead of future to avoid initialization overhead
  launch_background_job(job_id)
  invisible(NULL)
}

# Fallback background runner using a simple Rscript process
launch_background_job <- function(job_id) {
  runner_path <- normalizePath(file.path("jobs", "run_job.R"), mustWork = FALSE)

  if (!file.exists(runner_path)) {
    message("Runner script not found (", runner_path, "). Running job synchronously.")
    process_job(job_id)
    return(invisible(NULL))
  }

  rscript <- file.path(R.home("bin"), "Rscript")

  tryCatch({
    system2(rscript, args = c(runner_path, job_id), wait = FALSE)
  }, error = function(e) {
    message("Failed to start background runner: ", conditionMessage(e), ". Running job synchronously.")
    process_job(job_id)
  })

  invisible(NULL)
}

# Main job processor
process_job <- function(job_id) {
  job <- load_job_proc(job_id)
  if (is.null(job)) return(NULL)

  # Update status to running
  update_job_status(job_id, "running")

  tryCatch({
    result <- switch(job$type,
      "openva" = run_openva(job),
      "vacalibration" = run_vacalibration(job),
      "pipeline" = run_pipeline(job),
      stop("Unknown job type")
    )

    # Update job with results
    update_job_status(job_id, "completed")
    update_job_result(job_id, result)

  }, error = function(e) {
    update_job_status(job_id, "failed", error = conditionMessage(e))
  })
}

# Run full pipeline: openVA -> vacalibration
run_pipeline <- function(job) {
  add_log(job$id, "Starting full pipeline: openVA -> vacalibration")

  # Step 1: Run openVA
  add_log(job$id, "=== Step 1: openVA ===")

  if (isTRUE(job$use_sample_data)) {
    add_log(job$id, "Loading sample data")
    input_data <- load_openva_sample(job$age_group, job$id)
  } else {
    add_log(job$id, paste("Loading data from:", job$input_file))
    input_data <- read.csv(job$input_file, stringsAsFactors = FALSE)
  }

  add_log(job$id, paste("Data loaded:", nrow(input_data), "records"))

  # Run openVA - Check if multiple algorithms for ensemble
  # Parse algorithm parameter (handle JSON string or array)
  algorithms <- tryCatch({
    if (is.character(job$algorithm) && length(job$algorithm) == 1 && grepl("^\\[", job$algorithm)) {
      # It's a JSON string like "[\"InterVA\",\"InSilicoVA\"]"
      jsonlite::fromJSON(job$algorithm)
    } else if (is.character(job$algorithm)) {
      # It's a character vector
      job$algorithm
    } else {
      # Already a list
      job$algorithm
    }
  }, error = function(e) {
    # Fallback to original value
    job$algorithm
  })

  # Validate ensemble requirements
  ensemble_val <- if (!is.null(job$ensemble)) {
    as.logical(job$ensemble)
  } else {
    TRUE
  }

  if (ensemble_val && length(algorithms) < 2) {
    stop("Ensemble calibration requires at least 2 algorithms. Selected: ", length(algorithms))
  }

  if (length(algorithms) > 1) {
    add_log(job$id, paste("Running ensemble with", length(algorithms), "algorithms:", paste(algorithms, collapse=", ")))

    # Run all algorithms
    openva_results_list <- run_multiple_algorithms(algorithms, input_data, job$age_group, job$id)

    # Use first algorithm for primary COD output
    primary_result <- openva_results_list[[1]]
    cod <- getTopCOD(primary_result)
    csmf_openva <- getCSMF(primary_result)

    # Store algorithm list for results
    algorithm_name <- algorithms

  } else {
    # Single algorithm - existing logic
    algo <- algorithms[[1]]
    add_log(job$id, paste("Running", algo))

    if (algo == "InterVA") {
      openva_result <- run_with_capture(job$id, {
        codeVA(data = input_data, data.type = "WHO2016",
               model = "InterVA", version = "5.0",
               HIV = "l", Malaria = "l", write = FALSE)
      })
      algorithm_name <- "interva"
    } else if (algo == "InSilicoVA") {
      global_var_name <- paste0("..insilico_data_", job$id, "..")
      assign(global_var_name, input_data, envir = .GlobalEnv)

      # Call codeVA with data from global environment
      openva_result <- run_with_capture(job$id, {
        eval(parse(text = sprintf(
          "codeVA(data = `%s`, data.type = 'WHO2016', model = 'InSilicoVA', Nsim = 4000, auto.length = FALSE, write = FALSE)",
          global_var_name
        )), envir = .GlobalEnv)
      })

      # Clean up global variable
      rm(list = global_var_name, envir = .GlobalEnv)
      algorithm_name <- "insilicova"
    } else if (algo == "EAVA") {
      # EAVA requires an 'age' column in days and 'fb_day0' column
      input_data_eava <- input_data
      if (!"age" %in% names(input_data_eava)) {
        input_data_eava$age <- if (job$age_group == "neonate") {
          rep(14, nrow(input_data_eava))  # Default to 14 days for neonates
        } else {
          rep(180, nrow(input_data_eava))  # Default to 6 months for children
        }
      }

      # Add fb_day0 (death on first day of life) - default to "n" for WHO2016 data
      if (!"fb_day0" %in% names(input_data_eava)) {
        input_data_eava$fb_day0 <- "n"
      }

      openva_result <- run_with_capture(job$id, {
        codeVA(data = input_data_eava, data.type = "EAVA",
               model = "EAVA", age_group = job$age_group,
               write = FALSE)
      })
      algorithm_name <- "eava"
    }

    cod <- getTopCOD(openva_result)
    csmf_openva <- getCSMF(openva_result)
    openva_results_list <- setNames(list(openva_result), algorithm_name)
  }

  add_log(job$id, paste("openVA complete:", nrow(cod), "causes assigned"))

  # Step 2: Prepare for vacalibration
  add_log(job$id, "=== Step 2: Prepare for calibration ===")

  # Create broad cause matrices for all algorithms
  va_broad_list <- list()

  for (algo_name in names(openva_results_list)) {
    openva_res <- openva_results_list[[algo_name]]
    cod_temp <- getTopCOD(openva_res)

    va_data_df <- data.frame(
      ID = cod_temp$ID,
      cause = cod_temp$cause1,
      stringsAsFactors = FALSE
    )

    # Fix causes and convert to broad categories
    va_data_df <- fix_causes_for_vacalibration(va_data_df)
    va_broad <- safe_cause_map(df = va_data_df, age_group = job$age_group)
    va_broad_list[[algo_name]] <- va_broad
  }

  if (length(algorithms) > 1) {
    add_log(job$id, paste("Prepared data for algorithms:", paste(names(va_broad_list), collapse=", ")))
  } else {
    add_log(job$id, paste("Mapped to broad causes:", paste(colnames(va_broad_list[[1]]), collapse=", ")))
  }

  # Step 3: Run vacalibration
  add_log(job$id, "=== Step 3: vacalibration ===")

  # Extract parameters with defaults for backward compatibility
  calib_model_type <- if (!is.null(job$calib_model_type)) {
    job$calib_model_type
  } else {
    "Mmatprior"
  }

  # Disable ensemble if only one algorithm
  if (length(algorithms) == 1 && ensemble_val) {
    add_log(job$id, "Warning: Ensemble mode disabled - only 1 algorithm selected")
    ensemble_val <- FALSE
  }

  add_log(job$id, paste("calibmodel.type =", calib_model_type, ", ensemble =", ensemble_val))

  calib_result <- run_with_capture(job$id, {
    vacalibration(
      va_data = va_broad_list,  # Pass list with all algorithms
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

  # Extract results - handle both single algorithm and ensemble mode
  # In ensemble mode, results might be vectors instead of matrices
  if (is.null(dim(calib_result$p_uncalib)) || nrow(calib_result$p_uncalib) == 1) {
    # Vector or single row - extract directly, preserving names
    if (is.null(dim(calib_result$p_uncalib))) {
      # It's already a vector
      uncalibrated <- as.list(round(calib_result$p_uncalib, 4))
    } else {
      # It's a single-row matrix, extract with names
      uncalibrated <- as.list(round(calib_result$p_uncalib[1, ], 4))
    }
  } else {
    # Matrix with multiple rows - take first row
    uncalibrated <- as.list(round(calib_result$p_uncalib[1, ], 4))
  }

  if (is.null(dim(calib_result$pcalib_postsumm)) || dim(calib_result$pcalib_postsumm)[1] == 1) {
    # Handle vector or single row for ensemble
    if (length(dim(calib_result$pcalib_postsumm)) == 3) {
      # 3D array: [1, stat, causes]
      calibrated <- as.list(round(calib_result$pcalib_postsumm[1, "postmean", ], 4))
      calibrated_low <- as.list(round(calib_result$pcalib_postsumm[1, "lowcredI", ], 4))
      calibrated_high <- as.list(round(calib_result$pcalib_postsumm[1, "upcredI", ], 4))
    } else {
      # 2D matrix: [stat, causes]
      calibrated <- as.list(round(calib_result$pcalib_postsumm["postmean", ], 4))
      calibrated_low <- as.list(round(calib_result$pcalib_postsumm["lowcredI", ], 4))
      calibrated_high <- as.list(round(calib_result$pcalib_postsumm["upcredI", ], 4))
    }
  } else {
    # Matrix with multiple rows - take first row
    calibrated <- as.list(round(calib_result$pcalib_postsumm[1, "postmean", ], 4))
    calibrated_low <- as.list(round(calib_result$pcalib_postsumm[1, "lowcredI", ], 4))
    calibrated_high <- as.list(round(calib_result$pcalib_postsumm[1, "upcredI", ], 4))
  }

  # Extract misclassification matrix
  misclass_matrix <- NULL
  # Note: vacalibration 2.0 uses Mmat.asDirich (not Mmat_tomodel)
  mmat <- if (!is.null(calib_result$Mmat.asDirich)) {
    calib_result$Mmat.asDirich
  } else if (!is.null(calib_result$Mmat_tomodel)) {
    calib_result$Mmat_tomodel
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

  # Save cause assignments
  causes_file <- file.path(output_dir, "causes.csv")
  write.csv(cod, causes_file, row.names = FALSE)

  # Track output file in database
  add_job_file(job$id, "output", "causes.csv", causes_file, file.info(causes_file)$size)

  # Save calibration summary
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

  add_log(job$id, "All results saved")

  result_obj <- list(
    n_records = nrow(cod),
    algorithm = algorithm_name,
    age_group = job$age_group,
    country = job$country,
    openva_csmf = as.list(round(csmf_openva, 4)),
    cause_counts = as.list(table(cod$cause1)),
    uncalibrated_csmf = uncalibrated,
    calibrated_csmf = calibrated,
    calibrated_ci_lower = calibrated_low,
    calibrated_ci_upper = calibrated_high,
    files = list(
      causes = "causes.csv",
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
