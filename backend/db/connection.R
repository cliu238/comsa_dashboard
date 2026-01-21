# Database Connection Helper for COMSA Dashboard
# Provides PostgreSQL database access for job tracking

library(RPostgres)
library(jsonlite)
library(pool)

# Load environment variables
load_env <- function() {
  # Try .env.local first (for local development), then .env (for deployment)
  env_file <- NULL

  # Check for .env.local in current directory
  if (file.exists(".env.local")) {
    env_file <- ".env.local"
  } else if (file.exists("../.env.local")) {
    # Try parent directory (when running from backend/)
    env_file <- "../.env.local"
  } else if (file.exists(".env")) {
    # Fall back to .env
    env_file <- ".env"
  } else if (file.exists("../.env")) {
    # Try parent directory
    env_file <- "../.env"
  }

  if (!is.null(env_file)) {
    message("Loading environment from: ", env_file)
    env_lines <- readLines(env_file)
    env_lines <- env_lines[!grepl("^#", env_lines) & nzchar(env_lines)]

    for (line in env_lines) {
      if (grepl("=", line)) {
        parts <- strsplit(line, "=", fixed = TRUE)[[1]]
        key <- trimws(parts[1])
        value <- trimws(paste(parts[-1], collapse = "="))
        # Use do.call to properly set environment variable
        do.call(Sys.setenv, setNames(list(value), key))
      }
    }
  }
}

# Initialize environment
load_env()

# Job metadata storage (for fields not persisted in DB)
.job_metadata_dir <- file.path("data", "jobs")

ensure_job_metadata_dir <- function() {
  dir.create(.job_metadata_dir, recursive = TRUE, showWarnings = FALSE)
  .job_metadata_dir
}

get_job_metadata_path <- function(job_id) {
  file.path(.job_metadata_dir, paste0(job_id, ".json"))
}

save_job_metadata <- function(job) {
  if (is.null(job$id)) return(invisible(FALSE))

  ensure_job_metadata_dir()
  metadata_fields <- c("algorithm", "use_sample_data", "demo_id", "demo_name")
  metadata <- job[metadata_fields]

  metadata <- metadata[!vapply(metadata, function(x) is.null(x) || length(x) == 0, logical(1))]
  if (length(metadata) == 0) return(invisible(FALSE))

  metadata$id <- job$id
  jsonlite::write_json(metadata, get_job_metadata_path(job$id),
                       auto_unbox = TRUE, pretty = TRUE)
  invisible(TRUE)
}

load_job_metadata <- function(job_id) {
  path <- get_job_metadata_path(job_id)
  if (!file.exists(path)) return(NULL)
  jsonlite::fromJSON(path, simplifyVector = TRUE)
}

# Connection pool (initialized once)
.db_pool <- NULL

# Get or create database connection pool
get_db_pool <- function() {
  if (is.null(.db_pool)) {
    message("Initializing database connection pool...")
    t_start <- Sys.time()
    .db_pool <<- dbPool(
      drv = Postgres(),
      host = Sys.getenv("PGHOST", "localhost"),
      port = as.integer(Sys.getenv("PGPORT", "5433")),
      user = Sys.getenv("PGUSER", "eric"),
      password = Sys.getenv("PGPASSWORD"),
      dbname = Sys.getenv("PGDATABASE", "comsa_dashboard"),
      minSize = 0,  # Don't pre-create connections - create on demand
      maxSize = 10
    )
    t_end <- Sys.time()
    message(sprintf("Connection pool initialized in %.3f sec", as.numeric(t_end - t_start)))
  }
  return(.db_pool)
}

# Get database connection (for backward compatibility)
get_db_connection <- function() {
  return(get_db_pool())
}

# Save a new job to database
save_job <- function(job) {
  conn <- get_db_connection()

  # Convert algorithm to JSON if it's an array
  algorithm_json <- if (length(job$algorithm) > 1) {
    job$algorithm[1]  # Store first algorithm for now
  } else {
    job$algorithm
  }

  # Prepare error and result as JSONB
  error_json <- if (is.null(job$error) || length(job$error) == 0) {
    "{}"
  } else {
    toJSON(job$error, auto_unbox = TRUE)
  }

  result_json <- if (is.null(job$result) || length(job$result) == 0) {
    "{}"
  } else {
    toJSON(job$result, auto_unbox = TRUE)
  }

  # Handle NULL values (NULL has length 0 in R)
  started_at <- if (is.null(job$started_at) || length(job$started_at) == 0) NA else job$started_at
  completed_at <- if (is.null(job$completed_at) || length(job$completed_at) == 0) NA else job$completed_at
  input_file <- if (is.null(job$input_file) || length(job$input_file) == 0) NA else job$input_file

  # Insert job
  query <- "
    INSERT INTO jobs (
      id, type, status, algorithm, age_group, country,
      calib_model_type, ensemble, created_at, started_at,
      completed_at, error, result, input_file_path
    ) VALUES (
      $1::uuid, $2, $3, $4, $5, $6, $7, $8, $9::timestamp,
      $10::timestamp, $11::timestamp, $12::jsonb, $13::jsonb, $14
    )
    ON CONFLICT (id) DO UPDATE SET
      status = EXCLUDED.status,
      started_at = EXCLUDED.started_at,
      completed_at = EXCLUDED.completed_at,
      error = EXCLUDED.error,
      result = EXCLUDED.result
  "

  dbExecute(conn, query, params = list(
    job$id,
    job$type,
    job$status,
    algorithm_json,
    job$age_group,
    job$country,
    job$calib_model_type,
    job$ensemble,
    job$created_at,
    started_at,
    completed_at,
    error_json,
    result_json,
    input_file
  ))

  save_job_metadata(job)

  invisible(TRUE)
}

# Load job from database
load_job <- function(job_id) {
  conn <- get_db_connection()

  query <- "SELECT * FROM jobs WHERE id = $1::uuid"
  result <- dbGetQuery(conn, query, params = list(job_id))

  if (nrow(result) == 0) {
    return(NULL)
  }

  job <- as.list(result[1, ])

  # Parse JSONB fields - handle error field
  if (!is.null(job$error) && length(job$error) > 0 && !is.na(job$error) &&
      is.character(job$error) && nzchar(job$error) && job$error != "{}") {
    job$error <- fromJSON(job$error)
  } else {
    # Clear empty or null error
    job$error <- NULL
  }

  # Parse JSONB fields - handle result field
  if (!is.null(job$result) && length(job$result) > 0 && !is.na(job$result) &&
      is.character(job$result) && nzchar(job$result) && job$result != "{}") {
    job$result <- fromJSON(job$result)
  }

  # Get logs
  logs <- get_job_logs(job_id)
  job$log <- logs$message

  metadata <- load_job_metadata(job_id)
  if (!is.null(metadata)) {
    if (!is.null(metadata$algorithm)) {
      job$algorithm <- metadata$algorithm
    }

    extra_fields <- c("use_sample_data", "demo_id", "demo_name")
    for (field in extra_fields) {
      if (!is.null(metadata[[field]])) {
        job[[field]] <- metadata[[field]]
      }
    }
  }

  return(job)
}

# Check if job exists
job_exists <- function(job_id) {
  conn <- get_db_connection()

  query <- "SELECT COUNT(*) as count FROM jobs WHERE id = $1::uuid"
  result <- dbGetQuery(conn, query, params = list(job_id))

  return(result$count[1] > 0)
}

# List all job IDs
list_job_ids <- function() {
  conn <- get_db_connection()

  query <- "SELECT id FROM jobs ORDER BY created_at DESC"
  result <- dbGetQuery(conn, query)

  return(result$id)
}

# Add log entry for a job
add_log <- function(job_id, message) {
  conn <- get_db_connection()

  query <- "
    INSERT INTO job_logs (job_id, message, timestamp)
    VALUES ($1::uuid, $2, NOW())
  "

  dbExecute(conn, query, params = list(job_id, message))
  invisible(TRUE)
}

# Get all logs for a job
get_job_logs <- function(job_id) {
  conn <- get_db_connection()

  query <- "
    SELECT timestamp, message
    FROM job_logs
    WHERE job_id = $1::uuid
    ORDER BY timestamp
  "

  result <- dbGetQuery(conn, query, params = list(job_id))
  return(result)
}

# Add file record for a job
add_job_file <- function(job_id, file_type, file_name, file_path, file_size = NULL) {
  conn <- get_db_connection()

  query <- "
    INSERT INTO job_files (job_id, file_type, file_name, file_path, file_size)
    VALUES ($1::uuid, $2, $3, $4, $5)
  "

  dbExecute(conn, query, params = list(
    job_id,
    file_type,
    file_name,
    file_path,
    file_size
  ))

  invisible(TRUE)
}

# Get files for a job
get_job_files <- function(job_id, file_type = NULL) {
  conn <- get_db_connection()

  if (is.null(file_type)) {
    query <- "
      SELECT file_type, file_name, file_path, file_size
      FROM job_files
      WHERE job_id = $1::uuid
      ORDER BY created_at
    "
    result <- dbGetQuery(conn, query, params = list(job_id))
  } else {
    query <- "
      SELECT file_type, file_name, file_path, file_size
      FROM job_files
      WHERE job_id = $1::uuid AND file_type = $2
      ORDER BY created_at
    "
    result <- dbGetQuery(conn, query, params = list(job_id, file_type))
  }

  return(result)
}

# Update job status
update_job_status <- function(job_id, status, error = NULL) {
  conn <- get_db_connection()

  timestamp_field <- switch(status,
    "running" = "started_at",
    "completed" = "completed_at",
    "failed" = "completed_at",
    NULL
  )

  if (is.null(timestamp_field)) {
    query <- "UPDATE jobs SET status = $1 WHERE id = $2::uuid"
    dbExecute(conn, query, params = list(status, job_id))
  } else {
    query <- sprintf("
      UPDATE jobs
      SET status = $1, %s = NOW()
      WHERE id = $2::uuid
    ", timestamp_field)
    dbExecute(conn, query, params = list(status, job_id))
  }

  # Update error field: set error message if provided, clear if completed successfully
  if (!is.null(error)) {
    error_json <- toJSON(list(message = error), auto_unbox = TRUE)
    query <- "UPDATE jobs SET error = $1::jsonb WHERE id = $2::uuid"
    dbExecute(conn, query, params = list(error_json, job_id))
  } else if (status == "completed") {
    # Clear error field for successful completion
    query <- "UPDATE jobs SET error = NULL WHERE id = $1::uuid"
    dbExecute(conn, query, params = list(job_id))
  }

  invisible(TRUE)
}

# Update job result
update_job_result <- function(job_id, result) {
  conn <- get_db_connection()

  result_json <- toJSON(result, auto_unbox = TRUE)
  query <- "UPDATE jobs SET result = $1::jsonb WHERE id = $2::uuid"
  dbExecute(conn, query, params = list(result_json, job_id))

  invisible(TRUE)
}
