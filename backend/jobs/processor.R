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

  # A fresh pod has none of the uploaded files on disk (issue #110); restore any
  # missing ones from the DB mirror before the algorithm tries to read them.
  ensure_input_files(job)

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

# Run full pipeline: openVA -> vacalibration (supports ensemble mode)
run_pipeline <- function(job) {
  add_log(job$id, "Starting pipeline: openVA -> vacalibration")

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

  # Determine algorithms and ensemble mode
  algorithms <- if (is.character(job$algorithm)) job$algorithm else as.character(job$algorithm)
  ensemble_val <- isTRUE(job$ensemble) && length(algorithms) >= 2

  if (ensemble_val) {
    add_log(job$id, paste("Pipeline ensemble: running openVA for", paste(algorithms, collapse=", ")))
  } else {
    algorithms <- algorithms[1]  # Single algo for non-ensemble
  }

  # Loop openVA over all algorithms
  va_input <- list()
  all_cod <- NULL
  openva_csmfs <- list()  # Per-algorithm CSMFs

  for (algo in algorithms) {
    algorithm_name <- normalize_algo_name(algo)
    add_log(job$id, paste("Running openVA:", algo))

    if (algo == "InterVA") {
      openva_result <- run_with_capture(job$id, {
        codeVA(data = input_data, data.type = "WHO2016",
               model = "InterVA", version = "5.0",
               HIV = "l", Malaria = "l", write = FALSE)
      })
    } else if (algo == "InSilicoVA") {
      global_var_name <- paste0("..insilico_data_", job$id, "_", algo, "..")
      assign(global_var_name, input_data, envir = .GlobalEnv)

      openva_result <- run_with_capture(job$id, {
        eval(parse(text = sprintf(
          "codeVA(data = `%s`, data.type = 'WHO2016', model = 'InSilicoVA', Nsim = 4000, auto.length = FALSE, write = FALSE)",
          global_var_name
        )), envir = .GlobalEnv)
      })

      rm(list = global_var_name, envir = .GlobalEnv)
    } else if (algo == "EAVA") {
      input_data_eava <- prepare_eava_input(input_data, job$age_group)

      openva_result <- run_with_capture(job$id, {
        codeVA(data = input_data_eava, data.type = "EAVA",
               model = "EAVA", age_group = job$age_group,
               write = FALSE)
      })
    } else {
      stop("Unsupported algorithm: ", algo)
    }

    cod <- extract_top_cod(openva_result)
    openva_csmfs[[algorithm_name]] <- as.list(round(getCSMF(openva_result), 4))

    add_log(job$id, paste("openVA", algo, "complete:", nrow(cod), "causes assigned"))

    # Prepare for calibration
    va_data_df <- data.frame(ID = cod$ID, cause = cod$cause1, stringsAsFactors = FALSE)
    va_data_df_fixed <- fix_causes_for_vacalibration(va_data_df)
    va_broad <- safe_cause_map(df = va_data_df_fixed, age_group = job$age_group)
    # Reject records whose cause didn't map to a supported broad category
    # instead of silently dropping them (issue #92).
    assert_all_causes_mapped(va_data_df, va_broad, job$age_group)

    va_input[[algorithm_name]] <- va_broad

    cod$algorithm <- algorithm_name
    if (is.null(all_cod)) all_cod <- cod else all_cod <- rbind(all_cod, cod)
  }

  # Build cause display from last processed algorithm
  cause_display_names <- build_cause_display_map(va_data_df, va_broad)
  cause_order <- build_cause_order(va_broad)

  add_log(job$id, paste("Mapped to broad causes:", paste(colnames(va_broad), collapse = ", ")))

  # Step 3: Run vacalibration
  add_log(job$id, "=== Step 3: vacalibration ===")

  # Map legacy calib_model_type values to vacalibration v2.2 missmat_type
  raw_type <- if (!is.null(job$calib_model_type)) job$calib_model_type else "Mmatprior"
  missmat_type <- switch(raw_type,
    "Mmatprior" = "prior",
    "Mmatfixed" = "fixed",
    raw_type
  )
  n_mcmc <- if (!is.null(job$n_mcmc)) as.integer(job$n_mcmc) else 5000L
  n_burn <- if (!is.null(job$n_burn)) as.integer(job$n_burn) else 2000L
  n_thin <- if (!is.null(job$n_thin)) as.integer(job$n_thin) else 1L

  add_log(job$id, paste("missmat_type =", missmat_type, ", ensemble =", ensemble_val))
  add_log(job$id, paste("MCMC: nMCMC =", n_mcmc, ", nBurn =", n_burn, ", nThin =", n_thin))

  # Zero-death cause exclusion (issue #101, R1): a broad cause with no observed
  # deaths stalls path correction (see utils.R's LAMBDA_CEILING comment).
  # Excluded per algorithm via donotcalib, logged so the exclusion is never
  # silent (threat T-01-01-06). Shared with run_vacalibration() so the policy,
  # the log wording and the hidden-cause rule cannot drift between the two paths.
  exclusions <- prepare_calibration_exclusions(va_input, job)
  hidden_causes <- exclusions$hidden

  calib_result <- run_with_capture(job$id, {
    vacalibration(
      va_data = va_input,
      age_group = job$age_group,
      country = job$country,
      missmat_type = missmat_type,
      ensemble = ensemble_val,
      donotcalib = exclusions$donotcalib,
      nMCMC = n_mcmc,
      nBurn = n_burn,
      nThin = n_thin,
      verbose = TRUE
    )
  })

  add_log(job$id, "Calibration complete")

  # Save outputs
  output_dir <- file.path("data", "outputs", job$id)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  # Save cause assignments
  causes_file <- file.path(output_dir, "causes.csv")
  write.csv(all_cod, causes_file, row.names = FALSE)
  add_job_file(job$id, "output", "causes.csv", causes_file, file.info(causes_file)$size)

  # No "all results saved" line here: assemble_calibration_result() below still has
  # calibration_summary.csv and the misclassification CSVs to write, and logs its own
  # "Results saved" once they are on disk (issue R3 moved that work out of this
  # function). Logging it here made the claim false and printed two saved-lines.

  # Assemble the shared fields (issue R3), then merge the pipeline-only ones.
  # `algorithm` is passed as the full normalized vector, unifying this call with
  # run_vacalibration()'s equivalent (which replaced a conditional expression).
  # It does NOT close the independent multi-algorithm gap on this path: an
  # ensemble-off pipeline run is still truncated to `algorithms[1]` above, so the
  # vector holds one element by the time it gets here. Issue #83 remains open for
  # the pipeline path -- see .planning/phases/01-issue-101-calibration-correctness/deferred-items.md.
  algo_names_pipeline <- unique(vapply(algorithms, normalize_algo_name, character(1), USE.NAMES = FALSE))
  result_obj <- assemble_calibration_result(
    calib_result = calib_result,
    job = job,
    algo_names = algo_names_pipeline,
    output_dir = output_dir,
    ensemble_val = ensemble_val,
    cause_display_names = cause_display_names,
    cause_order = cause_order,
    hidden_causes = hidden_causes
  )

  result_obj$n_records <- length(unique(all_cod$ID))
  result_obj$openva_csmf <- openva_csmfs
  result_obj$cause_counts <- as.list(table(all_cod$cause1))
  result_obj$files$causes <- "causes.csv"

  return(result_obj)
}
