# VA Calibration Platform - Configuration
# Stan options, async setup, library imports

library(openVA)
library(vacalibration)
library(future)
library(jsonlite)

# Configure Stan for InSilicoVA - prevent compiled model cache issues
# Disable auto_write to force fresh compilation each time
options(mc.cores = 1)  # Use single core to avoid compilation race conditions
if (requireNamespace("rstan", quietly = TRUE)) {
  rstan::rstan_options(auto_write = FALSE)

  # Clear Stan model cache to prevent cross-platform issues
  cache_dir <- file.path(Sys.getenv("HOME"), ".cache", "R", "rstan")
  if (dir.exists(cache_dir)) {
    message("Clearing Stan model cache: ", cache_dir)
    unlink(file.path(cache_dir, "*"), recursive = TRUE)
  }
}

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
