# Job Processor - Handles openVA and vacalibration job execution

library(openVA)
library(vacalibration)
library(future)
library(jsonlite)

# Enable async processing
plan(multisession)

# Job store directory (same as plumber.R)
job_store_dir <- "data/jobs"

# File-based job storage helpers for processor
save_job_proc <- function(job) {
  job_file <- file.path(job_store_dir, paste0(job$id, ".json"))
  writeLines(toJSON(job, auto_unbox = TRUE), job_file)
}

load_job_proc <- function(job_id) {
  job_file <- file.path(job_store_dir, paste0(job_id, ".json"))
  if (!file.exists(job_file)) return(NULL)
  fromJSON(job_file)
}

# Start job processing asynchronously
start_job_async <- function(job_id) {
  future({
    process_job(job_id)
  }, seed = TRUE)
  invisible(NULL)
}

# Main job processor
process_job <- function(job_id) {
  job <- load_job_proc(job_id)
  if (is.null(job)) return(NULL)

  # Update status to running
  job$status <- "running"
  job$started_at <- format(Sys.time())
  save_job_proc(job)

  tryCatch({
    result <- switch(job$type,
      "openva" = run_openva(job),
      "vacalibration" = run_vacalibration(job),
      "pipeline" = run_pipeline(job),
      stop("Unknown job type")
    )

    # Update job with results
    job <- load_job_proc(job_id)
    job$status <- "completed"
    job$completed_at <- format(Sys.time())
    job$result <- result
    save_job_proc(job)

  }, error = function(e) {
    job <- load_job_proc(job_id)
    job$status <- "failed"
    job$completed_at <- format(Sys.time())
    job$error <- conditionMessage(e)
    save_job_proc(job)
  })
}

# Add log entry
add_log <- function(job_id, message) {
  job <- load_job_proc(job_id)
  if (is.null(job)) return(NULL)
  job$log <- c(job$log, paste0("[", format(Sys.time()), "] ", message))
  save_job_proc(job)
}

# Run openVA processing
run_openva <- function(job) {
  add_log(job$id, "Starting openVA processing")

  # Load data
  if (isTRUE(job$use_sample_data)) {
    add_log(job$id, "Loading sample data")
    if (job$age_group == "neonate") {
      data(NeonatesVA5, package = "openVA")
      input_data <- NeonatesVA5
    } else {
      data(RandomVA6, package = "openVA")
      input_data <- RandomVA6
    }
  } else {
    add_log(job$id, paste("Loading data from:", job$input_file))
    input_data <- read.csv(job$input_file, stringsAsFactors = FALSE)
  }

  add_log(job$id, paste("Data loaded:", nrow(input_data), "records"))

  # Run openVA
  add_log(job$id, paste("Running", job$algorithm))

  if (job$algorithm == "InterVA") {
    result <- codeVA(
      data = input_data,
      data.type = "WHO2016",
      model = "InterVA",
      version = "5.0",
      HIV = "l",
      Malaria = "l",
      write = FALSE
    )
  } else if (job$algorithm == "InSilicoVA") {
    result <- codeVA(
      data = input_data,
      data.type = "WHO2016",
      model = "InSilicoVA",
      Nsim = 4000,
      write = FALSE
    )
  } else {
    stop(paste("Unsupported algorithm:", job$algorithm))
  }

  add_log(job$id, "openVA processing complete")

  # Extract cause assignments
  cod <- getTopCOD(result)
  add_log(job$id, paste("Assigned causes for", nrow(cod), "deaths"))

  # Get CSMF
  csmf <- getCSMF(result)

  # Save outputs
  output_dir <- file.path("data", "outputs", job$id)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  write.csv(cod, file.path(output_dir, "causes.csv"), row.names = FALSE)

  add_log(job$id, "Results saved")

  # Return summary
  list(
    n_records = nrow(cod),
    cause_counts = as.list(table(cod$cause1)),
    csmf = as.list(csmf),
    files = list(
      causes = "causes.csv"
    )
  )
}

# Run vacalibration
run_vacalibration <- function(job) {
  add_log(job$id, "Starting vacalibration")

  # Load data
  if (isTRUE(job$use_sample_data)) {
    add_log(job$id, "Loading sample vacalibration data")
    data(comsamoz_public_openVAout, package = "vacalibration")

    # Use cause_map to convert to broad categories
    va_broad <- cause_map(df = comsamoz_public_openVAout$data, age_group = job$age_group)
    va_input <- setNames(
      list(va_broad),
      list(comsamoz_public_openVAout$va_algo)
    )
    algorithm_name <- comsamoz_public_openVAout$va_algo
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

    # Use cause_map to convert specific causes to broad categories
    add_log(job$id, "Mapping specific causes to broad categories...")
    va_broad <- cause_map(df = input_data, age_group = job$age_group)
    add_log(job$id, paste("Mapped to broad causes:", paste(colnames(va_broad), collapse = ", ")))

    # Map algorithm name
    algorithm_name <- tolower(gsub("VA$", "", job$algorithm))
    if (algorithm_name == "inter") algorithm_name <- "interva"
    if (algorithm_name == "insilico") algorithm_name <- "insilicova"

    va_input <- setNames(list(va_broad), algorithm_name)
  }

  add_log(job$id, paste("Running calibration for", job$age_group, "in", job$country))

  # Run vacalibration
  result <- vacalibration(
    va_data = va_input,
    age_group = job$age_group,
    country = job$country,
    nMCMC = 5000,
    nBurn = 2000,
    plot_it = FALSE,
    verbose = FALSE
  )

  add_log(job$id, "Calibration complete")

  # Extract results
  uncalibrated <- as.list(round(result$p_uncalib[1, ], 4))
  calibrated <- as.list(round(result$pcalib_postsumm[1, "postmean", ], 4))
  calibrated_low <- as.list(round(result$pcalib_postsumm[1, "lowcredI", ], 4))
  calibrated_high <- as.list(round(result$pcalib_postsumm[1, "upcredI", ], 4))

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
  write.csv(summary_df, file.path(output_dir, "calibration_summary.csv"), row.names = FALSE)

  add_log(job$id, "Results saved")

  list(
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
}

# Run full pipeline: openVA -> vacalibration
run_pipeline <- function(job) {
  add_log(job$id, "Starting full pipeline: openVA -> vacalibration")

  # Step 1: Run openVA
  add_log(job$id, "=== Step 1: openVA ===")

  if (isTRUE(job$use_sample_data)) {
    add_log(job$id, "Loading sample data")
    if (job$age_group == "neonate") {
      data(NeonatesVA5, package = "openVA")
      input_data <- NeonatesVA5
    } else {
      data(RandomVA6, package = "openVA")
      input_data <- RandomVA6
    }
  } else {
    add_log(job$id, paste("Loading data from:", job$input_file))
    input_data <- read.csv(job$input_file, stringsAsFactors = FALSE)
  }

  add_log(job$id, paste("Data loaded:", nrow(input_data), "records"))

  # Run openVA
  add_log(job$id, paste("Running", job$algorithm))

  if (job$algorithm == "InterVA") {
    openva_result <- codeVA(
      data = input_data,
      data.type = "WHO2016",
      model = "InterVA",
      version = "5.0",
      HIV = "l",
      Malaria = "l",
      write = FALSE
    )
    algorithm_name <- "interva"
  } else {
    openva_result <- codeVA(
      data = input_data,
      data.type = "WHO2016",
      model = "InSilicoVA",
      Nsim = 4000,
      write = FALSE
    )
    algorithm_name <- "insilicova"
  }

  cod <- getTopCOD(openva_result)
  csmf_openva <- getCSMF(openva_result)
  add_log(job$id, paste("openVA complete:", nrow(cod), "causes assigned"))

  # Step 2: Prepare for vacalibration
  add_log(job$id, "=== Step 2: Prepare for calibration ===")

  # Create dataframe with cause assignments
  va_data_df <- data.frame(
    ID = cod$ID,
    cause = cod$cause1,
    stringsAsFactors = FALSE
  )

  add_log(job$id, paste("Specific causes from openVA:", paste(names(table(va_data_df$cause)), collapse = ", ")))

  # Use vacalibration's cause_map() to convert specific causes to broad categories
  va_broad <- cause_map(df = va_data_df, age_group = job$age_group)

  add_log(job$id, paste("Mapped to broad causes:", paste(colnames(va_broad), collapse = ", ")))

  # Step 3: Run vacalibration
  add_log(job$id, "=== Step 3: vacalibration ===")

  # Pass the broad cause matrix to vacalibration
  va_input <- setNames(list(va_broad), algorithm_name)

  calib_result <- vacalibration(
    va_data = va_input,
    age_group = job$age_group,
    country = job$country,
    nMCMC = 5000,
    nBurn = 2000,
    plot_it = FALSE,
    verbose = FALSE
  )

  add_log(job$id, "Calibration complete")

  # Extract results
  uncalibrated <- as.list(round(calib_result$p_uncalib[1, ], 4))
  calibrated <- as.list(round(calib_result$pcalib_postsumm[1, "postmean", ], 4))
  calibrated_low <- as.list(round(calib_result$pcalib_postsumm[1, "lowcredI", ], 4))
  calibrated_high <- as.list(round(calib_result$pcalib_postsumm[1, "upcredI", ], 4))

  # Save outputs
  output_dir <- file.path("data", "outputs", job$id)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  # Save cause assignments
  write.csv(cod, file.path(output_dir, "causes.csv"), row.names = FALSE)

  # Save calibration summary
  causes <- names(uncalibrated)
  summary_df <- data.frame(
    cause = causes,
    uncalibrated = unlist(uncalibrated),
    calibrated_mean = unlist(calibrated),
    calibrated_lower = unlist(calibrated_low),
    calibrated_upper = unlist(calibrated_high)
  )
  write.csv(summary_df, file.path(output_dir, "calibration_summary.csv"), row.names = FALSE)

  add_log(job$id, "All results saved")

  list(
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
}
