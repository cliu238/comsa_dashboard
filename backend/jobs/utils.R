# Utility Functions for Job Processing
# Logging, data loading, and cause mapping helpers

# Capture stdout/stderr from package functions and log them in real-time.
# Sinks stdout to a temp file. A background Rscript process tails the file
# every `flush_interval` seconds and inserts new lines into the database.
# Messages/warnings are logged directly via add_log().
run_with_capture <- function(job_id, expr, flush_interval = 2) {
  tmp_file <- tempfile(pattern = paste0("job_", job_id, "_"), fileext = ".log")
  file_con <- file(tmp_file, open = "wt")

  # Launch a separate Rscript process that tails tmp_file -> DB
  flusher_script <- tempfile(pattern = "flusher_", fileext = ".R")
  writeLines(sprintf(
    'log_file <- "%s"
job_id  <- "%s"
interval <- %d
setwd("%s")
source("db/connection.R")
last_line <- 0L
while (file.exists(log_file)) {
  Sys.sleep(interval)
  tryCatch({
    lines <- readLines(log_file, warn = FALSE)
    if (length(lines) > last_line) {
      new_lines <- lines[(last_line + 1L):length(lines)]
      for (line in new_lines) {
        if (nzchar(trimws(line))) add_log(job_id, line)
      }
      last_line <- length(lines)
    }
  }, error = function(e) NULL)
}',
    gsub("\\\\", "/", tmp_file), job_id, flush_interval, gsub("\\\\", "/", getwd())
  ), flusher_script)

  rscript <- file.path(R.home("bin"), "Rscript")
  flusher_ok <- tryCatch({
    system2(rscript, args = flusher_script, wait = FALSE)
    TRUE
  }, error = function(e) FALSE)

  # Start sinking stdout to temp file
  sink(file_con, type = "output")

  on.exit({
    sink(type = "output")
    tryCatch(flush(file_con), error = function(e) NULL)
    close(file_con)

    if (flusher_ok) {
      # Give the flusher time for one last pass before deleting the file
      Sys.sleep(flush_interval + 1)
    }

    # Final sweep: log any lines the flusher may have missed
    tryCatch({
      if (file.exists(tmp_file)) {
        all_lines <- readLines(tmp_file, warn = FALSE)
        # Query DB for lines already logged by flusher to avoid duplicates
        existing <- tryCatch(get_job_logs(job_id), error = function(e) data.frame(message = character()))
        existing_set <- existing$message
        for (line in all_lines) {
          line_trimmed <- trimws(line)
          if (nzchar(line_trimmed) && !(line_trimmed %in% existing_set)) {
            add_log(job_id, line_trimmed)
          }
        }
        unlink(tmp_file)
      }
    }, error = function(e) NULL)
    unlink(flusher_script)
  }, add = TRUE)

  # Run expression; intercept messages and warnings directly
  result <- withCallingHandlers(
    expr,
    message = function(m) {
      add_log(job_id, trimws(conditionMessage(m)))
      invokeRestart("muffleMessage")
    },
    warning = function(w) {
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
# algorithm: "interva", "insilicova", or "eava" (lowercase)
# age_group: "neonate" or "child"
load_vacalibration_sample <- function(algorithm = "insilicova", age_group = "neonate", job_id = NULL) {
  # Try algorithm-specific file first
  algo_lower <- tolower(algorithm)
  sample_file <- file.path("data", "sample_data", sprintf("sample_vacalibration_%s_%s.rds", algo_lower, age_group))

  if (file.exists(sample_file)) {
    if (!is.null(job_id)) {
      add_log(job_id, sprintf("Using bundled %s calibration sample data", toupper(algorithm)))
    }
    return(readRDS(sample_file))
  }

  # Fallback to generic file (legacy)
  legacy_file <- file.path("data", "sample_data", "sample_vacalibration_broad.rds")
  if (file.exists(legacy_file)) {
    if (!is.null(job_id)) {
      add_log(job_id, "Using legacy bundled calibration sample data (InSilicoVA)")
    }
    return(readRDS(legacy_file))
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

# Canonical broad cause names by age group
get_broad_causes <- function(age_group) {
  if (tolower(age_group) == "neonate") {
    c("congenital_malformation", "pneumonia", "sepsis_meningitis_inf", "ipre", "other", "prematurity")
  } else if (tolower(age_group) == "child") {
    c("malaria", "pneumonia", "diarrhea", "severe_malnutrition", "hiv", "injury", "other", "other_infections", "nn_causes")
  } else {
    stop(paste("Unsupported age_group:", age_group))
  }
}

# Check if causes are already in broad format (all unique values are broad cause names)
is_broad_format <- function(causes, age_group) {
  broad <- get_broad_causes(age_group)
  unique_causes <- unique(tolower(trimws(causes)))
  unique_causes <- unique_causes[!is.na(unique_causes) & nzchar(unique_causes)]
  all(unique_causes %in% broad)
}

# Build one-hot indicator matrix directly from broad-format causes, skipping cause_map()
build_broad_matrix <- function(df, age_group) {
  broad <- get_broad_causes(age_group)
  causes <- tolower(trimws(df$cause))

  mat <- matrix(0L, nrow = nrow(df), ncol = length(broad), dimnames = list(df$ID, broad))
  for (i in seq_len(nrow(df))) {
    idx <- match(causes[i], broad)
    if (!is.na(idx)) mat[i, idx] <- 1L
  }
  mat
}

# Build a mapping from broad cause names to the user's original cause names.
# For each broad cause column, find the most frequent original cause that mapped to it.
# df: data.frame with ID and cause columns (original user data)
# broad_matrix: one-hot matrix from safe_cause_map (rows=records, cols=broad causes)
build_cause_display_map <- function(df, broad_matrix) {
  result <- list()
  for (broad_cause in colnames(broad_matrix)) {
    # Find which records mapped to this broad cause
    row_indices <- which(broad_matrix[, broad_cause] == 1)
    if (length(row_indices) > 0) {
      # Get original cause names for these records
      original_causes <- df$cause[match(rownames(broad_matrix)[row_indices], df$ID)]
      # Use the most frequent original cause name
      freq <- table(original_causes)
      result[[broad_cause]] <- names(freq)[which.max(freq)]
    }
  }
  result
}

# Build cause ordering based on first appearance in user's data.
# Returns broad cause names ordered by when they first appear in the CSV.
build_cause_order <- function(df, broad_matrix) {
  order <- character()
  for (i in seq_len(nrow(broad_matrix))) {
    broad_cause <- colnames(broad_matrix)[which(broad_matrix[i, ] == 1)]
    if (length(broad_cause) == 1 && !(broad_cause %in% order)) {
      order <- c(order, broad_cause)
    }
  }
  # Append any broad causes that weren't in the data (from dummy rows, etc.)
  remaining <- setdiff(colnames(broad_matrix), order)
  c(order, remaining)
}

# Normalize misclassification matrix so each row sums to 1.
# Converts Dirichlet scale parameters to proper conditional probabilities.
# Input: 2D matrix [champs_cause, va_cause] or 3D array [algorithm, champs_cause, va_cause]
# Returns: same shape with each row divided by its row sum (NULL if input is NULL)
normalize_mmat <- function(mmat) {
  if (is.null(mmat)) return(NULL)

  if (length(dim(mmat)) == 2) {
    rs <- rowSums(mmat)
    rs[rs == 0] <- 1  # avoid division by zero
    mmat <- mmat / rs
  } else if (length(dim(mmat)) == 3) {
    for (k in seq_len(dim(mmat)[1])) {
      slice <- mmat[k, , ]
      rs <- rowSums(slice)
      rs[rs == 0] <- 1
      mmat[k, , ] <- slice / rs
    }
  }
  mmat
}
