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
         age_group = "neonate", country = "Mozambique") {

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

  # Create job record
  job <- list(
    id = job_id,
    type = job_type,
    status = "pending",
    algorithm = algorithm,
    age_group = age_group,
    country = country,
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

    # Write file content
    if (is.raw(file_data)) {
      writeBin(file_data, input_path)
    } else if (is.character(file_data)) {
      writeLines(file_data, input_path)
    }
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
#* @param age_group:str Age group: "neonate" or "child"
#* @post /jobs/demo
function(job_type = "pipeline", age_group = "neonate") {
  job_id <- uuid::UUIDgenerate()

  job <- list(
    id = job_id,
    type = job_type,
    status = "pending",
    algorithm = "InterVA",
    age_group = age_group,
    country = "Mozambique",
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
