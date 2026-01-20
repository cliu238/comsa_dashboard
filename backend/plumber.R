# VA Calibration Platform - Plumber API
# Main API endpoints for job submission, status, and results

library(plumber)
library(jsonlite)
library(uuid)

# Source database connection helpers
source("db/connection.R")

# Source job processing functions
source("jobs/processor.R")

#* @apiTitle VA Calibration Platform API
#* @apiDescription API for processing verbal autopsy data with openVA and vacalibration

#* @serializer json list(auto_unbox = TRUE)

#* Enable CORS
#* @filter cors
function(req, res) {
  res$setHeader("Access-Control-Allow-Origin", "*")
  res$setHeader("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
  res$setHeader("Access-Control-Allow-Headers", "Content-Type, Authorization")

  if (req$REQUEST_METHOD == "OPTIONS") {
    res$status <- 200
    return(list())
  }

  plumber::forward()
}

#* Health check
#* @get /health
function() {
  list(status = "ok", timestamp = Sys.time())
}

#* Submit a new job
#* @post /jobs
function(req) {

  tryCatch({
    # Generate job ID
    job_id <- uuid::UUIDgenerate()

    # Debug: print request structure
    message("=== DEBUG: Request Info ===")
    message("REQUEST_METHOD: ", req$REQUEST_METHOD)
    message("CONTENT_TYPE: ", req$CONTENT_TYPE)
    message("Args names: ", paste(names(req$args), collapse=", "))
    message("Body names: ", paste(names(req$body), collapse=", "))
    message("PostBody names: ", paste(names(req$postBody), collapse=", "))

    # Extract parameters from request - prioritize args for multipart
    job_type <- req$args$job_type
    if (is.null(job_type) || length(job_type) == 0) job_type <- "pipeline"

    algorithm <- req$args$algorithm
    if (is.null(algorithm) || length(algorithm) == 0) algorithm <- "InterVA"

    age_group <- req$args$age_group
    if (is.null(age_group) || length(age_group) == 0) age_group <- "neonate"

    country <- req$args$country
    if (is.null(country) || length(country) == 0) country <- "Mozambique"

    calib_model_type <- req$args$calib_model_type
    if (is.null(calib_model_type) || length(calib_model_type) == 0) calib_model_type <- "Mmatprior"

    ensemble <- req$args$ensemble
    if (is.null(ensemble) || length(ensemble) == 0) ensemble <- "TRUE"

    # Handle file upload
    file_data <- req$args$file

    message("Extracted job_type: '", job_type, "' (length: ", length(job_type), ")")
    message("Extracted algorithm: '", algorithm, "' (length: ", length(algorithm), ")")
    message("Extracted age_group: '", age_group, "' (length: ", length(age_group), ")")
    message("File data: ", if (is.null(file_data)) "NULL" else paste(class(file_data), "length:", length(file_data)))
  }, error = function(e) {
    return(list(error = paste("Error parsing request:", e$message)))
  })

  # Validate job type
  if (!job_type %in% c("openva", "vacalibration", "pipeline")) {
    return(list(error = "Invalid job_type. Must be 'openva', 'vacalibration', or 'pipeline'"))
  }

  # Parse algorithm parameter (single value or JSON array)
  algorithms <- tryCatch({
    if (is.character(algorithm) && grepl("^\\[", algorithm)) {
      jsonlite::fromJSON(algorithm)
    } else {
      algorithm
    }
  }, error = function(e) {
    algorithm
  })

  # Validate algorithms
  valid_algorithms <- c("InterVA", "InSilicoVA", "EAVA")
  if (is.character(algorithms)) {
    invalid <- setdiff(algorithms, valid_algorithms)
    if (length(invalid) > 0) {
      return(list(error = paste("Invalid algorithm(s):", paste(invalid, collapse=", "))))
    }
  }

  # Validate ensemble requirements (only for pipeline/vacalibration)
  ensemble_bool <- as.logical(ensemble)
  if (ensemble_bool && length(algorithms) < 2 && (job_type == "pipeline" || job_type == "vacalibration")) {
    return(list(error = "Ensemble calibration requires at least 2 algorithms"))
  }

  # Create job record
  job <- list(
    id = job_id,
    type = job_type,
    status = "pending",
    algorithm = algorithms,  # Store as array
    age_group = age_group,
    country = country,
    calib_model_type = calib_model_type,
    ensemble = ensemble_bool,
    created_at = format(Sys.time()),
    started_at = NULL,
    completed_at = NULL,
    error = NULL,
    result = NULL,
    log = character()
  )

  # Save uploaded file if present
  if (!is.null(file_data)) {
    upload_dir <- file.path("data", "uploads", job_id)
    dir.create(upload_dir, recursive = TRUE, showWarnings = FALSE)
    input_path <- file.path(upload_dir, "input.csv")

    # Handle different file upload formats from plumber
    file_saved <- tryCatch({
      if (is.raw(file_data)) {
        writeBin(file_data, input_path)
        TRUE
      } else if (is.character(file_data) && length(file_data) == 1 && file.exists(file_data)) {
        # Temp file path string
        file.copy(file_data, input_path)
        TRUE
      } else if (is.character(file_data)) {
        writeLines(file_data, input_path)
        TRUE
      } else if (is.list(file_data)) {
        # Debug: log list structure
        message("File data is list with names: ", paste(names(file_data), collapse=", "))
        message("List length: ", length(file_data))

        # Try to extract raw content or file path from list
        if (!is.null(file_data$datapath)) {
          file.copy(file_data$datapath, input_path)
          TRUE
        } else if (!is.null(file_data$value)) {
          if (is.raw(file_data$value)) {
            writeBin(file_data$value, input_path)
            TRUE
          } else {
            writeLines(as.character(file_data$value), input_path)
            TRUE
          }
        } else if (length(file_data) > 0) {
          # Try each element in the list
          saved <- FALSE
          for (i in seq_along(file_data)) {
            elem <- file_data[[i]]
            message("Trying element ", i, " of class: ", class(elem)[1])

            if (is.raw(elem)) {
              writeBin(elem, input_path)
              saved <- TRUE
              break
            } else if (is.character(elem) && length(elem) == 1 && file.exists(elem)) {
              # It's a file path
              file.copy(elem, input_path)
              saved <- TRUE
              break
            } else if (is.character(elem)) {
              # It's the file contents as character vector
              writeLines(elem, input_path)
              saved <- TRUE
              break
            } else if (is.list(elem) && !is.null(elem$datapath)) {
              file.copy(elem$datapath, input_path)
              saved <- TRUE
              break
            }
          }
          saved
        } else {
          FALSE
        }
      } else {
        FALSE
      }
    }, error = function(e) {
      message("File upload error: ", e$message)
      FALSE
    })

    message("File saved status: ", file_saved)
    message("File exists check: ", file.exists(input_path))
    message("Input path: ", input_path)

    if (!file_saved || !file.exists(input_path)) {
      return(list(error = paste("Failed to save uploaded file. File data type:", class(file_data))))
    }

    job$input_file <- input_path
  }

  # Store job in database
  save_job(job)

  # Track uploaded file in database if present
  if (!is.null(file_data)) {
    file_size <- file.info(input_path)$size
    add_job_file(job_id, "input", "input.csv", input_path, file_size)
  }

  # Start async processing
  start_job_async(job_id)

  list(
    job_id = job_id,
    status = "pending",
    message = "Job submitted successfully"
  )
}

#* Get job status
#* @param job_id:str Job ID
#* @get /jobs/<job_id>/status
function(job_id) {
  job <- load_job(job_id)
  if (is.null(job)) {
    return(list(error = "Job not found"))
  }

  # Convert empty error objects to NULL for proper JSON serialization
  error_val <- job$error
  if (is.list(error_val) && length(error_val) == 0) {
    error_val <- NULL
  }

  list(
    job_id = job$id,
    type = job$type,
    status = job$status,
    algorithm = job$algorithm,
    age_group = job$age_group,
    country = job$country,
    created_at = job$created_at,
    started_at = job$started_at,
    completed_at = job$completed_at,
    error = error_val
  )
}

#* Get job log
#* @param job_id:str Job ID
#* @get /jobs/<job_id>/log
function(job_id) {
  job <- load_job(job_id)
  if (is.null(job)) {
    return(list(error = "Job not found"))
  }

  list(
    job_id = job$id,
    log = job$log
  )
}

#* Get job results
#* @param job_id:str Job ID
#* @get /jobs/<job_id>/results
function(job_id) {
  job <- load_job(job_id)
  if (is.null(job)) {
    return(list(error = "Job not found"))
  }

  if (job$status != "completed") {
    return(list(
      error = "Job not completed",
      status = job$status
    ))
  }

  job$result
}

#* List all jobs
#* @get /jobs
function() {
  job_ids <- list_job_ids()

  jobs <- lapply(job_ids, function(id) {
    job <- load_job(id)
    list(
      job_id = job$id,
      type = job$type,
      status = job$status,
      created_at = job$created_at
    )
  })

  list(jobs = jobs)
}

#* Download result file
#* @param job_id:str Job ID
#* @param filename:str File to download
#* @serializer contentType list(type="application/octet-stream")
#* @get /jobs/<job_id>/download/<filename>
function(job_id, filename) {
  if (!job_exists(job_id)) {
    stop("Job not found")
  }

  output_dir <- file.path("data", "outputs", job_id)
  file_path <- file.path(output_dir, filename)

  if (!file.exists(file_path)) {
    stop("File not found")
  }

  readBin(file_path, "raw", file.info(file_path)$size)
}

#* Run demo job with sample data
#* @param job_type:str Type: "openva", "vacalibration", or "pipeline"
#* @param algorithm:str Algorithm: "InterVA" or "InSilicoVA"
#* @param age_group:str Age group: "neonate" or "child"
#* @param country:str Country for calibration
#* @post /jobs/demo
function(job_type = "pipeline", algorithm = "InterVA", age_group = "neonate",
         country = "Mozambique", calib_model_type = "Mmatprior", ensemble = "TRUE") {
  job_id <- uuid::UUIDgenerate()

  # Parse algorithm parameter (single value or JSON array)
  algorithms <- tryCatch({
    if (is.character(algorithm) && grepl("^\\[", algorithm)) {
      jsonlite::fromJSON(algorithm)
    } else {
      algorithm
    }
  }, error = function(e) {
    algorithm
  })

  # Validate ensemble requirements (only for pipeline/vacalibration)
  ensemble_bool <- as.logical(ensemble)
  if (ensemble_bool && length(algorithms) < 2 && (job_type == "pipeline" || job_type == "vacalibration")) {
    return(list(error = "Ensemble calibration requires at least 2 algorithms"))
  }

  job <- list(
    id = job_id,
    type = job_type,
    status = "pending",
    algorithm = algorithms,
    age_group = age_group,
    country = country,
    calib_model_type = calib_model_type,
    ensemble = ensemble_bool,
    created_at = format(Sys.time()),
    started_at = NULL,
    completed_at = NULL,
    error = NULL,
    result = NULL,
    log = character(),
    use_sample_data = TRUE
  )

  save_job(job)
  start_job_async(job_id)

  list(
    job_id = job_id,
    status = "pending",
    message = "Demo job submitted with sample data"
  )
}

#* List available pre-configured demo scenarios
#* @get /demos/list
function() {
  demo_file <- "data/demo_configs.json"
  if (!file.exists(demo_file)) {
    return(list(demos = list()))
  }

  demos <- jsonlite::fromJSON(demo_file)
  return(demos)
}

#* Launch a pre-configured demo by ID
#* @param demo_id:str Demo configuration ID
#* @post /demos/launch
function(demo_id) {
  demo_file <- "data/demo_configs.json"
  if (!file.exists(demo_file)) {
    return(list(error = "Demo configurations not found"))
  }

  demos_data <- jsonlite::fromJSON(demo_file)
  demo <- demos_data$demos[demos_data$demos$id == demo_id, ]

  if (nrow(demo) == 0) {
    return(list(error = paste("Demo not found:", demo_id)))
  }

  # Extract demo configuration
  job_id <- uuid::UUIDgenerate()

  # Properly extract algorithm field from dataframe
  algorithm_value <- demo$algorithm[[1]]
  if (is.list(algorithm_value)) {
    # It's a list, convert to character vector
    algorithm_value <- unlist(algorithm_value)
  }

  job <- list(
    id = job_id,
    type = as.character(demo$job_type),
    status = "pending",
    algorithm = algorithm_value,
    age_group = as.character(demo$age_group),
    country = as.character(demo$country),
    calib_model_type = as.character(demo$calib_model_type),
    ensemble = as.logical(demo$ensemble),
    created_at = format(Sys.time()),
    started_at = NULL,
    completed_at = NULL,
    error = NULL,
    result = NULL,
    log = character(),
    use_sample_data = TRUE,
    demo_id = as.character(demo_id),
    demo_name = as.character(demo$name)
  )

  save_job(job)
  start_job_async(job_id)

  list(
    job_id = job_id,
    status = "pending",
    message = paste("Demo launched:", demo$name)
  )
}

#* Rerun a failed job with its original parameters
#* @param job_id:str Job ID to rerun
#* @post /jobs/<job_id>/rerun
function(job_id) {
  # Load original job
  old_job <- load_job(job_id)
  if (is.null(old_job)) {
    return(list(error = "Job not found"))
  }

  # Check if input file exists
  if (is.null(old_job$input_file) || !file.exists(old_job$input_file)) {
    return(list(error = "Original input file not found"))
  }

  # Create new job ID
  new_job_id <- uuid::UUIDgenerate()

  # Copy input file to new job directory
  new_upload_dir <- file.path("data", "uploads", new_job_id)
  dir.create(new_upload_dir, recursive = TRUE, showWarnings = FALSE)
  new_input_path <- file.path(new_upload_dir, "input.csv")
  file.copy(old_job$input_file, new_input_path)

  # Create new job with same parameters
  new_job <- list(
    id = new_job_id,
    type = old_job$type,
    status = "pending",
    algorithm = old_job$algorithm,
    age_group = old_job$age_group,
    country = old_job$country,
    calib_model_type = old_job$calib_model_type,
    ensemble = old_job$ensemble,
    created_at = format(Sys.time()),
    started_at = NULL,
    completed_at = NULL,
    error = NULL,
    result = NULL,
    log = character(),
    input_file = new_input_path,
    rerun_of = job_id
  )

  save_job(new_job)
  start_job_async(new_job_id)

  list(
    job_id = new_job_id,
    status = "pending",
    message = paste0("Rerun of job ", job_id, " submitted successfully"),
    original_job_id = job_id
  )
}
