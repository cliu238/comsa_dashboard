# Utility Functions for Job Processing
# Logging, data loading, and cause mapping helpers

# Capture stdout/stderr from package functions and log them in real-time
# Uses sink() to a temp file instead of capture.output() for better streaming
run_with_capture <- function(job_id, expr) {
  # Create temp file to capture stdout (file writes are unbuffered/real-time)
  tmp_file <- tempfile(pattern = paste0("job_", job_id, "_"), fileext = ".log")
  file_con <- file(tmp_file, open = "wt")

  # Track what we've already logged
  last_logged_line <- 0

  # Function to flush new lines from temp file to database
  flush_new_output <- function() {
    # Temporarily unsink to avoid recursion
    sink(type = "output")

    tryCatch({
      if (file.exists(tmp_file)) {
        lines <- readLines(tmp_file, warn = FALSE)
        if (length(lines) > last_logged_line) {
          new_lines <- lines[(last_logged_line + 1):length(lines)]
          for (line in new_lines) {
            if (nzchar(trimws(line))) {
              add_log(job_id, line)
            }
          }
          last_logged_line <<- length(lines)
        }
      }
    }, error = function(e) {
      # Ignore read errors
    })

    # Re-sink
    sink(file_con, type = "output")
  }

  # Start sinking stdout to temp file
  sink(file_con, type = "output")

  on.exit({
    # Unsink stdout
    sink(type = "output")
    close(file_con)

    # Final flush of any remaining output
    tryCatch({
      if (file.exists(tmp_file)) {
        lines <- readLines(tmp_file, warn = FALSE)
        if (length(lines) > last_logged_line) {
          new_lines <- lines[(last_logged_line + 1):length(lines)]
          for (line in new_lines) {
            if (nzchar(trimws(line))) {
              add_log(job_id, line)
            }
          }
        }
        # Clean up temp file
        unlink(tmp_file)
      }
    }, error = function(e) {
      # Ignore cleanup errors
    })
  }, add = TRUE)

  # Run expression with message/warning handlers
  result <- withCallingHandlers(
    expr,
    message = function(m) {
      # Flush any pending stdout before logging message
      flush_new_output()
      add_log(job_id, trimws(conditionMessage(m)))
      invokeRestart("muffleMessage")
    },
    warning = function(w) {
      # Flush any pending stdout before logging warning
      flush_new_output()
      add_log(job_id, paste("[WARN]", conditionMessage(w)))
      invokeRestart("muffleWarning")
    }
  )

  result
}

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
