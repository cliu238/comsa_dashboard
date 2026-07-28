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

# Cause labels for deaths with no determined cause. vacalibration::cause_map()
# drops "Unspecified" by design (subset(df, cause != "Unspecified")) because
# these deaths cannot be calibrated, so calibrating the package's own datasets
# (e.g. comsamoz_CCVAoutput, whose EAVA neonate table has 250 "Unspecified"
# records) excludes them from the denominator. Matched case-insensitively.
UNDETERMINED_CAUSES <- c("unspecified")

# Drop records whose cause is an undetermined label (see UNDETERMINED_CAUSES),
# reproducing what vacalibration::cause_map() does internally. Without this,
# assert_all_causes_mapped() (issue #92) would flag these intended drops as an
# error and reject the whole dataset. The exclusion is logged loudly (not a
# silent drop), so it still honors the no-silent-drop rule from issues #77/#89.
drop_undetermined_causes <- function(df, job_id = NULL) {
  trimmed <- trimws(df$cause)
  is_undet <- tolower(trimmed) %in% UNDETERMINED_CAUSES
  n <- sum(is_undet)
  if (n > 0 && !is.null(job_id)) {
    add_log(job_id, sprintf(
      "Excluding %d record(s) with an undetermined cause (%s) from calibration, consistent with the vacalibration methodology (these deaths have no assigned cause and cannot be calibrated).",
      n, paste(sort(unique(trimmed[is_undet])), collapse = ", ")))
  }
  df[!is_undet, , drop = FALSE]
}

# Classify a single cause into its broad category by probing the SAME mapping
# units the job path uses. Returns the broad cause name, or NA if the cause maps
# to nothing (unrecognized). cause_map() throws on unrecognized causes, so this
# probes one cause at a time and treats a throw / all-zero row as unrecognized.
classify_cause <- function(cause, age_group) {
  df <- data.frame(ID = "__probe__", cause = cause, stringsAsFactors = FALSE)
  m <- tryCatch(
    if (is_broad_format(df$cause, age_group)) build_broad_matrix(df, age_group)
    else safe_cause_map(fix_causes_for_vacalibration(df), age_group),
    error = function(e) NULL)
  if (is.null(m) || !("__probe__" %in% rownames(m))) return(NA_character_)
  row <- m["__probe__", ]
  if (sum(row) == 0) return(NA_character_)
  colnames(m)[which(row == 1)[1]]
}

# Build a pre-submit mapping report for uploaded data, WITHOUT running MCMC.
# Mirrors the job path: undetermined causes are excluded (matching cause_map),
# each remaining unique cause is classified, and unrecognized causes are reported
# (never silently dropped). See
# docs/superpowers/specs/2026-07-22-cause-mapping-preview-design.md
preview_cause_mapping <- function(input_data, age_group) {
  if ("cause1" %in% names(input_data) && !"cause" %in% names(input_data)) {
    names(input_data)[names(input_data) == "cause1"] <- "cause"
  }
  if (!all(c("ID", "cause") %in% names(input_data))) {
    stop("Input must have 'ID' and 'cause' columns (or 'ID' and 'cause1').", call. = FALSE)
  }
  input_data$ID <- as.character(input_data$ID)
  total_records <- nrow(input_data)

  # Normalize cause labels for reporting: trim whitespace so "Unspecified" and
  # "Unspecified " aren't split across buckets, and give NA/blank causes a
  # visible label so they are reported as unrecognized instead of silently
  # vanishing (table() drops NA by default). This keeps
  # total_records == excluded + calibrated + unrecognized.
  cause_disp <- trimws(input_data$cause)
  cause_disp[is.na(cause_disp) | cause_disp == ""] <- "(missing)"

  # Undetermined exclusions (dropped by vacalibration::cause_map by design)
  undet_mask <- tolower(cause_disp) %in% UNDETERMINED_CAUSES
  undet_tab <- table(cause_disp[undet_mask])
  excluded_undetermined <- lapply(names(undet_tab), function(cn)
    list(cause = cn, count = as.integer(undet_tab[[cn]])))

  counts <- table(cause_disp[!undet_mask])
  expected <- get_broad_causes(age_group)

  mapping <- list()
  unrecognized <- list()
  denom <- 0L
  for (cn in names(counts)) {
    broad <- classify_cause(cn, age_group)
    n <- as.integer(counts[[cn]])
    if (is.na(broad)) {
      s <- suggest_closest(normalize_cause(cn), expected)
      unrecognized[[length(unrecognized) + 1L]] <-
        list(cause = cn, count = n, suggestion = if (is.na(s)) NULL else s)
    } else {
      mapping[[length(mapping) + 1L]] <-
        list(input_cause = cn, broad_cause = broad, count = n)
      denom <- denom + n
    }
  }

  list(
    total_records = total_records,
    calibrated_denominator = denom,
    excluded_undetermined = excluded_undetermined,
    unrecognized = unrecognized,
    mapping = mapping,
    has_errors = length(unrecognized) > 0
  )
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
    # Every dummy MUST be a real child specific-cause name from cause_map()'s
    # internal lists. An unrecognized dummy renames to NA, model.matrix() drops
    # that column, and cause_map() crashes with "non-conformable arguments" --
    # the opposite of what this workaround is for. "diarrhoeal diseases" (British
    # spelling) and "stroke" replace the previously-invalid "diarrheal diseases"
    # and "other" (the child map, unlike the neonate map, has no literal "other").
    dummy_causes <- c(
      "malaria",                  # → malaria
      "pneumonia",                # → pneumonia
      "diarrhoeal diseases",      # → diarrhea
      "severe malnutrition",      # → severe_malnutrition
      "hiv/aids related death",   # → hiv
      "road traffic accident",    # → injury
      "stroke",                   # → other
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

  # Call cause_map. A dummy (or user cause) that is NOT a recognized specific-cause
  # name renames to NA inside cause_map, model.matrix() drops that column, and
  # cause_map() throws a cryptic "non-conformable arguments". Translate ONLY that
  # specific failure into a developer-facing diagnostic; propagate any other error
  # unchanged so genuine failures aren't misattributed to the dummies.
  result <- tryCatch(
    vacalibration::cause_map(df = df_with_dummies, age_group = age_group),
    error = function(e) {
      if (grepl("non-conformable", conditionMessage(e), fixed = TRUE)) {
        stop(sprintf(
          "safe_cause_map internal error: cause_map() failed for age_group='%s' (%s). This usually means a cause is not a recognized specific-cause name for this age group. Dummies: %s",
          age_group, conditionMessage(e), paste(dummy_causes, collapse = ", ")),
          call. = FALSE)
      }
      stop(e)
    }
  )

  # Remove dummy rows from result
  dummy_ids <- dummy_df$ID
  result <- result[!rownames(result) %in% dummy_ids, , drop = FALSE]

  # Post-condition: the dummies exist precisely so every broad category is
  # present. If one is missing, a dummy silently failed to map (e.g. cause_map
  # succeeded-but-dropped rather than throwing) -- fail loudly here rather than
  # letting a short/misshaped matrix reach vacalibration().
  expected <- get_broad_causes(age_group)
  missing <- setdiff(expected, colnames(result))
  if (length(missing) > 0) {
    stop(sprintf(
      "safe_cause_map internal error: broad categories missing after mapping for age_group='%s': %s. A dummy cause likely failed to map to its intended category.",
      age_group, paste(missing, collapse = ", ")), call. = FALSE)
  }

  return(result)
}

# Prepare input data for EAVA algorithm.
# EAVA's codEAVA() references WHO2016 columns directly (e.g. data$i183b) and crashes
# if any are missing. This pre-fills missing columns with "." (WHO standard missing value)
# and adds required 'age' and 'fb_day0' columns if absent.
prepare_eava_input <- function(input_data, age_group) {
  age_group <- tolower(trimws(age_group))
  # Add age column (days) if missing
  if (!"age" %in% names(input_data)) {
    input_data$age <- if (age_group == "neonate") rep(14, nrow(input_data)) else rep(180, nrow(input_data))
  }
  # Add fb_day0 if missing
  if (!"fb_day0" %in% names(input_data)) {
    input_data$fb_day0 <- "n"
  }
  # Extract all WHO columns EAVA::codEAVA references from its source
  src <- capture.output(print(EAVA::codEAVA))
  matches <- regmatches(src, gregexpr("data\\$i[0-9]+[a-z]?", src))
  eava_cols <- unique(sub("data\\$", "", unlist(matches)))
  # Pre-fill missing columns with "." (WHO2016 "not answered")
  missing <- setdiff(eava_cols, names(input_data))
  for (col in missing) input_data[[col]] <- "."
  input_data
}

# Extract top cause-of-death from openVA result.
# openVA's getTopCOD() doesn't support the eava class, so we handle it directly.
# Returns data.frame with ID and cause1 columns (consistent format for all algorithms).
extract_top_cod <- function(result) {
  if (inherits(result, "eava")) {
    data.frame(ID = result$ID, cause1 = result$cause, stringsAsFactors = FALSE)
  } else {
    getTopCOD(result)
  }
}

# ---- Request parameter resolution -------------------------------------------
#
# Every scalar the job endpoints take MUST arrive in the QUERY STRING. A multipart
# form field does not survive plumber: a text part carries no Content-Type and no
# filename, so parser_picker() falls through to parser_text(parseQS), and parseQS
# reads the raw part value as a query string -- a bare "child" contains no "=" and
# parses to an EMPTY LIST. That is how issue #105 arose: req$args$age_group arrived
# as list(), the endpoint could not tell it apart from an absent parameter, and a
# silent "neonate" default scored child uploads against the NEONATE cause list.
# Every child-only cause (hiv, other_infections, severe_malnutrition) was then
# reported unrecognized, which disabled the Calibrate button.
#
# So a parameter that determines WHAT SCIENCE RAN is never guessed (issues
# #77/#89): guessing converts a lost parameter into a plausible-but-wrong result.
# Genuine tuning knobs keep a documented default but still reject invalid values,
# because as.integer("abc") and as.logical("yes") both yield NA silently.

PARAM_TRANSPORT_HINT <- "Send it as a query-string parameter, e.g. /jobs?age_group=child (a multipart form field is discarded by plumber's form parser)."

VALID_JOB_TYPES <- c("openva", "vacalibration", "pipeline")
VALID_ALGORITHMS <- c("InterVA", "InSilicoVA", "EAVA")
VALID_CALIB_MODEL_TYPES <- c("Mmatprior", "Mmatfixed")

# The strata of the CHAMPS misclassification matrix, i.e. the only countries
# calibration can be performed against ("other" is the pooled all-country
# stratum). Verified against names(Mmat_champs$neonate$eava$postmean) in
# vacalibration, and re-checked by a drift guard in
# tests/test_vacalibration_backend.R section 2g. Calibrating against the wrong
# country silently uses the wrong misclassification matrix, which is why an
# absent country is rejected rather than defaulted to Mozambique.
CALIBRATION_COUNTRIES <- c("Bangladesh", "Ethiopia", "Kenya", "Mali",
                           "Mozambique", "Sierra Leone", "South Africa", "other")

# Reduce a request parameter to a single trimmed string, or "" when it is absent,
# empty, or the empty list plumber produces for a multipart text field.
# Conflicting repeated values are an error rather than a coin flip -- quietly
# taking the first would be another silent guess.
param_scalar <- function(value, name) {
  v <- suppressWarnings(as.character(unlist(value, use.names = FALSE)))
  v <- trimws(v[!is.na(v)])
  v <- v[nzchar(v)]
  if (length(v) == 0) return("")
  if (length(unique(v)) > 1) {
    stop(sprintf("Received %d conflicting values for '%s' (%s). Send it exactly once.",
                 length(unique(v)), name, paste(unique(v), collapse = ", ")), call. = FALSE)
  }
  v[1]
}

# Required parameter constrained to a fixed set. Returns the canonical spelling
# from `valid`, so case variants normalize. Never substitutes a default.
require_enum <- function(value, name, valid) {
  v <- param_scalar(value, name)
  if (!nzchar(v)) {
    stop(sprintf("Missing required parameter '%s'. %s Valid values: %s.",
                 name, PARAM_TRANSPORT_HINT, paste(valid, collapse = ", ")), call. = FALSE)
  }
  hit <- valid[tolower(valid) == tolower(v)]
  if (length(hit) == 0) {
    stop(sprintf("Invalid '%s' value '%s'. Must be one of: %s.",
                 name, v, paste(valid, collapse = ", ")), call. = FALSE)
  }
  hit[1]
}

# Optional parameter with a documented default, still validated when supplied.
optional_enum <- function(value, name, valid, default) {
  v <- param_scalar(value, name)
  if (!nzchar(v)) return(default)
  require_enum(v, name, valid)
}

# Optional positive-integer parameter with a documented default. as.integer("abc")
# is NA with only a warning, which used to reach the job record unnoticed.
optional_count <- function(value, name, default) {
  v <- param_scalar(value, name)
  if (!nzchar(v)) return(default)
  n <- suppressWarnings(as.numeric(v))
  # Values past .Machine$integer.max make as.integer() overflow to NA (warning
  # only) -- the exact NA leak this helper exists to prevent.
  if (is.na(n) || n < 1 || n != trunc(n) || n > .Machine$integer.max) {
    stop(sprintf("Invalid '%s' value '%s'. Must be a positive whole number.", name, v),
         call. = FALSE)
  }
  as.integer(n)
}

# Optional boolean with a documented default. as.logical() turns anything it does
# not recognize into NA, and a downstream `if (NA && ...)` is a hard error.
optional_flag <- function(value, name, default) {
  v <- tolower(param_scalar(value, name))
  if (!nzchar(v)) return(default)
  if (v %in% c("true", "t", "yes", "1")) return(TRUE)
  if (v %in% c("false", "f", "no", "0")) return(FALSE)
  stop(sprintf("Invalid '%s' value '%s'. Must be true or false.", name, v), call. = FALSE)
}

# Required algorithm selection. Accepts a single name or a JSON array (the shape
# the frontend sends for an ensemble). Defaulting this to "InterVA" would silently
# run a different algorithm than the user picked.
require_algorithms <- function(value) {
  missing_msg <- sprintf("Missing required parameter 'algorithm'. %s Valid values: %s.",
                         PARAM_TRANSPORT_HINT, paste(VALID_ALGORITHMS, collapse = ", "))
  raw <- suppressWarnings(as.character(unlist(value, use.names = FALSE)))
  raw <- trimws(raw[!is.na(raw)])
  raw <- raw[nzchar(raw)]
  if (length(raw) == 0) stop(missing_msg, call. = FALSE)

  if (length(raw) == 1 && grepl("^\\[", raw)) {
    raw <- tryCatch(as.character(jsonlite::fromJSON(raw)),
                    error = function(e)
                      stop(sprintf("Could not parse 'algorithm' as a JSON array: %s", raw),
                           call. = FALSE))
    raw <- trimws(raw[!is.na(raw)])
    raw <- raw[nzchar(raw)]
    if (length(raw) == 0) stop(missing_msg, call. = FALSE)
  }

  canon <- VALID_ALGORITHMS[match(tolower(raw), tolower(VALID_ALGORITHMS))]
  bad <- raw[is.na(canon)]
  if (length(bad) > 0) {
    stop(sprintf("Invalid algorithm(s): %s. Must be one of: %s.",
                 paste(unique(bad), collapse = ", "),
                 paste(VALID_ALGORITHMS, collapse = ", ")), call. = FALSE)
  }
  unique(canon)
}

# Resolve the age_group request parameter, or fail loudly (issue #105).
resolve_age_group <- function(age_group) {
  require_enum(age_group, "age_group", c("neonate", "child"))
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

# Normalize a cause name for cross-format matching: lowercase, trim,
# collapse spaces/underscores/hyphens to a single underscore.
# Lets "Congenital Malformation", "congenital-malformation", and
# "congenital_malformation" all match the canonical broad cause name.
normalize_cause <- function(x) gsub("[ _-]+", "_", tolower(trimws(x)))

# Suggest the closest broad cause name (Levenshtein distance) for an
# unrecognized cause. Returns NA_character_ if no candidate is close enough.
suggest_closest <- function(unknown_cause, candidates) {
  if (length(candidates) == 0) return(NA_character_)
  dists <- as.vector(adist(unknown_cause, candidates, ignore.case = TRUE))
  threshold <- max(3, nchar(unknown_cause) %/% 2)
  if (min(dists) <= threshold) candidates[which.min(dists)] else NA_character_
}

# Validate user-supplied causes against the expected broad-cause schema for
# age_group. On failure, throws a structured error containing:
#   - per-cause record counts for the offenders
#   - age_group switch hint when causes look like the OTHER age group
#   - spelling suggestions for truly unknown causes
#   - the full expected broad-cause list for reference
# Returns invisible(TRUE) when every input cause maps to a valid broad name.
validate_causes <- function(causes, age_group) {
  if (length(causes) == 0) stop("No causes provided in input data.", call. = FALSE)

  expected <- get_broad_causes(age_group)
  expected_norm <- normalize_cause(expected)
  causes_norm <- normalize_cause(causes)
  user_unique <- unique(causes_norm)
  user_unique <- user_unique[!is.na(user_unique) & nzchar(user_unique)]
  unknown <- user_unique[!user_unique %in% expected_norm]

  if (length(unknown) == 0) return(invisible(TRUE))

  all_counts <- table(causes_norm)

  other_age <- if (tolower(age_group) == "neonate") "child" else "neonate"
  other_age_broad_norm <- normalize_cause(get_broad_causes(other_age))
  wrong_age <- unknown[unknown %in% other_age_broad_norm]
  truly_unknown <- setdiff(unknown, wrong_age)

  msg <- sprintf("Cause validation failed for age_group='%s'.", age_group)

  if (length(wrong_age) > 0) {
    lines <- vapply(wrong_age, function(cn) {
      sprintf("  - %s: %d records", cn, as.integer(all_counts[cn]))
    }, character(1))
    msg <- paste(msg, "",
      sprintf("Found %d cause name(s) that belong to the '%s' age group:",
              length(wrong_age), other_age),
      paste(lines, collapse = "\n"),
      sprintf("  -> If your data is for %s, change age_group to '%s'.",
              if (other_age == "child") "children" else "neonates", other_age),
      sep = "\n")
  }

  if (length(truly_unknown) > 0) {
    lines <- vapply(truly_unknown, function(cn) {
      s <- suggest_closest(cn, expected)
      if (is.na(s)) {
        sprintf("  - %s: %d records (no close match; consider renaming to 'other')",
                cn, as.integer(all_counts[cn]))
      } else {
        sprintf("  - %s: %d records (did you mean '%s'?)",
                cn, as.integer(all_counts[cn]), s)
      }
    }, character(1))
    msg <- paste(msg, "",
      sprintf("Found %d unrecognized cause name(s):", length(truly_unknown)),
      paste(lines, collapse = "\n"),
      sep = "\n")
  }

  msg <- paste(msg, "",
    sprintf("Expected broad causes for '%s':", age_group),
    paste0("  ", paste(expected, collapse = ", ")),
    sep = "\n")

  stop(msg, call. = FALSE)
}

# Fail loudly if any input records have a cause that did NOT map to a supported
# broad category. cause_map() silently drops such rows (its output has fewer
# rows than the input); build_broad_matrix() leaves them as all-zero rows.
# Either way a record is "dropped" when its ID is absent from the mapped rows
# that sum to > 0. Reports the offending cause labels + counts and the supported
# broad causes so the user can relabel/remove them and re-run — instead of
# silently shrinking the denominator and inflating the remaining CSMFs.
# (issue #92)
assert_all_causes_mapped <- function(input_data, va_broad, age_group) {
  ids <- as.character(input_data$ID)

  # Duplicate record IDs are malformed input: cause_map()'s internal
  # dcast(ID ~ cause) collapses rows sharing an ID into one, which either
  # undercounts (silent denominator shrink -> distorted CSMFs) or produces a
  # multi-cause row that crashes vacalibration with an empty error. The set
  # comparison below is blind to duplicate-count loss, so reject duplicates up
  # front. We cannot tell an accidental double-entry (merge would be correct)
  # from two distinct deaths sharing an ID (merge loses one), so fail loudly and
  # let the user fix the IDs — same principle as the unrecognized-cause guard.
  dup_ids <- unique(ids[duplicated(ids)])
  if (length(dup_ids) > 0) {
    shown <- paste(utils::head(dup_ids, 5), collapse = ", ")
    more <- if (length(dup_ids) > 5) sprintf(" (and %d more)", length(dup_ids) - 5) else ""
    stop(sprintf(
      "Input contains %d duplicate record ID(s): %s%s. Each record must have a unique ID — duplicate IDs can be silently merged during cause mapping, which shrinks the denominator and distorts the calculated CSMFs. Please de-duplicate the IDs and re-upload.",
      length(dup_ids), shown, more), call. = FALSE)
  }

  mapped_ids <- rownames(va_broad)[rowSums(va_broad) > 0]
  dropped_ids <- setdiff(ids, mapped_ids)
  if (length(dropped_ids) == 0) return(invisible(TRUE))

  dropped_causes <- input_data$cause[match(dropped_ids, ids)]
  counts <- sort(table(dropped_causes), decreasing = TRUE)
  expected <- get_broad_causes(age_group)
  lines <- vapply(names(counts), function(cn)
    sprintf("  - %s: %d records", cn, as.integer(counts[cn])), character(1))

  msg <- paste(
    sprintf("%d of %d records have a cause that is not recognized for calibration (age_group='%s') and would be dropped:",
            length(dropped_ids), length(ids), age_group),
    paste(lines, collapse = "\n"),
    "",
    sprintf("Supported broad causes for '%s':", age_group),
    paste0("  ", paste(expected, collapse = ", ")),
    "",
    "Please relabel these records to a supported cause (e.g. 'other') or remove them, then re-upload.",
    sep = "\n")
  stop(msg, call. = FALSE)
}

# Check if causes are already in broad format (all unique values are broad cause names).
# Normalizes both sides so spaces / underscores / hyphens / case all match.
is_broad_format <- function(causes, age_group) {
  broad <- get_broad_causes(age_group)
  unique_causes <- unique(normalize_cause(causes))
  unique_causes <- unique_causes[!is.na(unique_causes) & nzchar(unique_causes)]
  all(unique_causes %in% normalize_cause(broad))
}

# Build one-hot indicator matrix directly from broad-format causes, skipping cause_map().
# Normalizes both input causes and broad-cause names so space/underscore/hyphen/case
# variants all match the canonical column.
build_broad_matrix <- function(df, age_group) {
  broad <- get_broad_causes(age_group)
  broad_norm <- normalize_cause(broad)
  causes <- normalize_cause(df$cause)

  mat <- matrix(0L, nrow = nrow(df), ncol = length(broad), dimnames = list(df$ID, broad))
  for (i in seq_len(nrow(df))) {
    idx <- match(causes[i], broad_norm)
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
build_cause_order <- function(broad_matrix) {
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

# ---------------------------------------------------------------------------
# Misclassification matrix (issue #90; corrected in issue #104)
#
# vacalibration calibrates only a SUBMATRIX of the broad causes:
#   * `donotcalib` is always excluded. `vacalibration()` applies
#     `if (is.null(donotcalib)) donotcalib = "other"` and the dashboard never
#     passes one, so `other` is always excluded.
#   * with `donotcalib_type = "learn"` (the default) it excludes ADDITIONAL
#     causes PER ALGORITHM whose misclassification column is near-constant
#     (`diff(range(column)) <= nocalib.threshold`), i.e. causes the algorithm
#     cannot distinguish. These are calibrated for one algorithm and not for
#     another, so the excluded set is per-algorithm, never a global "other".
#
# Its own plot subsets to the calibrated causes FIRST and then row-normalizes
# over that submatrix. Normalizing over ALL causes instead deflates every entry
# by 1/(1 - excluded mass) and renders rows that carry input data rather than
# calibration output -- the defect reported in issue #104.
# ---------------------------------------------------------------------------

# Read the per-algorithm not-calibrated declaration, whatever this package
# version happens to call it. Returns list(found, causes); `found` distinguishes
# "the package said nothing was excluded" from "no such field exists".
#
# v2.0: `donotcalib` (logical algorithm x cause), `causes_notcalibrated` (list)
# v2.2: `donotcalib_study`   -- only what the INPUT `donotcalib` asked for
#       `donotcalib_tomodel` -- documented as "a modified donotcalib_study if
#        donotcalib_type is provided and ensemble=TRUE"; the ensemble path
#        intersects the per-algorithm masks, so it can under-report.
# Every one of these can under-report, so callers union it with the direct
# read-out in .passthrough_not_calibrated().
.declared_not_calibrated <- function(result, algo_name, causes) {
  found <- FALSE
  out <- character()

  for (field in c("donotcalib_tomodel", "donotcalib_study", "donotcalib")) {
    m <- result[[field]]
    if (is.null(m) || !is.matrix(m)) next

    idx <- if (!is.null(rownames(m)) && algo_name %in% rownames(m)) {
      match(algo_name, rownames(m))
    } else if (nrow(m) == 1L) {
      1L  # a single-algorithm result may carry no algorithm name
    } else {
      NA_integer_
    }
    if (is.na(idx)) next

    flags <- as.logical(m[idx, ])
    flags[is.na(flags)] <- FALSE
    labels <- if (!is.null(colnames(m))) colnames(m) else causes
    if (length(labels) != length(flags)) next

    found <- TRUE
    out <- union(out, labels[flags])
  }

  cn <- result$causes_notcalibrated
  if (is.list(cn) && !is.null(names(cn)) && algo_name %in% names(cn)) {
    found <- TRUE
    out <- union(out, as.character(cn[[algo_name]]))
  }

  list(found = found, causes = intersect(causes, out))
}

# Read the not-calibrated set straight off the calibration output. A cause that
# was not calibrated is passed through untouched, so its calibrated CSMF equals
# its uncalibrated CSMF and its credible interval is degenerate. This signature
# needs no version-specific field name and is per-algorithm by construction --
# it is exactly what vacalibration's own plot greys out.
.passthrough_not_calibrated <- function(result, algo_name, causes) {
  none <- list(found = FALSE, causes = character())

  ps <- result$pcalib_postsumm
  pu <- result$p_uncalib
  if (is.null(ps) || is.null(pu)) return(none)
  if (length(dim(ps)) != 3L || length(dim(pu)) != 2L) return(none)

  dn <- dimnames(ps)
  if (is.null(dn) || any(sapply(dn, is.null))) return(none)
  if (!(algo_name %in% dn[[1]])) return(none)
  if (!all(c("postmean", "lowcredI", "upcredI") %in% dn[[2]])) return(none)
  if (is.null(rownames(pu)) || !(algo_name %in% rownames(pu))) return(none)

  shared <- intersect(causes, intersect(dn[[3]], colnames(pu)))
  if (!length(shared)) return(none)

  out <- character()
  for (cause in shared) {
    mean_c  <- ps[algo_name, "postmean", cause]
    lower_c <- ps[algo_name, "lowcredI", cause]
    upper_c <- ps[algo_name, "upcredI", cause]
    uncal_c <- pu[algo_name, cause]
    if (any(!is.finite(c(mean_c, lower_c, upper_c, uncal_c)))) next
    if (abs(lower_c - upper_c) < 1e-9 && abs(mean_c - uncal_c) < 1e-9) {
      out <- c(out, cause)
    }
  }
  list(found = TRUE, causes = out)
}

# The causes vacalibration did not calibrate for one algorithm.
not_calibrated_causes <- function(result, algo_name, causes) {
  declared <- .declared_not_calibrated(result, algo_name, causes)
  from_csmf <- .passthrough_not_calibrated(result, algo_name, causes)

  excluded <- union(declared$causes, from_csmf$causes)

  # Neither source said anything at all: mirror vacalibration()'s own default
  # (`if (is.null(donotcalib)) donotcalib = "other"`), which the dashboard never
  # overrides. Only reached when the result carries no usable calibration output.
  if (!length(excluded) && !declared$found && !from_csmf$found && "other" %in% causes) {
    excluded <- "other"
  }

  intersect(causes, excluded)
}

# Logical keep-vector for one axis. Unnamed axes keep everything.
.keep_causes <- function(labels, n, not_calibrated) {
  if (is.null(labels) || !length(not_calibrated)) return(rep(TRUE, n))
  !(labels %in% not_calibrated)
}

# Normalize a misclassification matrix so each row sums to 1 over the CALIBRATED
# causes. Converts Dirichlet scale parameters to conditional probabilities.
#
# `not_calibrated` names causes vacalibration excluded from calibration; they are
# dropped from BOTH axes BEFORE normalizing, matching vacalibration's own
# "Used For Calibration" panel (subset, then row-normalize). Keeping them in the
# denominator deflates every entry (issue #104).
#
# Input: 2D matrix [champs_cause, va_cause] or 3D array [algorithm, champs_cause, va_cause]
# Returns: the same shape restricted to the kept causes, each row divided by its
# row sum (NULL if input is NULL or nothing survives masking).
normalize_mmat <- function(mmat, not_calibrated = character()) {
  if (is.null(mmat)) return(NULL)

  if (length(dim(mmat)) == 2) {
    keep_r <- .keep_causes(rownames(mmat), nrow(mmat), not_calibrated)
    keep_c <- .keep_causes(colnames(mmat), ncol(mmat), not_calibrated)
    sub <- mmat[keep_r, keep_c, drop = FALSE]
    if (nrow(sub) == 0 || ncol(sub) == 0) return(NULL)
    rs <- rowSums(sub)
    rs[!is.finite(rs) | rs == 0] <- 1  # a fully-zero row stays zero, no NaN
    return(sub / rs)
  }

  if (length(dim(mmat)) == 3) {
    # Exclusions are PER ALGORITHM, so one mask cannot be correct for every slice
    # of a 3D array -- insilicova excludes congenital_malformation where interva
    # does not. extract_misclass_matrix() therefore slices first and masks each
    # 2D slice with its own set. Refuse the ambiguous call rather than silently
    # apply one algorithm's exclusions to all of them.
    if (length(not_calibrated)) {
      stop("normalize_mmat(): `not_calibrated` is per-algorithm and cannot be ",
           "applied to a 3D array. Slice per algorithm first, as ",
           "extract_misclass_matrix() does.")
    }
    dn <- dimnames(mmat)
    keep_r <- .keep_causes(if (is.null(dn)) NULL else dn[[2]], dim(mmat)[2], not_calibrated)
    keep_c <- .keep_causes(if (is.null(dn)) NULL else dn[[3]], dim(mmat)[3], not_calibrated)
    out <- mmat[, keep_r, keep_c, drop = FALSE]
    if (dim(out)[2] == 0 || dim(out)[3] == 0) return(NULL)
    for (k in seq_len(dim(out)[1])) {
      slice <- matrix(out[k, , ], nrow = dim(out)[2], ncol = dim(out)[3])
      rs <- rowSums(slice)
      rs[!is.finite(rs) | rs == 0] <- 1
      out[k, , ] <- slice / rs
    }
    return(out)
  }

  mmat
}

# Build the misclassification matrix shown in the results view (issue #90):
# P(VA cause | CHAMPS cause), one entry per algorithm.
#
# vacalibration v2.2 returns the matrix actually used in calibration as
# `Mmat_tomodel` (documented in ?vacalibration: "This is used for calibration"),
# arranged algorithm x CHAMPS cause x VA cause. It is Dirichlet counts in prior
# mode and normalized probabilities in fixed mode; normalize_mmat row-normalizes
# both to probabilities. (Pre-2.2 used Mmat.asDirich/Mmat.fixed, which no longer
# exist — reading those silently produced NULL, which is why the matrix stopped
# appearing.)
#
# `single_algo_name` is the label used only for a 2D (single-algorithm) result
# that carries no algorithm dimname. Returns a named list (one entry per
# algorithm) or NULL when the result has no misclassification matrix.
#
# Each entry restricts the matrix to the causes that algorithm actually
# calibrated (issue #104) and reports the rest in `not_calibrated`. The excluded
# causes are DROPPED rather than emitted as NA: db/connection.R serializes the
# result with `toJSON(result, auto_unbox = TRUE)` and no `na = "null"`, so an NA
# cell would reach the frontend as the string "NA".
extract_misclass_matrix <- function(result, single_algo_name = "combined") {
  mmat <- result$Mmat_tomodel
  if (is.null(mmat)) return(NULL)

  ndim <- length(dim(mmat))
  if (!(ndim %in% c(2L, 3L))) return(NULL)

  dnames <- dimnames(mmat)
  misclass_matrix <- list()

  if (ndim == 3L) {
    # 3D: [algorithm, CHAMPS, VA] -- each algorithm has its own excluded set, so
    # slices can end up with different dimensions and must be built one by one.
    algo_names <- if (!is.null(dnames) && !is.null(dnames[[1]])) {
      dnames[[1]]
    } else {
      paste0("algorithm_", seq_len(dim(mmat)[1]))
    }
    for (i in seq_len(dim(mmat)[1])) {
      slice <- matrix(
        mmat[i, , ],
        nrow = dim(mmat)[2], ncol = dim(mmat)[3],
        dimnames = if (is.null(dnames)) NULL else list(dnames[[2]], dnames[[3]])
      )
      misclass_matrix[[algo_names[i]]] <- .build_misclass_entry(result, algo_names[i], slice)
    }
  } else {
    # 2D: [CHAMPS, VA] for a single algorithm
    misclass_matrix[[single_algo_name]] <- .build_misclass_entry(result, single_algo_name, mmat)
  }

  # An algorithm whose matrix collapsed away entirely contributes nothing.
  misclass_matrix <- misclass_matrix[!sapply(misclass_matrix, is.null)]
  if (!length(misclass_matrix)) return(NULL)

  misclass_matrix
}

# One algorithm's entry: the calibrated submatrix row-normalized to conditional
# probabilities, plus the causes vacalibration excluded so the UI can say so.
.build_misclass_entry <- function(result, algo_name, slice) {
  causes <- unique(c(rownames(slice), colnames(slice)))
  excluded <- not_calibrated_causes(result, algo_name, causes)

  norm <- normalize_mmat(slice, excluded)
  if (is.null(norm)) return(NULL)

  list(
    matrix = lapply(seq_len(nrow(norm)), function(row) round(norm[row, ], 4)),
    champs_causes = rownames(norm),
    va_causes = colnames(norm),
    not_calibrated = excluded
  )
}

# Build the per-algorithm CSMF breakdown shown in the results view. It is
# populated whenever the calibration produced more than one labeled result —
# i.e. multiple algorithms and/or an "ensemble" row — so an INDEPENDENT
# multi-algorithm run surfaces every algorithm's calibration even with
# "Combine algorithms?" off (issue #83). Returns a named list (one entry per
# label) or NULL for a single-label (single-algorithm, no ensemble) run.
build_per_algorithm <- function(result) {
  result_labels <- dimnames(result$pcalib_postsumm)[[1]]
  if (length(result_labels) <= 1) return(NULL)

  per_algorithm <- list()
  for (label in result_labels) {
    per_algorithm[[label]] <- list(
      uncalibrated_csmf   = as.list(round(result$p_uncalib[label, ], 4)),
      calibrated_csmf     = as.list(round(result$pcalib_postsumm[label, "postmean", ], 4)),
      calibrated_ci_lower = as.list(round(result$pcalib_postsumm[label, "lowcredI", ], 4)),
      calibrated_ci_upper = as.list(round(result$pcalib_postsumm[label, "upcredI", ], 4))
    )
  }
  per_algorithm
}
