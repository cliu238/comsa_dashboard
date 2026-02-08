# Job Processor - Main orchestration and job management
# Entry point for job processing system

# Source dependencies
source("jobs/config.R")
source("jobs/utils.R")
source("jobs/algorithms/openva.R")
source("jobs/algorithms/vacalibration.R")

# Start job processing asynchronously
start_job_async <- function(job_id) {
  launch_background_job(job_id)
  invisible(NULL)
}

# Background runner using Rscript process
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

  update_job_status(job_id, "running")

  tryCatch({
    result <- switch(job$type,
      "openva" = run_openva(job),
      "vacalibration" = run_vacalibration(job),
      "pipeline" = run_pipeline(job),
      stop("Unknown job type")
    )

    update_job_status(job_id, "completed")
    update_job_result(job_id, result)

  }, error = function(e) {
    update_job_status(job_id, "failed", error = conditionMessage(e))
  })
}

# Run full pipeline: openVA (single algorithm) -> vacalibration
run_pipeline <- function(job) {
  add_log(job$id, "Starting pipeline: openVA -> vacalibration")

  # Step 1: Run openVA with single algorithm
  add_log(job$id, "=== Step 1: openVA ===")

  if (isTRUE(job$use_sample_data)) {
    add_log(job$id, "Loading sample data")
    input_data <- load_openva_sample(job$age_group, job$id)
  } else {
    add_log(job$id, paste("Loading data from:", job$input_file))
    input_data <- read.csv(job$input_file, stringsAsFactors = FALSE)
  }

  add_log(job$id, paste("Data loaded:", nrow(input_data), "records"))

  # Use first algorithm only (pipeline = one algorithm)
  algo <- if (is.character(job$algorithm)) job$algorithm[1] else as.character(job$algorithm)[1]
  algorithm_name <- normalize_algo_name(algo)

  add_log(job$id, paste("Running", algo))

  if (algo == "InterVA") {
    openva_result <- run_with_capture(job$id, {
      codeVA(data = input_data, data.type = "WHO2016",
             model = "InterVA", version = "5.0",
             HIV = "l", Malaria = "l", write = FALSE)
    })
  } else if (algo == "InSilicoVA") {
    global_var_name <- paste0("..insilico_data_", job$id, "..")
    assign(global_var_name, input_data, envir = .GlobalEnv)

    openva_result <- run_with_capture(job$id, {
      eval(parse(text = sprintf(
        "codeVA(data = `%s`, data.type = 'WHO2016', model = 'InSilicoVA', Nsim = 4000, auto.length = FALSE, write = FALSE)",
        global_var_name
      )), envir = .GlobalEnv)
    })

    rm(list = global_var_name, envir = .GlobalEnv)
  } else if (algo == "EAVA") {
    input_data_eava <- input_data
    if (!"age" %in% names(input_data_eava)) {
      input_data_eava$age <- if (job$age_group == "neonate") {
        rep(14, nrow(input_data_eava))
      } else {
        rep(180, nrow(input_data_eava))
      }
    }
    if (!"fb_day0" %in% names(input_data_eava)) {
      input_data_eava$fb_day0 <- "n"
    }

    openva_result <- run_with_capture(job$id, {
      codeVA(data = input_data_eava, data.type = "EAVA",
             model = "EAVA", age_group = job$age_group,
             write = FALSE)
    })
  } else {
    stop("Unsupported algorithm: ", algo)
  }

  cod <- getTopCOD(openva_result)
  csmf_openva <- getCSMF(openva_result)

  add_log(job$id, paste("openVA complete:", nrow(cod), "causes assigned"))

  # Step 2: Prepare for vacalibration
  add_log(job$id, "=== Step 2: Prepare for calibration ===")

  va_data_df <- data.frame(
    ID = cod$ID,
    cause = cod$cause1,
    stringsAsFactors = FALSE
  )

  va_data_df <- fix_causes_for_vacalibration(va_data_df)
  va_broad <- safe_cause_map(df = va_data_df, age_group = job$age_group)
  add_log(job$id, paste("Mapped to broad causes:", paste(colnames(va_broad), collapse = ", ")))

  va_input <- setNames(list(va_broad), algorithm_name)

  # Step 3: Run vacalibration (single algorithm, no ensemble)
  add_log(job$id, "=== Step 3: vacalibration ===")

  calib_model_type <- if (!is.null(job$calib_model_type)) job$calib_model_type else "Mmatprior"

  add_log(job$id, paste("calibmodel.type =", calib_model_type))

  calib_result <- run_with_capture(job$id, {
    vacalibration(
      va_data = va_input,
      age_group = job$age_group,
      country = job$country,
      calibmodel.type = calib_model_type,
      ensemble = FALSE,
      nMCMC = 5000,
      nBurn = 2000,
      plot_it = FALSE,
      verbose = TRUE
    )
  })

  add_log(job$id, "Calibration complete")

  # Extract results (single algorithm — first row)
  uncalibrated   <- as.list(round(calib_result$p_uncalib[1, ], 4))
  calibrated     <- as.list(round(calib_result$pcalib_postsumm[1, "postmean", ], 4))
  calibrated_low <- as.list(round(calib_result$pcalib_postsumm[1, "lowcredI", ], 4))
  calibrated_high <- as.list(round(calib_result$pcalib_postsumm[1, "upcredI", ], 4))

  # Extract misclassification matrix (2D for single algorithm)
  mmat <- if (!is.null(calib_result$Mmat.asDirich)) calib_result$Mmat.asDirich
          else if (!is.null(calib_result$Mmat_tomodel)) calib_result$Mmat_tomodel
          else NULL

  misclass_matrix <- NULL
  if (!is.null(mmat)) {
    dnames <- dimnames(mmat)

    if (length(dim(mmat)) == 3) {
      # Single algo can still produce 3D with dim[1]=1
      algo_matrix <- mmat[1, , , drop = TRUE]
      misclass_matrix <- list()
      misclass_matrix[[algorithm_name]] <- list(
        matrix = lapply(seq_len(nrow(algo_matrix)), function(row) round(algo_matrix[row, ], 4)),
        champs_causes = dnames[[2]],
        va_causes = dnames[[3]]
      )
    } else if (length(dim(mmat)) == 2) {
      misclass_matrix <- list()
      misclass_matrix[[algorithm_name]] <- list(
        matrix = lapply(seq_len(nrow(mmat)), function(row) round(mmat[row, ], 4)),
        champs_causes = dnames[[1]],
        va_causes = dnames[[2]]
      )
    }
  }

  # Save outputs
  output_dir <- file.path("data", "outputs", job$id)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  # Save cause assignments
  causes_file <- file.path(output_dir, "causes.csv")
  write.csv(cod, causes_file, row.names = FALSE)
  add_job_file(job$id, "output", "causes.csv", causes_file, file.info(causes_file)$size)

  # Save calibration summary
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

  # Save misclassification matrix
  if (!is.null(misclass_matrix)) {
    algo_data <- misclass_matrix[[algorithm_name]]
    mmat_df <- as.data.frame(do.call(rbind, algo_data$matrix))
    colnames(mmat_df) <- algo_data$va_causes
    mmat_df <- cbind(CHAMPS_Cause = algo_data$champs_causes, mmat_df)

    mmat_file <- file.path(output_dir, "misclass_matrix.csv")
    write.csv(mmat_df, mmat_file, row.names = FALSE)
    add_job_file(job$id, "output", "misclass_matrix.csv", mmat_file, file.info(mmat_file)$size)
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
    result_obj$files$misclass_matrix <- "misclass_matrix.csv"
  }

  return(result_obj)
}
