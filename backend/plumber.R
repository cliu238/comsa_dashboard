# VA Calibration Platform - Plumber API
# Main API endpoints for job submission, status, and results

library(plumber)
library(jsonlite)
library(uuid)

# Source job processing functions
source("jobs/processor.R")

# Initialize job store directory (file-based for async processing)
job_store_dir <- "data/jobs"
dir.create(job_store_dir, recursive = TRUE, showWarnings = FALSE)

# Helper functions for file-based job storage
save_job <- function(job) {
  job_file <- file.path(job_store_dir, paste0(job$id, ".json"))
  writeLines(toJSON(job, auto_unbox = TRUE), job_file)
}

load_job <- function(job_id) {
  job_file <- file.path(job_store_dir, paste0(job_id, ".json"))
  if (!file.exists(job_file)) return(NULL)
  fromJSON(job_file)
}

job_exists <- function(job_id) {
  file.exists(file.path(job_store_dir, paste0(job_id, ".json")))
}

list_job_ids <- function() {
  files <- list.files(job_store_dir, pattern = "\\.json$")
  gsub("\\.json$", "", files)
}

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
#* @param job_type:str Type of job: "openva", "vacalibration", or "pipeline"
#* @param algorithm:str Algorithm to use (for openva): "InterVA", "InSilicoVA"
#* @param age_group:str Age group: "neonate" or "child"
#* @param country:str Country for calibration (default: "Mozambique")
#* @post /jobs
function(req, job_type = "pipeline", algorithm = "InterVA",
         age_group = "neonate", country = "Mozambique",
         calib_model_type = "Mmatprior", ensemble = "TRUE") {

  # Generate job ID
  job_id <- uuid::UUIDgenerate()

  # Parse multipart form data for file upload
  file_data <- NULL
  if (!is.null(req$body)) {
    # Handle file upload
    if (!is.null(req$body$file)) {
      file_data <- req$body$file
    }
  }

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

  # Validate ensemble requirements
  ensemble_bool <- as.logical(ensemble)
  if (ensemble_bool && length(algorithms) < 2) {
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
    tryCatch({
      if (is.raw(file_data)) {
        writeBin(file_data, input_path)
      } else if (is.character(file_data) && length(file_data) == 1 && file.exists(file_data)) {
        # Temp file path string
        file.copy(file_data, input_path)
      } else if (is.character(file_data)) {
        writeLines(file_data, input_path)
      } else if (is.list(file_data)) {
        # Try to extract raw content or file path from list
        if (!is.null(file_data$datapath)) {
          file.copy(file_data$datapath, input_path)
        } else if (!is.null(file_data$value)) {
          if (is.raw(file_data$value)) {
            writeBin(file_data$value, input_path)
          } else {
            writeLines(as.character(file_data$value), input_path)
          }
        } else {
          # Last resort: serialize the first element
          first_elem <- file_data[[1]]
          if (is.raw(first_elem)) {
            writeBin(first_elem, input_path)
          } else if (is.character(first_elem) && length(first_elem) == 1 && file.exists(first_elem)) {
            file.copy(first_elem, input_path)
          }
        }
      }
    }, error = function(e) {
      message("File upload error: ", e$message)
    })
    job$input_file <- input_path
  }

  # Store job
  save_job(job)

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

  list(
    job_id = job$id,
    type = job$type,
    status = job$status,
    created_at = job$created_at,
    started_at = job$started_at,
    completed_at = job$completed_at,
    error = job$error
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
#* @post /jobs/demo
function(job_type = "pipeline", algorithm = "InterVA", age_group = "neonate",
         calib_model_type = "Mmatprior", ensemble = "TRUE") {
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

  # Validate ensemble requirements
  ensemble_bool <- as.logical(ensemble)
  if (ensemble_bool && length(algorithms) < 2) {
    return(list(error = "Ensemble calibration requires at least 2 algorithms"))
  }

  job <- list(
    id = job_id,
    type = job_type,
    status = "pending",
    algorithm = algorithms,
    age_group = age_group,
    country = "Mozambique",
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
