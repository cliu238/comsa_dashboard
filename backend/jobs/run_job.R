#!/usr/bin/env Rscript

# Background runner - processes a single job by ID
args <- commandArgs(trailingOnly = TRUE)

if (length(args) == 0) {
  stop("Job ID argument is required", call. = FALSE)
}

job_id <- args[[1]]

# Ensure working directory is the backend root regardless of invocation path
arg_full <- commandArgs(trailingOnly = FALSE)
script_flag <- "--file="
script_arg <- arg_full[grepl(script_flag, arg_full)]

if (length(script_arg) == 1) {
  script_path <- normalizePath(sub(script_flag, "", script_arg))
  backend_root <- normalizePath(file.path(dirname(script_path), ".."))
  setwd(backend_root)
}

# Load processor functions and run the job directly
source("jobs/processor.R")
process_job(job_id)
