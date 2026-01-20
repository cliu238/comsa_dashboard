# Job Processor - Handles openVA and vacalibration job execution

library(openVA)
library(vacalibration)
library(future)
library(jsonlite)

# Enable async processing - prefer multicore on Unix to avoid PSOCK socket issues
if (.Platform$OS.type != "windows" && future::supportsMulticore()) {
  plan(multicore)
} else {
  plan(multisession)
}

# Source database connection helpers
source("db/connection.R")

# Alias database functions for processor use
save_job_proc <- save_job
load_job_proc <- load_job

# Load bundled sample openVA data if available, otherwise fall back to package datasets
load_openva_sample <- function(age_group, job_id = NULL) {
  sample_dir <- file.path("data", "sample_data")
  sample_file <- if (tolower(age_group) == "neonate") {
    file.path(sample_dir, "sample_neonate_openva.rds")
  } else {
    file.path(sample_dir, "sample_child_openva.rds")
  }

  if (file.exists(sample_file)) {
    if (!is.null(job_id)) {
      add_log(job_id, paste("Using bundled sample data:", basename(sample_file)))
    }
    return(readRDS(sample_file))
  }

  if (!is.null(job_id)) {
    add_log(job_id, "Bundled sample data not found, using openVA package data")
  }

  if (tolower(age_group) == "neonate") {
    data(NeonatesVA5, package = "openVA")
    return(NeonatesVA5)
  }

  data(RandomVA6, package = "openVA")
  return(RandomVA6)
}

# Load bundled vacalibration sample if available
load_vacalibration_sample <- function(job_id = NULL) {
  sample_file <- file.path("data", "sample_data", "sample_vacalibration_broad.rds")

  if (file.exists(sample_file)) {
    if (!is.null(job_id)) {
      add_log(job_id, "Using bundled calibration sample data")
    }
    return(readRDS(sample_file))
  }

  if (!is.null(job_id)) {
    add_log(job_id, "Calibration sample file missing, using vacalibration package data")
  }

  data(comsamoz_public_broad, package = "vacalibration")
  return(comsamoz_public_broad)
}

# Start job processing asynchronously
start_job_async <- function(job_id) {
  tryCatch({
    future({
      process_job(job_id)
    }, seed = TRUE)
  }, error = function(e) {
    message("Future worker failed: ", conditionMessage(e), " - using background runner")
    launch_background_job(job_id)
  })
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

# Note: add_log is now defined in db/connection.R

# Run openVA processing
run_openva <- function(job) {
  add_log(job$id, "Starting openVA processing")

  # Load data
  if (isTRUE(job$use_sample_data)) {
    add_log(job$id, "Loading sample data")
    input_data <- load_openva_sample(job$age_group, job$id)
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
    # InSilicoVA uses rjags which has scoping issues in future contexts
    # Workaround: assign data to global environment temporarily
    assign("..insilico_data..", input_data, envir = .GlobalEnv)
    on.exit(rm("..insilico_data..", envir = .GlobalEnv), add = TRUE)
    result <- codeVA(
      data = ..insilico_data..,
      data.type = "WHO2016",
      model = "InSilicoVA",
      Nsim = 4000,
      auto.length = FALSE,
      write = FALSE
    )
  } else if (job$algorithm == "EAVA") {
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

    result <- codeVA(
      data = input_data_eava,
      data.type = "EAVA",
      model = "EAVA",
      age_group = job$age_group,
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

  causes_file <- file.path(output_dir, "causes.csv")
  write.csv(cod, causes_file, row.names = FALSE)

  # Track output file in database
  add_job_file(job$id, "output", "causes.csv", causes_file, file.info(causes_file)$size)

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

# Workaround for vacalibration::cause_map() bugs
# Bug 1: The package's cause_map() is missing "Undetermined" in its internal mapping
# Bug 2: cause_map() fails with "subscript out of bounds" when not all broad cause
#        categories are represented in the input data
# Fix: Pre-process data to ensure all required categories are present
fix_causes_for_vacalibration <- function(df) {
  # Map causes that cause_map() doesn't recognize to ones it does
  # Note: cause_map converts all causes to lowercase before matching
  cause_fixes <- c(
    "Undetermined" = "other"
  )

  df$cause <- ifelse(df$cause %in% names(cause_fixes),
                     cause_fixes[df$cause],
                     df$cause)
  return(df)
}

# Safe wrapper around cause_map that handles missing broad cause categories
# The vacalibration::cause_map function has a bug where it fails if not all
# 6 broad categories (for neonate) or 9 categories (for child) are present
safe_cause_map <- function(df, age_group) {
  # Define dummy IDs for each required broad cause category
  # These ensure cause_map has all columns it needs
  if (tolower(age_group) == "neonate") {
    # Neonate requires: congenital_malformation, pneumonia, sepsis_meningitis_inf, ipre, other, prematurity
    dummy_causes <- c(
      "congenital malformation",  # → congenital_malformation
      "neonatal pneumonia",       # → pneumonia
      "neonatal sepsis",          # → sepsis_meningitis_inf
      "birth asphyxia",           # → ipre
      "other",                    # → other
      "prematurity"               # → prematurity
    )
  } else if (tolower(age_group) == "child") {
    # Child requires: malaria, pneumonia, diarrhea, severe_malnutrition, hiv, injury, other, other_infections, nn_causes
    dummy_causes <- c(
      "malaria",                  # → malaria
      "pneumonia",                # → pneumonia
      "diarrheal diseases",       # → diarrhea
      "severe malnutrition",      # → severe_malnutrition
      "hiv/aids related death",   # → hiv
      "road traffic accident",    # → injury
      "other",                    # → other
      "measles",                  # → other_infections
      "congenital malformation"   # → nn_causes
    )
  } else {
    stop(paste("Unsupported age_group:", age_group))
  }

  # Add dummy records with unique IDs that won't conflict with real data
  dummy_df <- data.frame(
    ID = paste0("__dummy_", seq_along(dummy_causes), "__"),
    cause = dummy_causes,
    stringsAsFactors = FALSE
  )

  # Combine with actual data
  df_with_dummies <- rbind(df, dummy_df)

  # Call cause_map
  result <- vacalibration::cause_map(df = df_with_dummies, age_group = age_group)

  # Remove dummy rows from result
  dummy_ids <- dummy_df$ID
  result <- result[!rownames(result) %in% dummy_ids, , drop = FALSE]

  return(result)
}

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
  result <- vacalibration(
    va_data = va_input,
    age_group = job$age_group,
    country = job$country,
    calibmodel.type = calib_model_type,
    ensemble = ensemble_val,
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

  summary_file <- file.path(output_dir, "calibration_summary.csv")
  write.csv(summary_df, summary_file, row.names = FALSE)

  # Track output file in database
  add_job_file(job$id, "output", "calibration_summary.csv", summary_file, file.info(summary_file)$size)

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

# Run multiple algorithms and return named list for ensemble
run_multiple_algorithms <- function(algorithms, input_data, age_group, job_id) {
  results <- list()

  for (algo in algorithms) {
    add_log(job_id, paste("Running algorithm:", algo))

    if (algo == "InterVA") {
      result <- codeVA(
        data = input_data,
        data.type = "WHO2016",
        model = "InterVA",
        version = "5.0",
        HIV = "l",
        Malaria = "l",
        write = FALSE
      )
      results[["interva"]] <- result

    } else if (algo == "InSilicoVA") {
      # InSilicoVA global env workaround - assign to global variable
      # Use a unique variable name to avoid conflicts
      global_var_name <- paste0("..insilico_data_", job_id, "..")
      assign(global_var_name, input_data, envir = .GlobalEnv)

      # Call codeVA with data from global environment
      # Use backticks to escape the variable name (UUIDs have hyphens)
      result <- eval(parse(text = sprintf(
        "codeVA(data = `%s`, data.type = 'WHO2016', model = 'InSilicoVA', Nsim = 4000, auto.length = FALSE, write = FALSE)",
        global_var_name
      )), envir = .GlobalEnv)

      # Clean up global variable
      rm(list = global_var_name, envir = .GlobalEnv)
      results[["insilicova"]] <- result

    } else if (algo == "EAVA") {
      # EAVA requires an 'age' column in days and 'fb_day0' column
      # Note: EAVA may not work properly with WHO2016 data format
      tryCatch({
        input_data_eava <- input_data
        if (!"age" %in% names(input_data_eava)) {
          input_data_eava$age <- if (age_group == "neonate") {
            rep(14, nrow(input_data_eava))  # Default to 14 days for neonates
          } else {
            rep(180, nrow(input_data_eava))  # Default to 6 months for children
          }
        }

        # Add fb_day0 (death on first day of life) - default to "n" for WHO2016 data
        if (!"fb_day0" %in% names(input_data_eava)) {
          input_data_eava$fb_day0 <- "n"
        }

        result <- codeVA(
          data = input_data_eava,
          data.type = "EAVA",
          model = "EAVA",
          age_group = age_group,
          write = FALSE
        )
        results[["eava"]] <- result
        add_log(job_id, paste(algo, "complete"))
      }, error = function(e) {
        add_log(job_id, paste("EAVA failed:", conditionMessage(e), "- skipping"))
        # Don't add to results if it failed
      })
      next  # Skip the normal completion log below
    }

    add_log(job_id, paste(algo, "complete"))
  }

  return(results)
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
      openva_result <- codeVA(data = input_data, data.type = "WHO2016",
                              model = "InterVA", version = "5.0",
                              HIV = "l", Malaria = "l", write = FALSE)
      algorithm_name <- "interva"
    } else if (algo == "InSilicoVA") {
      temp_var <- paste0("..insilico_data_", job$id, "..")
      assign(temp_var, input_data, envir = .GlobalEnv)
      on.exit(rm(list = temp_var, envir = .GlobalEnv), add = TRUE)
      openva_result <- codeVA(data = get(temp_var, envir = .GlobalEnv),
                              data.type = "WHO2016", model = "InSilicoVA",
                              Nsim = 4000, auto.length = FALSE, write = FALSE)
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

      openva_result <- codeVA(data = input_data_eava, data.type = "EAVA",
                              model = "EAVA", age_group = job$age_group,
                              write = FALSE)
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

  calib_result <- vacalibration(
    va_data = va_broad_list,  # Pass list with all algorithms
    age_group = job$age_group,
    country = job$country,
    calibmodel.type = calib_model_type,
    ensemble = ensemble_val,
    nMCMC = 5000,
    nBurn = 2000,
    plot_it = FALSE,
    verbose = FALSE
  )

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
