# Test Database Integration
# This script tests the database connection and job management functions

library(uuid)

# Change to backend directory
setwd("/Users/ericliu/projects5/comsa_dashboard/backend")

# Source the database connection helper
source("db/connection.R")

cat("=== Testing Database Integration ===\n\n")

# Test 1: Database connection
cat("Test 1: Testing database connection...\n")
tryCatch({
  conn <- get_db_connection()
  cat("✓ Database connection successful\n")

  # Test query
  result <- dbGetQuery(conn, "SELECT version()")
  cat("✓ PostgreSQL version:", result$version[1], "\n")

  dbDisconnect(conn)
}, error = function(e) {
  cat("✗ Database connection failed:", e$message, "\n")
  stop(e)
})

cat("\n")

# Test 2: Create a test job
cat("Test 2: Creating a test job...\n")
test_job_id <- UUIDgenerate()
test_job <- list(
  id = test_job_id,
  type = "pipeline",
  status = "pending",
  algorithm = "InterVA",
  age_group = "neonate",
  country = "Mozambique",
  calib_model_type = "Mmatprior",
  ensemble = FALSE,
  created_at = format(Sys.time()),
  started_at = NULL,
  completed_at = NULL,
  error = NULL,
  result = NULL,
  input_file = NULL
)

tryCatch({
  save_job(test_job)
  cat("✓ Job saved successfully with ID:", test_job_id, "\n")
}, error = function(e) {
  cat("✗ Failed to save job:", e$message, "\n")
  stop(e)
})

cat("\n")

# Test 3: Load the job back
cat("Test 3: Loading the job from database...\n")
tryCatch({
  loaded_job <- load_job(test_job_id)
  if (is.null(loaded_job)) {
    stop("Job not found")
  }
  cat("✓ Job loaded successfully\n")
  cat("  - Type:", loaded_job$type, "\n")
  cat("  - Status:", loaded_job$status, "\n")
  cat("  - Algorithm:", loaded_job$algorithm, "\n")
}, error = function(e) {
  cat("✗ Failed to load job:", e$message, "\n")
  stop(e)
})

cat("\n")

# Test 4: Add log entries
cat("Test 4: Adding log entries...\n")
tryCatch({
  add_log(test_job_id, "Test log entry 1")
  add_log(test_job_id, "Test log entry 2")
  add_log(test_job_id, "Test log entry 3")
  cat("✓ Log entries added successfully\n")

  # Retrieve logs
  logs <- get_job_logs(test_job_id)
  cat("✓ Retrieved", nrow(logs), "log entries\n")
  cat("  First log:", logs$message[1], "\n")
}, error = function(e) {
  cat("✗ Failed to add logs:", e$message, "\n")
  stop(e)
})

cat("\n")

# Test 5: Add file records
cat("Test 5: Adding file records...\n")
tryCatch({
  add_job_file(test_job_id, "input", "input.csv", "data/uploads/test/input.csv", 1024)
  add_job_file(test_job_id, "output", "causes.csv", "data/outputs/test/causes.csv", 2048)
  cat("✓ File records added successfully\n")

  # Retrieve files
  files <- get_job_files(test_job_id)
  cat("✓ Retrieved", nrow(files), "file records\n")
  cat("  Input files:", nrow(get_job_files(test_job_id, "input")), "\n")
  cat("  Output files:", nrow(get_job_files(test_job_id, "output")), "\n")
}, error = function(e) {
  cat("✗ Failed to add file records:", e$message, "\n")
  stop(e)
})

cat("\n")

# Test 6: Update job status
cat("Test 6: Updating job status...\n")
tryCatch({
  update_job_status(test_job_id, "running")
  job <- load_job(test_job_id)
  cat("✓ Status updated to:", job$status, "\n")

  update_job_status(test_job_id, "completed")
  job <- load_job(test_job_id)
  cat("✓ Status updated to:", job$status, "\n")
}, error = function(e) {
  cat("✗ Failed to update status:", e$message, "\n")
  stop(e)
})

cat("\n")

# Test 7: Update job result
cat("Test 7: Updating job result...\n")
tryCatch({
  test_result <- list(
    n_records = 10,
    algorithm = "InterVA",
    csmf = list(
      "Prematurity" = 0.5,
      "Birth asphyxia" = 0.3,
      "Other" = 0.2
    )
  )
  update_job_result(test_job_id, test_result)
  cat("✓ Job result updated successfully\n")

  # Verify result
  job <- load_job(test_job_id)
  cat("✓ Result contains", length(job$result), "fields\n")
}, error = function(e) {
  cat("✗ Failed to update result:", e$message, "\n")
  stop(e)
})

cat("\n")

# Test 8: List all jobs
cat("Test 8: Listing all jobs...\n")
tryCatch({
  job_ids <- list_job_ids()
  cat("✓ Found", length(job_ids), "total jobs in database\n")
  cat("✓ Test job ID is in list:", test_job_id %in% job_ids, "\n")
}, error = function(e) {
  cat("✗ Failed to list jobs:", e$message, "\n")
  stop(e)
})

cat("\n")

# Test 9: Clean up - delete test job
cat("Test 9: Cleaning up test job...\n")
tryCatch({
  conn <- get_db_connection()
  dbExecute(conn, "DELETE FROM jobs WHERE id = $1::uuid", params = list(test_job_id))
  dbDisconnect(conn)
  cat("✓ Test job deleted successfully\n")
}, error = function(e) {
  cat("✗ Failed to delete test job:", e$message, "\n")
})

cat("\n=== All tests completed successfully! ===\n")
