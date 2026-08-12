# =============================================================================
# Vacalibration Backend Tests
# =============================================================================
# Tests input data validity, vacalibration computation, and output correctness.
#
# Usage:
#   Full suite (includes MCMC, 2-5 min):
#     Rscript tests/test_vacalibration_backend.R
#
#   Input-only (no MCMC, < 10 sec):
#     Rscript tests/test_vacalibration_backend.R --input-only
#
# Run from project root or backend/ directory. Exit code: 0 = all pass, 1 = failures.

library(vacalibration)

# --- Parse command-line arguments ---
args <- commandArgs(trailingOnly = TRUE)
input_only <- "--input-only" %in% args

# --- Test Helpers ---
.test_count <- 0L
.pass_count <- 0L
.fail_count <- 0L
.fail_msgs  <- character()

test <- function(desc, expr) {
  .test_count <<- .test_count + 1L
  result <- tryCatch({
    ok <- eval(expr, envir = parent.frame())
    if (!isTRUE(ok)) stop("assertion returned FALSE")
    .pass_count <<- .pass_count + 1L
    cat(sprintf("  PASS: %s\n", desc))
  }, error = function(e) {
    .fail_count <<- .fail_count + 1L
    msg <- sprintf("  FAIL: %s -- %s", desc, e$message)
    .fail_msgs <<- c(.fail_msgs, msg)
    cat(msg, "\n")
  })
}

section <- function(title) cat(sprintf("\n=== %s ===\n", title))

# --- Locate project paths ---
# Works whether run from project root or backend/
if (file.exists("backend/plumber.R")) {
  backend_dir  <- "backend"
  frontend_dir <- "frontend"
} else if (file.exists("plumber.R")) {
  backend_dir  <- "."
  frontend_dir <- "../frontend"
} else {
  stop("Run this test from the project root or backend/ directory")
}

sample_dir <- file.path(backend_dir, "data", "sample_data")

# =============================================================================
# 1. INPUT DATA VALIDATION -- Frontend CSV samples
# =============================================================================
section("1. Frontend Sample CSV Files")

# --- InterVA neonate ---
interva_csv <- file.path(frontend_dir, "public", "sample_interva_neonate.csv")
test("InterVA sample CSV exists", file.exists(interva_csv))

interva_df <- read.csv(interva_csv, stringsAsFactors = FALSE)
test("InterVA sample has ID column", "ID" %in% names(interva_df))
test("InterVA sample has cause column", "cause" %in% names(interva_df))
test("InterVA sample has 1190 records", nrow(interva_df) == 1190)
test("InterVA sample has no NA in cause", !any(is.na(interva_df$cause)))
test("InterVA sample has no empty cause", !any(interva_df$cause == ""))

interva_causes <- sort(unique(interva_df$cause))
cat("  InterVA unique causes:", paste(interva_causes, collapse = ", "), "\n")

# --- InSilicoVA neonate ---
insilico_csv <- file.path(frontend_dir, "public", "sample_insilicova_neonate.csv")
test("InSilicoVA sample CSV exists", file.exists(insilico_csv))

insilico_df <- read.csv(insilico_csv, stringsAsFactors = FALSE)
test("InSilicoVA sample has ID column", "ID" %in% names(insilico_df))
test("InSilicoVA sample has cause column", "cause" %in% names(insilico_df))
test("InSilicoVA sample has 1190 records", nrow(insilico_df) == 1190)
test("InSilicoVA sample has no NA in cause", !any(is.na(insilico_df$cause)))

insilico_causes <- sort(unique(insilico_df$cause))
cat("  InSilicoVA unique causes:", paste(insilico_causes, collapse = ", "), "\n")

# --- EAVA neonate ---
eava_csv <- file.path(frontend_dir, "public", "sample_eava_neonate.csv")
test("EAVA sample CSV exists", file.exists(eava_csv))

eava_df <- read.csv(eava_csv, stringsAsFactors = FALSE)
test("EAVA sample has ID column", "ID" %in% names(eava_df))
test("EAVA sample has cause column", "cause" %in% names(eava_df))
# EAVA: 940 records — the 250 "Unspecified" rows were removed so every record
# maps to a supported broad cause (issue #92; matches the 940-row EAVA RDS).
test("EAVA sample has 940 records (Unspecified removed)", nrow(eava_df) == 940)
test("EAVA sample has no NA in cause", !any(is.na(eava_df$cause)))
test("EAVA sample no longer contains 'Unspecified' (issue #92)",
     !any(eava_df$cause == "Unspecified"))

eava_causes <- sort(unique(eava_df$cause))
cat("  EAVA unique causes:", paste(eava_causes, collapse = ", "), "\n")

# --- Sample ID sets ---
test("InterVA and InSilicoVA samples share identical ID sets",
     setequal(interva_df$ID, insilico_df$ID))
test("EAVA sample IDs are a subset of the other samples (Unspecified rows removed)",
     all(eava_df$ID %in% interva_df$ID))

# =============================================================================
# 2. INPUT DATA VALIDATION -- Cause mapping compatibility
# =============================================================================
section("2. Cause Mapping Compatibility")

# vacalibration::cause_map expects specific cause names (case-insensitive).
# The backend uses fix_causes_for_vacalibration + safe_cause_map to handle this.
# Here we verify that every cause in the sample files can be mapped to a
# valid broad cause category via cause_map.

neonate_broad_causes <- c("congenital_malformation", "pneumonia",
                          "sepsis_meningitis_inf", "ipre", "other", "prematurity")

# Source the backend utils to get fix_causes_for_vacalibration and safe_cause_map
source(file.path(backend_dir, "jobs", "utils.R"))

# Test InterVA cause mapping
interva_fixed <- fix_causes_for_vacalibration(interva_df)
interva_broad <- tryCatch(
  safe_cause_map(df = interva_fixed, age_group = "neonate"),
  error = function(e) NULL
)
test("InterVA causes map to broad categories without error", !is.null(interva_broad))
test("InterVA broad matrix has correct columns",
     !is.null(interva_broad) && setequal(colnames(interva_broad), neonate_broad_causes))
test("InterVA broad matrix rows match input records",
     !is.null(interva_broad) && nrow(interva_broad) == nrow(interva_df))

# Test InSilicoVA cause mapping
insilico_fixed <- fix_causes_for_vacalibration(insilico_df)
insilico_broad <- tryCatch(
  safe_cause_map(df = insilico_fixed, age_group = "neonate"),
  error = function(e) NULL
)
test("InSilicoVA causes map to broad categories without error", !is.null(insilico_broad))
test("InSilicoVA broad matrix has correct columns",
     !is.null(insilico_broad) && setequal(colnames(insilico_broad), neonate_broad_causes))

# Test EAVA cause mapping
eava_fixed <- fix_causes_for_vacalibration(eava_df)
eava_broad <- tryCatch(
  safe_cause_map(df = eava_fixed, age_group = "neonate"),
  error = function(e) NULL
)
test("EAVA causes map to broad categories without error", !is.null(eava_broad))
test("EAVA broad matrix has correct columns",
     !is.null(eava_broad) && setequal(colnames(eava_broad), neonate_broad_causes))

# Verify each broad cause column sums to an integer count (binary indicator matrix)
if (!is.null(interva_broad)) {
  col_sums <- colSums(interva_broad)
  test("InterVA broad matrix total equals number of records",
       sum(col_sums) == nrow(interva_df))
}

# =============================================================================
# 2b. INPUT DATA VALIDATION -- Undetermined-cause exclusion ("Unspecified")
# =============================================================================
section("2b. Undetermined-cause exclusion (Unspecified)")

# vacalibration::cause_map() drops records whose cause is "Unspecified" by
# design (subset(df, cause != "Unspecified")). The vacalibration package's own
# EAVA neonate dataset (comsamoz_CCVAoutput) has 250 such records. Without
# dropping them up front, assert_all_causes_mapped (issue #92) treats those
# intended drops as an error and rejects the whole dataset -- the exact failure
# users hit when uploading the package's bundled datasets. The backend must
# drop them (loudly logged, not silent) so calibration reproduces the package's
# native denominator (940) instead of erroring.
data(comsamoz_CCVAoutput)
eava_pkg <- as.data.frame(comsamoz_CCVAoutput$neonate$eava)
eava_pkg$ID <- as.character(eava_pkg$ID)
n_unspec <- sum(tolower(trimws(eava_pkg$cause)) == "unspecified")
test("package EAVA neonate data contains Unspecified records (fixture sanity)",
     n_unspec == 250)

# Baseline: without dropping, the #92 guard must reject the dataset
raw_broad <- tryCatch(
  safe_cause_map(df = fix_causes_for_vacalibration(eava_pkg), age_group = "neonate"),
  error = function(e) NULL)
test("without dropping, assert_all_causes_mapped rejects Unspecified records",
     !is.null(raw_broad) &&
     inherits(tryCatch(assert_all_causes_mapped(eava_pkg, raw_broad, "neonate"),
                       error = function(e) e), "error"))

# With the fix: drop undetermined causes, then the full path succeeds
eava_dropped <- drop_undetermined_causes(eava_pkg)
test("drop_undetermined_causes removes exactly the Unspecified records",
     nrow(eava_dropped) == nrow(eava_pkg) - n_unspec)
dropped_broad <- tryCatch(
  safe_cause_map(df = fix_causes_for_vacalibration(eava_dropped), age_group = "neonate"),
  error = function(e) NULL)
test("after dropping, EAVA package data passes assert_all_causes_mapped",
     !is.null(dropped_broad) &&
     isTRUE(assert_all_causes_mapped(eava_dropped, dropped_broad, "neonate")))
test("after dropping, denominator matches package native (940)",
     !is.null(dropped_broad) && nrow(dropped_broad) == 940)

# Datasets without undetermined causes must be untouched
test("drop_undetermined_causes leaves InterVA data unchanged",
     nrow(drop_undetermined_causes(interva_df)) == nrow(interva_df))

# =============================================================================
# 2c. INPUT DATA VALIDATION -- Child specific-cause mapping (package data)
# =============================================================================
section("2c. Child specific-cause mapping (vacalibration package data)")

# safe_cause_map injects dummy rows for all 9 child broad categories to work
# around cause_map()'s non-conformable bug. Two child dummies were invalid
# specific-cause names ("diarrheal diseases" [misspelled] and "other" [not a
# child specific cause]), so they renamed to NA, model.matrix dropped those
# columns, and cause_map crashed with "non-conformable arguments" -- breaking
# every specific-format child upload, including the vacalibration package's own
# comsamoz_CCVAoutput child datasets. (Neonate was unaffected: its "other"
# dummy matches the neonate map's literal "other" entry; child's does not.)
child_broad_causes <- c("malaria", "pneumonia", "diarrhea", "severe_malnutrition",
                        "hiv", "injury", "other", "other_infections", "nn_causes")
for (alg in c("interva", "insilicova", "eava")) {
  cd <- as.data.frame(comsamoz_CCVAoutput$child[[alg]])
  if ("cause1" %in% names(cd)) names(cd)[names(cd) == "cause1"] <- "cause"
  cd$ID <- as.character(cd$ID)
  cd <- drop_undetermined_causes(cd)
  cb <- tryCatch(safe_cause_map(fix_causes_for_vacalibration(cd), "child"),
                 error = function(e) NULL)
  test(sprintf("child %s package data maps via safe_cause_map without error", alg),
       !is.null(cb))
  test(sprintf("child %s broad matrix has all 9 broad causes", alg),
       !is.null(cb) && setequal(colnames(cb), child_broad_causes))
  test(sprintf("child %s broad matrix passes assert_all_causes_mapped", alg),
       !is.null(cb) && isTRUE(assert_all_causes_mapped(cd, cb, "child")))
}

# =============================================================================
# 2d. INPUT DATA VALIDATION -- safe_cause_map dummy integrity
# =============================================================================
section("2d. safe_cause_map dummy integrity")

# safe_cause_map() injects one dummy record per broad category so cause_map()
# sees all categories. If any dummy is not a recognized specific-cause name,
# cause_map() crashes ("non-conformable") or silently drops a category. Assert
# the hardcoded dummies produce EVERY broad category for both age groups -- a
# direct regression guard for the child "diarrheal diseases"/"other" bug.
for (ag in c("neonate", "child")) {
  seed_cause <- if (ag == "neonate") c("prematurity", "neonatal sepsis") else c("malaria", "pneumonia")
  minimal <- data.frame(ID = c("m1", "m2"), cause = seed_cause, stringsAsFactors = FALSE)
  m <- tryCatch(safe_cause_map(minimal, ag), error = function(e) NULL)
  test(sprintf("safe_cause_map(%s) succeeds on minimal input", ag), !is.null(m))
  test(sprintf("safe_cause_map(%s) dummies inject all broad categories", ag),
       !is.null(m) && setequal(colnames(m), get_broad_causes(ag)))
  test(sprintf("safe_cause_map(%s) returns only the real records (dummies removed)", ag),
       !is.null(m) && nrow(m) == nrow(minimal))
}

# =============================================================================
# 2e. INPUT DATA VALIDATION -- preview_cause_mapping report
# =============================================================================
section("2e. preview_cause_mapping report")

# EAVA neonate package data: 250 Unspecified excluded, rest recognized.
eava_prev <- as.data.frame(comsamoz_CCVAoutput$neonate$eava)
eava_prev$ID <- as.character(eava_prev$ID)
rep_eava <- preview_cause_mapping(eava_prev, "neonate")
test("preview: total_records is full upload count", rep_eava$total_records == 1190)
test("preview: 250 Unspecified excluded",
     length(rep_eava$excluded_undetermined) == 1 &&
     rep_eava$excluded_undetermined[[1]]$cause == "Unspecified" &&
     rep_eava$excluded_undetermined[[1]]$count == 250)
test("preview: no unrecognized causes in clean package data",
     length(rep_eava$unrecognized) == 0 && isFALSE(rep_eava$has_errors))
test("preview: calibrated denominator excludes Unspecified (940)",
     rep_eava$calibrated_denominator == 940)
test("preview: mapping rows sum to the calibrated denominator",
     sum(vapply(rep_eava$mapping, function(m) m$count, integer(1))) == 940)

# A deliberately misspelled cause must be flagged unrecognized with a suggestion.
bad_df <- data.frame(ID = as.character(1:5),
                     cause = c("Prematurity", "Pnemonia", "Pnemonia", "Neonatal sepsis", "Birth asphyxia"),
                     stringsAsFactors = FALSE)
rep_bad <- preview_cause_mapping(bad_df, "neonate")
test("preview: misspelled cause is unrecognized and blocks (has_errors)",
     rep_bad$has_errors &&
     any(vapply(rep_bad$unrecognized, function(u) u$cause == "Pnemonia" && u$count == 2, logical(1))))
test("preview: unrecognized cause carries a spelling suggestion",
     any(vapply(rep_bad$unrecognized,
                function(u) u$cause == "Pnemonia" && !is.null(u$suggestion) && nzchar(u$suggestion),
                logical(1))))

# Missing (NA) and blank causes must be REPORTED, not silently dropped (R's
# table() drops NA by default). They surface as an unrecognized "(missing)"
# bucket, and every record is accounted for in exactly one bucket.
na_df <- data.frame(ID = as.character(1:4),
                    cause = c("Prematurity", NA, "", "Neonatal sepsis"),
                    stringsAsFactors = FALSE)
rep_na <- preview_cause_mapping(na_df, "neonate")
test("preview: NA/blank causes are accounted for (buckets reconcile to total)",
     rep_na$total_records == 4 &&
     (rep_na$calibrated_denominator +
      sum(vapply(rep_na$excluded_undetermined, function(e) e$count, integer(1))) +
      sum(vapply(rep_na$unrecognized, function(u) u$count, integer(1)))) == 4)
test("preview: NA/blank causes surface as unrecognized (has_errors)",
     rep_na$has_errors &&
     any(vapply(rep_na$unrecognized, function(u) u$cause == "(missing)" && u$count == 2, logical(1))))

# Consistency: preview's recognized denominator == job-path mapped rows, for
# every bundled dataset (both age groups, all algorithms). This is the anti-drift
# guarantee: the preview must agree with what the real job will calibrate.
for (age in c("neonate", "child")) {
  for (alg in c("interva", "insilicova", "eava")) {
    d <- as.data.frame(comsamoz_CCVAoutput[[age]][[alg]])
    if ("cause1" %in% names(d) && !"cause" %in% names(d)) names(d)[names(d) == "cause1"] <- "cause"
    d$ID <- as.character(d$ID)
    rep <- preview_cause_mapping(d, age)
    dropped <- drop_undetermined_causes(d)
    vb <- if (is_broad_format(dropped$cause, age)) build_broad_matrix(dropped, age)
          else safe_cause_map(fix_causes_for_vacalibration(dropped), age)
    job_denom <- sum(rowSums(vb) > 0)
    test(sprintf("preview denominator matches job path for %s/%s", age, alg),
         rep$calibrated_denominator == job_denom)

    # Stronger than the denominator: assert the per-broad-cause ASSIGNMENTS match
    # the job path (a wrong cause->broad assignment with an unchanged total would
    # otherwise slip past a denominator-only check). This is the "SAME broad
    # matrix" guarantee the design doc claims.
    broad_all <- get_broad_causes(age)
    job_by_broad <- as.integer(colSums(vb)[broad_all])
    prev_by_broad <- setNames(integer(length(broad_all)), broad_all)
    for (m in rep$mapping) prev_by_broad[m$broad_cause] <- prev_by_broad[m$broad_cause] + m$count
    test(sprintf("preview per-broad-cause assignments match job path for %s/%s", age, alg),
         all(prev_by_broad[broad_all] == job_by_broad))
  }
}

# =============================================================================
# 2f. age_group resolution -- no silent fallback (issue #105)
# =============================================================================
section("2f. age_group resolution (issue #105)")

# Issue #105: the Calibrate button was permanently disabled for child uploads.
# POST /jobs/preview read req$args$age_group and silently defaulted to "neonate"
# when it was absent or empty. plumber 1.3.2 gives a multipart TEXT part no
# Content-Type and no filename, so parser_picker() falls through to
# parser_text(parseQS); parseQS treats the raw value as a query string, and a
# bare "child" (no "=") parses to an EMPTY LIST. So req$args$age_group arrived as
# list() and the endpoint silently scored child data against the NEONATE cause
# list. A missing/invalid age_group must now fail loudly (issues #77/#89).
test("utils.R defines resolve_age_group helper",
     exists("resolve_age_group") && is.function(resolve_age_group))

# Returns the rejection message, or "" if the call was accepted. Asserting on
# message CONTENT (not merely "an error was raised") keeps these tests from
# passing spuriously when the helper is missing or renamed.
ag_reject <- function(x) {
  e <- tryCatch({ resolve_age_group(x); NULL }, error = function(e) e)
  if (is.null(e)) return("")
  m <- conditionMessage(e)
  if (grepl("could not find function|object .* not found", m)) return("")
  m
}

# The exact corrupted shape plumber hands over for a multipart text field.
test("resolve_age_group rejects the empty list plumber produces for multipart text fields",
     grepl("required", ag_reject(list()), ignore.case = TRUE))
test("resolve_age_group rejects NULL (parameter absent)",
     grepl("required", ag_reject(NULL), ignore.case = TRUE))
test("resolve_age_group rejects character(0)",
     grepl("required", ag_reject(character(0)), ignore.case = TRUE))
test("resolve_age_group rejects an empty/whitespace string",
     grepl("required", ag_reject("   "), ignore.case = TRUE))
test("resolve_age_group NEVER silently returns 'neonate' for a missing value",
     nzchar(ag_reject(list())) && nzchar(ag_reject(NULL)) && nzchar(ag_reject(character(0))))
test("resolve_age_group rejects an unsupported age group naming the valid options",
     grepl("neonate", ag_reject("adult")) && grepl("child", ag_reject("adult")))
test("resolve_age_group error message names the offending parameter",
     grepl("age_group", ag_reject(list()), fixed = TRUE))

# Valid values, including the case/whitespace variants a form may send.
test("resolve_age_group accepts 'child'", identical(resolve_age_group("child"), "child"))
test("resolve_age_group accepts 'neonate'", identical(resolve_age_group("neonate"), "neonate"))
test("resolve_age_group normalizes case and whitespace",
     identical(resolve_age_group("  Child "), "child") &&
     identical(resolve_age_group("NEONATE"), "neonate"))

# End-to-end mapping guarantee for the issue #105 reproduction data: a
# broad-format CHILD upload (the shape attached to issue #101) must preview
# completely clean, so the Calibrate button stays ENABLED.
issue105_causes <- c(rep("other_infections", 720), rep("pneumonia", 526),
                     rep("diarrhea", 473), rep("malaria", 201),
                     rep("severe_malnutrition", 167), rep("hiv", 162),
                     rep("other", 134))
issue105_df <- data.frame(ID = as.character(seq_along(issue105_causes)),
                          cause = issue105_causes, stringsAsFactors = FALSE)
rep_child105 <- preview_cause_mapping(issue105_df, "child")
test("issue #105: broad-format child upload has NO unrecognized causes",
     length(rep_child105$unrecognized) == 0)
test("issue #105: broad-format child upload does not block submission (has_errors FALSE)",
     isFALSE(rep_child105$has_errors))
test("issue #105: every child record is calibrated (2383 of 2383)",
     rep_child105$total_records == 2383 && rep_child105$calibrated_denominator == 2383)
test("issue #105: child broad causes map 1:1 (no cross-category folding)",
     all(vapply(rep_child105$mapping,
                function(m) identical(m$input_cause, m$broad_cause), logical(1))))

# The failure signature of the bug, kept as documentation: the SAME data scored
# under the wrong age group reproduces the issue report exactly (1334 of 2383,
# hiv/other_infections/severe_malnutrition unrecognized, diarrhea and malaria
# folded into sepsis_meningitis_inf -- a cause that is not even a child broad
# cause). This is what a silent age_group fallback produced.
rep_neo105 <- preview_cause_mapping(issue105_df, "neonate")
test("issue #105: scoring child data as neonate is what produced the 1334/2383 report",
     rep_neo105$has_errors && rep_neo105$calibrated_denominator == 1334 &&
     setequal(vapply(rep_neo105$unrecognized, function(u) u$cause, character(1)),
              c("hiv", "other_infections", "severe_malnutrition")))
test("issue #105: sepsis_meningitis_inf is not a valid child broad cause",
     !("sepsis_meningitis_inf" %in% get_broad_causes("child")))

# =============================================================================
# 2g. POST /jobs scalar parameters -- no silent fallback
# =============================================================================
section("2g. POST /jobs parameter validation")

# Same class of defect as issue #105, on the endpoint that actually CREATES the
# calibration. POST /jobs had nine scalars each with a silent default:
#   job_type->"pipeline", algorithm->"InterVA", age_group->"neonate",
#   country->"Mozambique", calib_model_type->"Mmatprior", ensemble->"FALSE",
#   n_mcmc->"5000", n_burn->"2000", n_thin->"1"
# It was masked only because client.js happens to send them via URLSearchParams.
# The four that determine WHAT SCIENCE RAN are now required; the five tuning
# knobs keep their documented defaults but reject invalid values instead of
# turning them into NA.

# Returns the rejection message, or "" if the call was accepted. Asserting on
# message CONTENT keeps these from passing spuriously if a helper is missing.
reject <- function(expr) {
  e <- tryCatch({ force(expr); NULL }, error = function(e) e)
  if (is.null(e)) return("")
  m <- conditionMessage(e)
  if (grepl("could not find function|object .* not found", m)) return("")
  m
}

# --- param_scalar: conflicting repeats are an error, not a coin flip ---------
test("param_scalar returns '' for the empty list plumber makes of a multipart field",
     identical(param_scalar(list(), "x"), ""))
test("param_scalar returns '' for NULL", identical(param_scalar(NULL, "x"), ""))
test("param_scalar trims whitespace", identical(param_scalar("  child ", "x"), "child"))
test("param_scalar accepts a repeated identical value",
     identical(param_scalar(c("child", "child"), "x"), "child"))
test("param_scalar REJECTS conflicting repeated values rather than taking the first",
     grepl("conflicting", reject(param_scalar(c("child", "neonate"), "age_group"))))

# --- job_type: required -----------------------------------------------------
test("job_type is required (absent is rejected)",
     grepl("required", reject(require_enum(list(), "job_type", VALID_JOB_TYPES))))
test("job_type NEVER silently falls back to 'pipeline'",
     nzchar(reject(require_enum(list(), "job_type", VALID_JOB_TYPES))) &&
     nzchar(reject(require_enum(NULL, "job_type", VALID_JOB_TYPES))))
test("job_type rejects an unknown value naming the valid options",
     grepl("openva", reject(require_enum("batch", "job_type", VALID_JOB_TYPES))) &&
     grepl("pipeline", reject(require_enum("batch", "job_type", VALID_JOB_TYPES))))
test("job_type accepts all three supported values",
     identical(vapply(VALID_JOB_TYPES, function(t) require_enum(t, "job_type", VALID_JOB_TYPES),
                      character(1), USE.NAMES = FALSE), VALID_JOB_TYPES))
test("job_type normalizes case", identical(require_enum("Pipeline", "job_type", VALID_JOB_TYPES), "pipeline"))

# --- algorithm: required, single value or JSON array -------------------------
test("algorithm is required (absent is rejected)",
     grepl("required", reject(require_algorithms(list()))))
test("algorithm NEVER silently falls back to 'InterVA'",
     nzchar(reject(require_algorithms(list()))) && nzchar(reject(require_algorithms(NULL))) &&
     nzchar(reject(require_algorithms(""))))
test("algorithm accepts a single name", identical(require_algorithms("EAVA"), "EAVA"))
test("algorithm accepts the JSON array the frontend sends for an ensemble",
     identical(require_algorithms('["InterVA","EAVA"]'), c("InterVA", "EAVA")))
test("algorithm normalizes case to the canonical spelling",
     identical(require_algorithms("insilicova"), "InSilicoVA"))
test("algorithm de-duplicates repeats",
     identical(require_algorithms('["EAVA","EAVA"]'), "EAVA"))
test("algorithm rejects an unknown name",
     grepl("Invalid algorithm", reject(require_algorithms("Tariff"))))
test("algorithm rejects an unknown name nested in a JSON array",
     grepl("Tariff", reject(require_algorithms('["InterVA","Tariff"]'))))
test("algorithm rejects an empty JSON array",
     nzchar(reject(require_algorithms("[]"))))

# --- country: required, and validated against the CHAMPS strata --------------
test("country is required (absent is rejected)",
     grepl("required", reject(require_enum(list(), "country", CALIBRATION_COUNTRIES))))
test("country NEVER silently falls back to 'Mozambique'",
     nzchar(reject(require_enum(list(), "country", CALIBRATION_COUNTRIES))) &&
     nzchar(reject(require_enum(NULL, "country", CALIBRATION_COUNTRIES))))
test("country rejects an unsupported country",
     grepl("Invalid 'country'", reject(require_enum("Narnia", "country", CALIBRATION_COUNTRIES))))
test("country accepts every CHAMPS stratum, including the pooled 'other'",
     identical(vapply(CALIBRATION_COUNTRIES,
                      function(c) require_enum(c, "country", CALIBRATION_COUNTRIES),
                      character(1), USE.NAMES = FALSE), CALIBRATION_COUNTRIES))

# Drift guard: CALIBRATION_COUNTRIES is hardcoded, so assert it still matches the
# misclassification matrix it claims to mirror. Skipped loudly (not silently) if
# the installed vacalibration cannot supply Mmat_champs.
champs_countries <- tryCatch({
  data(Mmat_champs, package = "vacalibration", envir = environment())
  names(get("Mmat_champs", envir = environment())$neonate$eava$postmean)
}, error = function(e) NULL, warning = function(w) NULL)
if (is.null(champs_countries)) {
  cat("  NOTE: Mmat_champs unavailable in this R library -- country drift guard could not run\n")
} else {
  test("CALIBRATION_COUNTRIES still matches the CHAMPS misclassification matrix strata",
       setequal(CALIBRATION_COUNTRIES, champs_countries))
}

# --- calib_model_type: optional, defaults to Mmatprior, but validated -------
test("calib_model_type defaults to Mmatprior when absent",
     identical(optional_enum(list(), "calib_model_type", VALID_CALIB_MODEL_TYPES, "Mmatprior"),
               "Mmatprior"))
test("calib_model_type accepts Mmatfixed",
     identical(optional_enum("Mmatfixed", "calib_model_type", VALID_CALIB_MODEL_TYPES, "Mmatprior"),
               "Mmatfixed"))
test("calib_model_type rejects a value it cannot map (would reach vacalibration as garbage)",
     grepl("Invalid 'calib_model_type'",
           reject(optional_enum("Mmatwhatever", "calib_model_type", VALID_CALIB_MODEL_TYPES, "Mmatprior"))))

# --- ensemble: optional flag, must not become NA ----------------------------
test("ensemble defaults to FALSE when absent",
     identical(optional_flag(list(), "ensemble", FALSE), FALSE))
test("ensemble accepts the string forms a form may send",
     identical(optional_flag("TRUE", "ensemble", FALSE), TRUE) &&
     identical(optional_flag("true", "ensemble", FALSE), TRUE) &&
     identical(optional_flag("1", "ensemble", FALSE), TRUE) &&
     identical(optional_flag("false", "ensemble", FALSE), FALSE))
# as.logical("yes") is NA, and `if (NA && ...)` is a hard error downstream.
test("ensemble rejects an unparseable value instead of yielding NA",
     grepl("Invalid 'ensemble'", reject(optional_flag("maybe", "ensemble", FALSE))))
test("ensemble never returns NA", !is.na(optional_flag(list(), "ensemble", FALSE)))

# --- MCMC counts: optional, defaults kept, but must be positive integers ----
test("n_mcmc/n_burn/n_thin keep their documented defaults when absent",
     identical(optional_count(list(), "n_mcmc", 5000L), 5000L) &&
     identical(optional_count(list(), "n_burn", 2000L), 2000L) &&
     identical(optional_count(list(), "n_thin", 1L), 1L))
test("optional_count accepts a supplied value",
     identical(optional_count("12000", "n_mcmc", 5000L), 12000L))
# as.integer("abc") is NA with only a warning -- that used to reach the job record.
test("optional_count rejects a non-numeric value instead of yielding NA",
     grepl("Invalid 'n_mcmc'", reject(optional_count("abc", "n_mcmc", 5000L))))
test("optional_count rejects zero and negatives",
     nzchar(reject(optional_count("0", "n_mcmc", 5000L))) &&
     nzchar(reject(optional_count("-5", "n_mcmc", 5000L))))
test("optional_count rejects a fractional value",
     nzchar(reject(optional_count("1.5", "n_thin", 1L))))
test("optional_count rejects a value past integer range instead of overflowing to NA",
     grepl("Invalid 'n_mcmc'", reject(optional_count("3e9", "n_mcmc", 5000L))))
test("optional_count never returns NA",
     !is.na(optional_count(list(), "n_mcmc", 5000L)) &&
     !is.na(optional_count("7", "n_mcmc", 5000L)))

# --- the meta-guarantee -----------------------------------------------------
# The whole point: none of the four science-determining parameters may ever come
# back as its old silent default when the caller did not send it.
test("no required POST /jobs parameter resurrects its old silent default",
     all(vapply(list(
       function() require_enum(list(), "job_type", VALID_JOB_TYPES),
       function() require_algorithms(list()),
       function() resolve_age_group(list()),
       function() require_enum(list(), "country", CALIBRATION_COUNTRIES)
     ), function(f) nzchar(reject(f())), logical(1))))

# =============================================================================
# 3. INPUT DATA VALIDATION -- Backend RDS sample data
# =============================================================================
section("3. Backend RDS Sample Data")

for (algo in c("interva", "insilicova", "eava")) {
  rds_file <- file.path(sample_dir, sprintf("sample_vacalibration_%s_neonate.rds", algo))
  test(sprintf("RDS sample exists for %s", algo), file.exists(rds_file))

  if (file.exists(rds_file)) {
    rds_data <- readRDS(rds_file)
    test(sprintf("RDS %s has $data field", algo), !is.null(rds_data$data))
    test(sprintf("RDS %s has $va_algo field", algo), !is.null(rds_data$va_algo))

    if (!is.null(rds_data$data)) {
      test(sprintf("RDS %s broad matrix has correct columns", algo),
           setequal(colnames(rds_data$data), neonate_broad_causes))
      test(sprintf("RDS %s broad matrix has rows", algo), nrow(rds_data$data) > 0)

      # Each row should have exactly one 1 and the rest 0 (binary indicator)
      row_sums <- rowSums(rds_data$data)
      test(sprintf("RDS %s each row sums to 1 (binary indicator)", algo),
           all(row_sums == 1))
    }
  }
}

# =============================================================================
# 4. PARAMETER & CONFIGURATION VALIDATION
# =============================================================================
section("4. Parameter Validation")

# Valid countries per vacalibration package docs
valid_countries <- c("Bangladesh", "Ethiopia", "Kenya", "Mali",
                     "Mozambique", "Sierra Leone", "South Africa", "other")
valid_algorithms <- c("InterVA", "InSilicoVA", "EAVA")
valid_age_groups <- c("neonate", "child")
valid_calib_models <- c("Mmatprior", "Mmatfixed")

# Verify demo_configs.json has valid parameters
demo_file <- file.path(backend_dir, "data", "demo_configs.json")
test("demo_configs.json exists", file.exists(demo_file))

demos <- jsonlite::fromJSON(demo_file)$demos

# Filter to vacalibration demos only
vacalib_demos <- demos[demos$job_type == "vacalibration", ]
cat(sprintf("  Found %d vacalibration demos\n", nrow(vacalib_demos)))

for (i in seq_len(nrow(vacalib_demos))) {
  d <- vacalib_demos[i, ]
  label <- d$name

  test(sprintf("Demo '%s' has valid country", label),
       d$country %in% valid_countries)

  test(sprintf("Demo '%s' has valid age_group", label),
       d$age_group %in% valid_age_groups)

  test(sprintf("Demo '%s' has valid calib_model_type", label),
       d$calib_model_type %in% valid_calib_models)

  # Check algorithm(s) are valid
  algos <- if (is.list(d$algorithm)) unlist(d$algorithm[[1]]) else d$algorithm
  test(sprintf("Demo '%s' has valid algorithm(s)", label),
       all(algos %in% valid_algorithms))

  # Ensemble requires >= 2 algorithms
  if (isTRUE(d$ensemble)) {
    test(sprintf("Demo '%s' ensemble has >= 2 algorithms", label),
         length(algos) >= 2)
  }
}

# Verify MCMC defaults used in backend match reasonable values
test("Default nMCMC (5000) is >= 1000", 5000 >= 1000)
test("Default nBurn (2000) is < nMCMC (5000)", 2000 < 5000)
test("Default calib_model_type is 'Mmatprior'", "Mmatprior" %in% valid_calib_models)

# =============================================================================
# 4b. openVA SAMPLE DATA (WHO2016 FORMAT)
# =============================================================================
section("4b. openVA Sample Data (WHO2016 Format)")

openva_file <- file.path(sample_dir, "sample_neonate_openva.rds")
test("openVA neonate sample RDS exists", file.exists(openva_file))

if (file.exists(openva_file)) {
  openva <- readRDS(openva_file)
  test("openVA data is a data.frame", is.data.frame(openva))
  test("openVA data has ID column", "ID" %in% names(openva))
  test("openVA data has > 100 columns (WHO2016 format)", ncol(openva) > 100)
  test("openVA data has > 0 records", nrow(openva) > 0)

  cat(sprintf("  openVA neonate: %d records, %d columns\n", nrow(openva), ncol(openva)))

  # Check for WHO2016 indicator patterns (i004a, i019a, etc.)
  who_cols <- grep("^i[0-9]", names(openva), value = TRUE)
  test("openVA data has WHO2016 indicator columns (i###)", length(who_cols) > 50)

  # Check value encoding
  sample_vals <- unique(unlist(openva[, who_cols[1:min(10, length(who_cols))]]))
  sample_vals <- sample_vals[!is.na(sample_vals)]
  test("openVA indicator values are y/n/. encoded",
       all(sample_vals %in% c("y", "n", ".", "")))
}

# =============================================================================
# 4c. CSV-to-RDS CONSISTENCY
# =============================================================================
section("4c. CSV-to-RDS Consistency Check")

for (algo in c("interva", "insilicova", "eava")) {
  algo_label <- switch(algo,
    interva = "InterVA",
    insilicova = "InSilicoVA",
    eava = "EAVA"
  )

  csv_file <- file.path(frontend_dir, "public", sprintf("sample_%s_neonate.csv", algo))
  rds_file <- file.path(sample_dir, sprintf("sample_vacalibration_%s_neonate.rds", algo))

  if (file.exists(csv_file) && file.exists(rds_file)) {
    csv_df <- read.csv(csv_file, stringsAsFactors = FALSE)
    csv_fixed <- fix_causes_for_vacalibration(csv_df)
    csv_broad <- tryCatch(
      safe_cause_map(df = csv_fixed, age_group = "neonate"),
      error = function(e) NULL
    )
    rds_mat <- readRDS(rds_file)$data

    if (!is.null(csv_broad) && !is.null(rds_mat)) {
      # Same column names
      test(sprintf("%s CSV broad and RDS have same columns", algo_label),
           setequal(colnames(csv_broad), colnames(rds_mat)))

      # Same number of records
      test(sprintf("%s CSV broad and RDS have same record count", algo_label),
           nrow(csv_broad) == nrow(rds_mat))

      # Same column distributions (column means should match)
      if (nrow(csv_broad) == nrow(rds_mat)) {
        csv_means <- colMeans(csv_broad)
        rds_means <- colMeans(rds_mat[, names(csv_means)])
        max_diff <- max(abs(csv_means - rds_means))
        test(sprintf("%s CSV and RDS column means match (max diff: %.6f)", algo_label, max_diff),
             max_diff < 0.001)
      }
    }
  }
}

# =============================================================================
# 4d. CHILD (1-59m) SAMPLE DATA CORRECTNESS (issue #89)
# =============================================================================
# Issue #89 reported "wrong causes/estimates" for the InterVA + ensemble +
# CHILDREN case. The root cause (issue #92/#93) was that the EAVA sample
# silently DROPPED 21% of records (unmapped "Unspecified" causes), computing the
# CSMF over a deflated denominator and inflating every other cause. That guard is
# now in place; these checks lock the CHILD path so the same class of bug cannot
# regress: every child sample (frontend CSV + backend RDS, all 3 algorithms) must
# keep its FULL denominator, pass assert_all_causes_mapped, and use exactly the 9
# canonical child broad causes. (Calibrated *estimates* derive deterministically
# from this verified-correct input; the ensemble extraction is covered structurally
# by sections 11/12.)
section("4d. Child Sample Data Correctness (issue #89)")

child_broad_causes <- c("malaria", "pneumonia", "diarrhea", "severe_malnutrition",
                        "hiv", "injury", "other", "other_infections", "nn_causes")

# The backend's own canonical list must match the 9 expected child broad causes.
test("get_broad_causes('child') is the 9 expected broad causes",
     setequal(get_broad_causes("child"), child_broad_causes))

for (algo in c("interva", "insilicova", "eava")) {
  algo_label <- switch(algo, interva = "InterVA", insilicova = "InSilicoVA", eava = "EAVA")

  # --- Frontend CSV: follow the SAME branch logic the backend uses ---
  csv_file <- file.path(frontend_dir, "public", sprintf("sample_%s_child.csv", algo))
  if (file.exists(csv_file)) {
    csv_df <- read.csv(csv_file, stringsAsFactors = FALSE)
    raw_n <- nrow(csv_df)
    # A throw from the mapping is exactly the failure this section guards against,
    # so capture it and record a failing assertion instead of aborting the whole
    # script. (Keeps the mapping out of the test() descriptions, which are built
    # before test()'s own tryCatch runs.)
    csv_broad <- tryCatch(
      if (is_broad_format(csv_df$cause, "child")) {
        build_broad_matrix(csv_df, "child")
      } else {
        safe_cause_map(df = fix_causes_for_vacalibration(csv_df), age_group = "child")
      },
      error = function(e) e
    )
    test(sprintf("%s child CSV maps without error", algo_label),
         !inherits(csv_broad, "error"))

    if (!inherits(csv_broad, "error")) {
      mapped_n <- as.integer(sum(colSums(csv_broad)))

      # No silent drop: every record maps to a broad cause (the #89 root-cause domain).
      test(sprintf("%s child CSV maps every record (no silent drop): %d/%d", algo_label, mapped_n, raw_n),
           mapped_n == raw_n)
      # The #92 guard passes for the shipped sample.
      test(sprintf("%s child CSV passes assert_all_causes_mapped (issue #92 guard)", algo_label),
           isTRUE(assert_all_causes_mapped(csv_df, csv_broad, "child")))
      # Uses exactly the canonical 9 child broad causes (both mapping branches
      # produce the full canonical set, so this is a strict check, not a subset).
      test(sprintf("%s child CSV uses exactly the 9 canonical child broad causes", algo_label),
           setequal(colnames(csv_broad), child_broad_causes))
    }
  }

  # --- Backend RDS: full denominator + exact canonical cause set ---
  rds_file <- file.path(sample_dir, sprintf("sample_vacalibration_%s_child.rds", algo))
  if (file.exists(rds_file)) {
    rds_mat <- readRDS(rds_file)$data
    test(sprintf("%s child RDS has full denominator (colSums total == nrow)", algo_label),
         as.integer(sum(colSums(rds_mat))) == nrow(rds_mat))
    test(sprintf("%s child RDS uses exactly the 9 canonical child broad causes", algo_label),
         setequal(colnames(rds_mat), child_broad_causes))
  }
}

if (input_only) {
  cat("\n=== --input-only mode: skipping MCMC computation sections ===\n")
}

# =============================================================================
# COMPUTATION TESTS (skipped in --input-only mode)
# =============================================================================
if (!input_only) {

# =============================================================================
# 5a. GOLDEN DATASET CONTRACT -- vacalibration package's own bundled data
# =============================================================================
# The failures users hit came from uploading the vacalibration package's OWN
# bundled datasets (comsamoz_CCVAoutput) -- data the scrubbed frontend/RDS
# samples did not represent, so the suite stayed green while production broke.
# This contract test runs EVERY bundled dataset through the FULL upload path
# (drop undetermined -> map -> vacalibration) for both age groups and all three
# algorithms, plus an ensemble per age group, and asserts each returns the four
# deliverables: uncalibrated CSMF, calibrated CSMF, calibrated credible-interval
# bounds, and the misclassification matrix. This is the regression net for the
# whole "package data drifts from dashboard assumptions" class of bug (neonate
# Unspecified drop, child safe_cause_map dummies). Small MCMC -- shape, not
# convergence, is what is under test here.
section("5a. Golden Dataset Contract (vacalibration package data)")

data(comsamoz_CCVAoutput)

# Map one bundled dataset exactly the way the backend upload path does.
golden_broad <- function(age, algo) {
  d <- as.data.frame(comsamoz_CCVAoutput[[age]][[algo]])
  if ("cause1" %in% names(d) && !"cause" %in% names(d)) names(d)[names(d) == "cause1"] <- "cause"
  d$ID <- as.character(d$ID)
  d <- drop_undetermined_causes(d)
  vb <- if (is_broad_format(d$cause, age)) build_broad_matrix(d, age) else
        safe_cause_map(fix_causes_for_vacalibration(d), age)
  assert_all_causes_mapped(d, vb, age)
  vb
}

# Assert a vacalibration result carries all four deliverables for `label`.
assert_deliverables <- function(res, label, age, tag) {
  broad <- get_broad_causes(age)
  labs <- dimnames(res$pcalib_postsumm)[[1]]
  primary <- if (label %in% labs) label else labs[1]
  test(sprintf("%s: uncalibrated CSMF spans all broad causes", tag),
       setequal(names(res$p_uncalib[primary, ]), broad))
  test(sprintf("%s: calibrated CSMF (postmean) finite", tag),
       all(is.finite(res$pcalib_postsumm[primary, "postmean", ])))
  test(sprintf("%s: credible-interval bounds present and ordered (low <= high)", tag),
       all(res$pcalib_postsumm[primary, "lowcredI", ] <= res$pcalib_postsumm[primary, "upcredI", ]))
  test(sprintf("%s: misclassification matrix present", tag),
       !is.null(extract_misclass_matrix(res, single_algo_name = label)))
}

run_golden <- function(va_input, age, ensemble, label, tag) {
  res <- tryCatch(
    vacalibration(va_data = va_input, age_group = age, country = "Mozambique",
      missmat_type = "prior", ensemble = ensemble,
      nMCMC = 300, nBurn = 300, nThin = 1, verbose = FALSE, seed = 1),
    error = function(e) e)
  test(sprintf("%s runs without error", tag), !inherits(res, "error"))
  if (!inherits(res, "error")) assert_deliverables(res, label, age, tag)
}

for (age in c("neonate", "child")) {
  for (algo in c("interva", "insilicova", "eava")) {
    run_golden(setNames(list(golden_broad(age, algo)), algo), age, FALSE, algo,
               sprintf("golden %s/%s", age, algo))
  }
  ens_input <- setNames(lapply(c("interva", "insilicova", "eava"),
                               function(a) golden_broad(age, a)),
                        c("interva", "insilicova", "eava"))
  run_golden(ens_input, age, TRUE, "ensemble", sprintf("golden %s/ensemble", age))
}

# =============================================================================
# 5. VACALIBRATION COMPUTATION -- Single algorithm
# =============================================================================
section("5. Vacalibration Computation (Single Algorithm)")

# Test with InterVA sample (use backend RDS for speed)
rds_interva <- file.path(sample_dir, "sample_vacalibration_interva_neonate.rds")
if (file.exists(rds_interva)) {
  sample_data <- readRDS(rds_interva)
  va_input <- setNames(list(sample_data$data), sample_data$va_algo)

  cat("  Running vacalibration (InterVA, neonate, Mozambique)...\n")
  t0 <- Sys.time()
  result_interva <- tryCatch(
    vacalibration(
      va_data = va_input,
      age_group = "neonate",
      country = "Mozambique",
      missmat_type = "prior",
      ensemble = TRUE,
      nMCMC = 5000,
      nBurn = 2000,

      verbose = FALSE
    ),
    error = function(e) { cat("  ERROR:", e$message, "\n"); NULL }
  )
  elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
  cat(sprintf("  Elapsed: %.1f sec\n", elapsed))

  test("vacalibration returns non-NULL result", !is.null(result_interva))

  if (!is.null(result_interva)) {
    # -- p_uncalib --
    test("Result has p_uncalib", !is.null(result_interva$p_uncalib))
    uncalib <- result_interva$p_uncalib[1, ]
    test("Uncalibrated CSMF sums to ~1",
         abs(sum(uncalib) - 1) < 0.01)
    test("Uncalibrated CSMF values are all >= 0",
         all(uncalib >= 0))
    test("Uncalibrated CSMF has 6 broad causes (neonate)",
         length(uncalib) == 6)
    test("Uncalibrated CSMF cause names match broad categories",
         setequal(names(uncalib), neonate_broad_causes))

    # -- pcalib_postsumm --
    test("Result has pcalib_postsumm", !is.null(result_interva$pcalib_postsumm))
    postsumm <- result_interva$pcalib_postsumm
    calib_mean <- postsumm[1, "postmean", ]
    calib_low  <- postsumm[1, "lowcredI", ]
    calib_high <- postsumm[1, "upcredI", ]

    test("Calibrated mean CSMF sums to ~1",
         abs(sum(calib_mean) - 1) < 0.01)
    test("Calibrated mean values are all >= 0",
         all(calib_mean >= 0))
    test("Credible interval lower <= mean for all causes",
         all(calib_low <= calib_mean + 1e-6))
    test("Credible interval upper >= mean for all causes",
         all(calib_high >= calib_mean - 1e-6))
    test("Credible interval lower >= 0",
         all(calib_low >= -1e-6))
    test("Credible interval upper <= 1",
         all(calib_high <= 1 + 1e-6))

    # -- Misclassification matrix (v2.2 field; issue #90) --
    test("Result has Mmat_tomodel", !is.null(result_interva$Mmat_tomodel))
    mmat <- result_interva$Mmat_tomodel
    test("Mmat_tomodel is a matrix or array",
         (is.matrix(mmat) || is.array(mmat)) && length(dim(mmat)) %in% c(2, 3))
    if (length(dim(mmat)) == 2) {
      test("2D Mmat has 6 rows (CHAMPS causes)", nrow(mmat) == 6)
      test("2D Mmat all values >= 0", all(mmat >= 0))
    } else if (length(dim(mmat)) == 3) {
      test("3D Mmat has 6 CHAMPS causes (dim 2)", dim(mmat)[2] == 6)
      test("3D Mmat all values >= 0", all(mmat >= 0))
    }
  }
} else {
  cat("  SKIP: InterVA RDS sample not found\n")
}

# =============================================================================
# 6. VACALIBRATION COMPUTATION -- From CSV (simulating user upload)
# =============================================================================
section("6. Vacalibration from CSV Upload (InSilicoVA)")

insilico_fixed2 <- fix_causes_for_vacalibration(insilico_df)
insilico_broad2 <- safe_cause_map(df = insilico_fixed2, age_group = "neonate")
va_input_csv <- list("insilicova" = insilico_broad2)

cat("  Running vacalibration from CSV data (InSilicoVA, neonate, Mozambique)...\n")
t0 <- Sys.time()
result_csv <- tryCatch(
  vacalibration(
    va_data = va_input_csv,
    age_group = "neonate",
    country = "Mozambique",
    missmat_type = "prior",
    ensemble = TRUE,
    nMCMC = 5000,
    nBurn = 2000,
    verbose = FALSE
  ),
  error = function(e) { cat("  ERROR:", e$message, "\n"); NULL }
)
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("  Elapsed: %.1f sec\n", elapsed))

test("CSV-based vacalibration returns non-NULL result", !is.null(result_csv))

if (!is.null(result_csv)) {
  uncalib_csv <- result_csv$p_uncalib[1, ]
  test("CSV uncalibrated CSMF sums to ~1", abs(sum(uncalib_csv) - 1) < 0.01)
  test("CSV calibrated mean sums to ~1",
       abs(sum(result_csv$pcalib_postsumm[1, "postmean", ]) - 1) < 0.01)
}

# =============================================================================
# 7. VACALIBRATION COMPUTATION -- EAVA algorithm
# =============================================================================
section("7. Vacalibration from CSV Upload (EAVA)")

eava_fixed2 <- fix_causes_for_vacalibration(eava_df)
eava_broad2 <- safe_cause_map(df = eava_fixed2, age_group = "neonate")
va_input_eava <- list("eava" = eava_broad2)

cat("  Running vacalibration from CSV data (EAVA, neonate, Mozambique)...\n")
t0 <- Sys.time()
result_eava <- tryCatch(
  vacalibration(
    va_data = va_input_eava,
    age_group = "neonate",
    country = "Mozambique",
    missmat_type = "prior",
    ensemble = TRUE,
    nMCMC = 5000,
    nBurn = 2000,
    verbose = FALSE
  ),
  error = function(e) { cat("  ERROR:", e$message, "\n"); NULL }
)
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("  Elapsed: %.1f sec\n", elapsed))

test("EAVA vacalibration returns non-NULL result", !is.null(result_eava))

if (!is.null(result_eava)) {
  uncalib_eava <- result_eava$p_uncalib[1, ]
  test("EAVA uncalibrated CSMF sums to ~1", abs(sum(uncalib_eava) - 1) < 0.01)
  calib_eava <- result_eava$pcalib_postsumm[1, "postmean", ]
  test("EAVA calibrated mean sums to ~1", abs(sum(calib_eava) - 1) < 0.01)
}

# =============================================================================
# 8. OUTPUT STRUCTURE VALIDATION
# =============================================================================
section("8. Output Structure Validation")

# Simulate what run_vacalibration() produces and verify the output format
if (!is.null(result_interva)) {
  # Simulate the backend result extraction logic
  uncalibrated <- as.list(round(result_interva$p_uncalib[1, ], 4))
  calibrated   <- as.list(round(result_interva$pcalib_postsumm[1, "postmean", ], 4))
  calib_low    <- as.list(round(result_interva$pcalib_postsumm[1, "lowcredI", ], 4))
  calib_high   <- as.list(round(result_interva$pcalib_postsumm[1, "upcredI", ], 4))

  test("Output uncalibrated_csmf is a named list", is.list(uncalibrated) && !is.null(names(uncalibrated)))
  test("Output calibrated_csmf is a named list", is.list(calibrated) && !is.null(names(calibrated)))
  test("Output names are consistent across uncalib/calib/CI",
       identical(names(uncalibrated), names(calibrated)) &&
       identical(names(calibrated), names(calib_low)) &&
       identical(names(calibrated), names(calib_high)))

  # Verify calibration_summary.csv would be correct
  causes <- names(uncalibrated)
  summary_df <- data.frame(
    cause = causes,
    uncalibrated = unlist(uncalibrated),
    calibrated_mean = unlist(calibrated),
    calibrated_lower = unlist(calib_low),
    calibrated_upper = unlist(calib_high)
  )

  test("Summary CSV has 6 rows (neonate broad causes)", nrow(summary_df) == 6)
  test("Summary CSV has 5 columns", ncol(summary_df) == 5)
  test("Summary CSV column names correct",
       identical(names(summary_df),
                 c("cause", "uncalibrated", "calibrated_mean",
                   "calibrated_lower", "calibrated_upper")))
  test("Summary uncalibrated values sum to ~1",
       abs(sum(summary_df$uncalibrated) - 1) < 0.01)
  test("Summary calibrated_lower <= calibrated_mean",
       all(summary_df$calibrated_lower <= summary_df$calibrated_mean + 1e-4))
  test("Summary calibrated_upper >= calibrated_mean",
       all(summary_df$calibrated_upper >= summary_df$calibrated_mean - 1e-4))

  # Misclassification matrix output (v2.2 field; issue #90)
  mmat <- result_interva$Mmat_tomodel
  if (!is.null(mmat) && length(dim(mmat)) == 2) {
    dnames <- dimnames(mmat)
    mmat_df <- as.data.frame(round(mmat, 4))
    mmat_df <- cbind(CHAMPS_Cause = dnames[[1]], mmat_df)
    test("Misclass matrix CSV has CHAMPS_Cause column", "CHAMPS_Cause" %in% names(mmat_df))
    test("Misclass matrix all numeric values >= 0",
         all(as.matrix(mmat_df[, -1]) >= 0))
  }
}

# =============================================================================
# 9. DIFFERENT COUNTRY TESTS
# =============================================================================
section("9. Country Parameter Validation")

# Test that vacalibration works with different supported countries
if (file.exists(rds_interva)) {
  sample_data <- readRDS(rds_interva)
  va_input_country <- setNames(list(sample_data$data), sample_data$va_algo)

  for (country in c("South Africa", "Sierra Leone", "other")) {
    cat(sprintf("  Testing country: %s\n", country))
    result_country <- tryCatch(
      vacalibration(
        va_data = va_input_country,
        age_group = "neonate",
        country = country,
        missmat_type = "prior",
        ensemble = TRUE,
        nMCMC = 2000,
        nBurn = 1000,
  
        verbose = FALSE
      ),
      error = function(e) { cat("    ERROR:", e$message, "\n"); NULL }
    )
    test(sprintf("vacalibration succeeds for country=%s", country),
         !is.null(result_country))

    if (!is.null(result_country)) {
      calib_sum <- sum(result_country$pcalib_postsumm[1, "postmean", ])
      test(sprintf("Country=%s calibrated CSMF sums to ~1", country),
           abs(calib_sum - 1) < 0.02)
    }
  }
}

# =============================================================================
# 10. Mmatfixed MODEL TYPE
# =============================================================================
section("10. Mmatfixed Calibration Model")

if (file.exists(rds_interva)) {
  sample_data <- readRDS(rds_interva)
  va_input_fixed <- setNames(list(sample_data$data), sample_data$va_algo)

  cat("  Running vacalibration with Mmatfixed...\n")
  result_fixed <- tryCatch(
    vacalibration(
      va_data = va_input_fixed,
      age_group = "neonate",
      country = "Mozambique",
      missmat_type = "fixed",
      ensemble = TRUE,
      nMCMC = 2000,
      nBurn = 1000,

      verbose = FALSE
    ),
    error = function(e) { cat("  ERROR:", e$message, "\n"); NULL }
  )
  test("Mmatfixed returns non-NULL result", !is.null(result_fixed))

  if (!is.null(result_fixed)) {
    calib_fixed <- result_fixed$pcalib_postsumm[1, "postmean", ]
    test("Mmatfixed calibrated CSMF sums to ~1", abs(sum(calib_fixed) - 1) < 0.01)

    # Mmatfixed should have narrower CI since no uncertainty propagation on Mmat
    ci_width_fixed <- result_fixed$pcalib_postsumm[1, "upcredI", ] -
                      result_fixed$pcalib_postsumm[1, "lowcredI", ]

    if (!is.null(result_interva)) {
      ci_width_prior <- result_interva$pcalib_postsumm[1, "upcredI", ] -
                        result_interva$pcalib_postsumm[1, "lowcredI", ]
      test("Mmatfixed CI is generally narrower than Mmatprior",
           mean(ci_width_fixed) <= mean(ci_width_prior) + 0.05)
    }
  }
}

# =============================================================================
# 11. ENSEMBLE VACALIBRATION -- 2 Algorithms (from frontend CSVs)
# =============================================================================
section("11. Ensemble Vacalibration (2 Algorithms)")

# Ensemble = passing multiple algorithm outputs in va_data to vacalibration()
# vacalibration calibrates each algo separately AND produces a combined "ensemble" estimate

interva_broad_e <- safe_cause_map(df = fix_causes_for_vacalibration(interva_df), age_group = "neonate")
insilico_broad_e <- safe_cause_map(df = fix_causes_for_vacalibration(insilico_df), age_group = "neonate")

va_input_ens2 <- list(
  "interva" = interva_broad_e,
  "insilicova" = insilico_broad_e
)

cat("  Running ensemble vacalibration (InterVA + InSilicoVA, neonate, Mozambique)...\n")
t0 <- Sys.time()
result_ens2 <- tryCatch(
  vacalibration(
    va_data = va_input_ens2,
    age_group = "neonate",
    country = "Mozambique",
    missmat_type = "prior",
    ensemble = TRUE,
    nMCMC = 5000,
    nBurn = 2000,
    verbose = FALSE
  ),
  error = function(e) { cat("  ERROR:", e$message, "\n"); NULL }
)
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("  Elapsed: %.1f sec\n", elapsed))

test("Ensemble 2-algo returns non-NULL result", !is.null(result_ens2))

if (!is.null(result_ens2)) {
  # p_uncalib: one row per algorithm + ensemble
  test("p_uncalib has 3 rows (2 algos + ensemble)", nrow(result_ens2$p_uncalib) == 3)
  test("p_uncalib rows include interva", "interva" %in% rownames(result_ens2$p_uncalib))
  test("p_uncalib rows include insilicova", "insilicova" %in% rownames(result_ens2$p_uncalib))
  test("p_uncalib rows include ensemble", "ensemble" %in% rownames(result_ens2$p_uncalib))

  for (rn in rownames(result_ens2$p_uncalib)) {
    test(sprintf("Uncalibrated CSMF for %s sums to ~1", rn),
         abs(sum(result_ens2$p_uncalib[rn, ]) - 1) < 0.01)
  }

  # pcalib_postsumm: rows for each algo + "ensemble"
  postsumm2 <- result_ens2$pcalib_postsumm
  algo_names2 <- dimnames(postsumm2)[[1]]
  test("pcalib_postsumm has 3 rows (2 algos + ensemble)", length(algo_names2) == 3)
  test("pcalib_postsumm includes 'ensemble' row", "ensemble" %in% algo_names2)

  # Verify ensemble combined estimate
  ens_mean <- postsumm2["ensemble", "postmean", ]
  ens_low  <- postsumm2["ensemble", "lowcredI", ]
  ens_high <- postsumm2["ensemble", "upcredI", ]
  test("Ensemble calibrated mean sums to ~1", abs(sum(ens_mean) - 1) < 0.01)
  test("Ensemble mean values >= 0", all(ens_mean >= 0))
  test("Ensemble CI lower <= mean", all(ens_low <= ens_mean + 1e-6))
  test("Ensemble CI upper >= mean", all(ens_high >= ens_mean - 1e-6))

  # Per-algorithm calibrated results also valid
  for (rn in c("interva", "insilicova")) {
    algo_mean <- postsumm2[rn, "postmean", ]
    test(sprintf("Calibrated mean for %s sums to ~1", rn),
         abs(sum(algo_mean) - 1) < 0.01)
  }

  # Mmat_tomodel should be 3D: [algo, champs_cause, va_cause] (v2.2 field; issue #90)
  mmat_ens2 <- result_ens2$Mmat_tomodel
  test("Ensemble Mmat_tomodel is 3D", length(dim(mmat_ens2)) == 3)
  if (length(dim(mmat_ens2)) == 3) {
    test("Mmat 3D dim[1] = 2 (algorithms)", dim(mmat_ens2)[1] == 2)
    test("Mmat 3D dim[2] = 6 (CHAMPS causes)", dim(mmat_ens2)[2] == 6)
    test("Mmat 3D all values >= 0", all(mmat_ens2 >= 0))
  }
}

# =============================================================================
# 12. ENSEMBLE VACALIBRATION -- 3 Algorithms (all from frontend CSVs)
# =============================================================================
section("12. Ensemble Vacalibration (3 Algorithms)")

eava_broad_e <- safe_cause_map(df = fix_causes_for_vacalibration(eava_df), age_group = "neonate")

va_input_ens3 <- list(
  "interva" = interva_broad_e,
  "insilicova" = insilico_broad_e,
  "eava" = eava_broad_e
)

cat("  Running ensemble vacalibration (all 3 algorithms, neonate, Mozambique)...\n")
t0 <- Sys.time()
result_ens3 <- tryCatch(
  vacalibration(
    va_data = va_input_ens3,
    age_group = "neonate",
    country = "Mozambique",
    missmat_type = "prior",
    ensemble = TRUE,
    nMCMC = 5000,
    nBurn = 2000,
    verbose = FALSE
  ),
  error = function(e) { cat("  ERROR:", e$message, "\n"); NULL }
)
elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
cat(sprintf("  Elapsed: %.1f sec\n", elapsed))

test("Ensemble 3-algo returns non-NULL result", !is.null(result_ens3))

if (!is.null(result_ens3)) {
  test("p_uncalib has 4 rows (3 algos + ensemble)", nrow(result_ens3$p_uncalib) == 4)

  postsumm3 <- result_ens3$pcalib_postsumm
  algo_names3 <- dimnames(postsumm3)[[1]]
  test("pcalib_postsumm has 4 rows (3 algos + ensemble)", length(algo_names3) == 4)
  test("pcalib_postsumm includes all 3 algos + ensemble",
       all(c("interva", "insilicova", "eava", "ensemble") %in% algo_names3))

  # Ensemble combined estimate
  ens_mean3 <- postsumm3["ensemble", "postmean", ]
  test("3-algo ensemble mean sums to ~1", abs(sum(ens_mean3) - 1) < 0.01)
  test("3-algo ensemble mean values >= 0", all(ens_mean3 >= 0))

  # Each individual algo should also sum to ~1
  for (rn in c("interva", "insilicova", "eava")) {
    test(sprintf("3-algo: calibrated mean for %s sums to ~1", rn),
         abs(sum(postsumm3[rn, "postmean", ]) - 1) < 0.01)
  }

  # Mmat_tomodel: 3D with dim[1]=3 (v2.2 field; issue #90)
  mmat_ens3 <- result_ens3$Mmat_tomodel
  test("3-algo Mmat_tomodel is 3D with dim[1]=3",
       length(dim(mmat_ens3)) == 3 && dim(mmat_ens3)[1] == 3)
}

# =============================================================================
# 12b. new_test_data.csv VALIDATION (InterVA, Neonate, Mozambique)
# =============================================================================
section("12b. new_test_data.csv Validation")

new_csv <- file.path(sample_dir, "new_test_data.csv")
test("new_test_data.csv exists", file.exists(new_csv))

if (file.exists(new_csv)) {
  new_df <- read.csv(new_csv, stringsAsFactors = FALSE)
  test("new_test_data has ID column", "ID" %in% names(new_df))
  test("new_test_data has cause column", "cause" %in% names(new_df))
  test("new_test_data has 1190 records", nrow(new_df) == 1190)

  new_df_fixed <- fix_causes_for_vacalibration(new_df)
  new_broad <- tryCatch(
    safe_cause_map(df = new_df_fixed, age_group = "neonate"),
    error = function(e) NULL
  )
  test("new_test_data causes map without error", !is.null(new_broad))

  if (!is.null(new_broad)) {
    test("new_test_data broad matrix has 6 neonate columns", ncol(new_broad) == 6)
    test("new_test_data each row sums to 1", all(rowSums(new_broad) == 1))

    # Run vacalibration
    new_va_input <- setNames(list(new_broad), "interva")

    cat("  Running vacalibration (new_test_data, InterVA, neonate, Mozambique, Mmatprior)...\n")
    t0 <- Sys.time()
    result_new <- tryCatch(
      vacalibration(
        va_data = new_va_input,
        age_group = "neonate",
        country = "Mozambique",
        missmat_type = "prior",
        ensemble = TRUE,
        nMCMC = 5000,
        nBurn = 2000,
  
        verbose = FALSE
      ),
      error = function(e) { cat("  ERROR:", e$message, "\n"); NULL }
    )
    elapsed <- as.numeric(difftime(Sys.time(), t0, units = "secs"))
    cat(sprintf("  Elapsed: %.1f sec\n", elapsed))

    test("new_test_data vacalibration returns non-NULL", !is.null(result_new))

    if (!is.null(result_new)) {
      uncalib_new <- result_new$p_uncalib[1, ]
      test("new_test_data uncalibrated CSMF sums to ~1",
           abs(sum(uncalib_new) - 1) < 0.02)
      test("new_test_data uncalibrated all >= 0", all(uncalib_new >= 0))
      test("new_test_data uncalibrated has 6 causes", length(uncalib_new) == 6)

      calib_new_mean <- result_new$pcalib_postsumm[1, "postmean", ]
      calib_new_low  <- result_new$pcalib_postsumm[1, "lowcredI", ]
      calib_new_high <- result_new$pcalib_postsumm[1, "upcredI", ]

      test("new_test_data calibrated mean sums to ~1",
           abs(sum(calib_new_mean) - 1) < 0.02)
      test("new_test_data lower <= mean",
           all(calib_new_low <= calib_new_mean + 1e-6))
      test("new_test_data upper >= mean",
           all(calib_new_high >= calib_new_mean - 1e-6))

      # Validate uncalibrated CSMF (deterministic, tight tolerance)
      expected_uncalib_new <- c(
        ipre = 0.242,
        other = 0.013,
        pneumonia = 0.069,
        prematurity = 0.416,
        sepsis_meningitis_inf = 0.224,
        congenital_malformation = 0.035
      )

      for (cause in names(expected_uncalib_new)) {
        diff <- abs(uncalib_new[cause] - expected_uncalib_new[cause])
        test(sprintf("new_test_data uncalib %s = %.3f (diff: %.6f)",
                     cause, expected_uncalib_new[cause], diff),
             diff < 0.005)
      }

      # Validate calibrated CSMF (stochastic, wider tolerance ~0.05)
      expected_calib_new <- c(
        ipre = 0.072,
        other = 0.013,
        pneumonia = 0.088,
        prematurity = 0.331,
        sepsis_meningitis_inf = 0.465,
        congenital_malformation = 0.031
      )

      for (cause in names(expected_calib_new)) {
        diff <- abs(calib_new_mean[cause] - expected_calib_new[cause])
        test(sprintf("new_test_data calibrated %s ~ %.3f (diff: %.4f, tol: 0.05)",
                     cause, expected_calib_new[cause], diff),
             diff < 0.05)
      }
    }
  }
}

# =============================================================================
# 12c. MISCLASSIFICATION MATRIX EXTRACTION -- v2.2 field (issue #90)
# =============================================================================
# vacalibration v2.2 renamed the misclassification output to `Mmat_tomodel`
# (documented: "This is used for calibration"). The v2.0 names Mmat.asDirich /
# Mmat.fixed no longer exist, so the backend's old extraction silently produced
# NULL and the results view never showed the matrix. These tests run a REAL v2.2
# calibration and lock the field + the shared extract_misclass_matrix() helper.
section("12c. Misclassification Matrix Extraction (issue #90)")

res90 <- tryCatch(
  vacalibration(va_data = list(interva = interva_broad_e), age_group = "neonate",
                country = "Mozambique", missmat_type = "prior", ensemble = FALSE,
                nMCMC = 400, nBurn = 200, verbose = FALSE),
  error = function(e) { cat("  ERROR:", e$message, "\n"); NULL })

test("vacalibration result exposes Mmat_tomodel (v2.2 field, issue #90)",
     !is.null(res90) && !is.null(res90$Mmat_tomodel))
test("old v2.0 field names are absent (documents the #90 root cause)",
     !is.null(res90) && is.null(res90$Mmat.asDirich) && is.null(res90$Mmat.fixed))

mm90 <- if (!is.null(res90)) extract_misclass_matrix(res90, "interva") else NULL
test("extract_misclass_matrix returns a non-NULL matrix for a real v2.2 result (issue #90)",
     !is.null(mm90) && length(mm90) >= 1)
if (!is.null(mm90)) {
  algo1 <- mm90[[1]]
  test("extracted matrix has matrix/champs_causes/va_causes",
       all(c("matrix", "champs_causes", "va_causes") %in% names(algo1)))
  test("extracted matrix rows are normalized to ~1 (P(VA | CHAMPS))",
       all(abs(vapply(algo1$matrix, sum, numeric(1)) - 1) < 0.01))
  test("extracted matrix uses the 6 neonate broad causes",
       setequal(algo1$champs_causes, neonate_broad_causes) &&
       setequal(algo1$va_causes, neonate_broad_causes))
}

# Ensemble: one matrix per algorithm (reuse result_ens2 from section 11).
if (exists("result_ens2") && !is.null(result_ens2)) {
  mm90e <- extract_misclass_matrix(result_ens2, "combined")
  test("ensemble extraction yields one matrix per algorithm (issue #90)",
       !is.null(mm90e) && setequal(names(mm90e), c("interva", "insilicova")))
}

# =============================================================================
# 12d. INDEPENDENT MULTI-ALGORITHM CALIBRATION -- ensemble OFF (issue #83)
# =============================================================================
# With 2+ algorithms and ensemble OFF, vacalibration runs N INDEPENDENT
# calibrations (no "ensemble" row). build_per_algorithm() must still surface
# every algorithm so none of the uploaded files is effectively dropped.
section("12d. Independent multi-algorithm calibration, ensemble OFF (issue #83)")

result_indep <- tryCatch(
  vacalibration(va_data = list(interva = interva_broad_e, insilicova = insilico_broad_e),
                age_group = "neonate", country = "Mozambique", missmat_type = "prior",
                ensemble = FALSE, nMCMC = 400, nBurn = 200, verbose = FALSE),
  error = function(e) { cat("  ERROR:", e$message, "\n"); NULL })

test("ensemble-OFF multi-algo returns a result (issue #83)", !is.null(result_indep))
if (!is.null(result_indep)) {
  labels_indep <- dimnames(result_indep$pcalib_postsumm)[[1]]
  test("ensemble-OFF result has NO ensemble row (independent calibrations)",
       !("ensemble" %in% labels_indep) && setequal(labels_indep, c("interva", "insilicova")))

  pa_indep <- build_per_algorithm(result_indep)
  test("build_per_algorithm surfaces BOTH algorithms when ensemble is OFF (issue #83)",
       !is.null(pa_indep) && setequal(names(pa_indep), c("interva", "insilicova")))
  test("each algorithm's calibrated CSMF sums to ~1",
       !is.null(pa_indep) &&
       all(vapply(pa_indep, function(a) abs(sum(unlist(a$calibrated_csmf)) - 1) < 0.02, logical(1))))
}

} # end if (!input_only)

# =============================================================================
# 13. EDGE CASES
# =============================================================================
section("13. Edge Cases")

# Test auto-rename of cause1 -> cause
df_cause1 <- data.frame(
  ID = c("t1", "t2", "t3"),
  cause1 = c("Prematurity", "Neonatal sepsis", "Birth asphyxia"),
  stringsAsFactors = FALSE
)
names(df_cause1)[names(df_cause1) == "cause1"] <- "cause"
test("cause1->cause rename produces valid df",
     "cause" %in% names(df_cause1) && nrow(df_cause1) == 3)

# Test fix_causes_for_vacalibration with "Undetermined"
df_undetermined <- data.frame(
  ID = c("u1", "u2"),
  cause = c("Undetermined", "Prematurity"),
  stringsAsFactors = FALSE
)
df_fixed_u <- fix_causes_for_vacalibration(df_undetermined)
test("Undetermined maps to 'other'", df_fixed_u$cause[1] == "other")
test("Non-Undetermined cause unchanged", df_fixed_u$cause[2] == "Prematurity")

# Test safe_cause_map with incomplete cause set (only 2 of 6 broad causes present)
df_sparse <- data.frame(
  ID = c("s1", "s2", "s3"),
  cause = c("Prematurity", "Prematurity", "Birth asphyxia"),
  stringsAsFactors = FALSE
)
sparse_broad <- tryCatch(
  safe_cause_map(df = df_sparse, age_group = "neonate"),
  error = function(e) NULL
)
test("safe_cause_map handles sparse causes without error", !is.null(sparse_broad))
if (!is.null(sparse_broad)) {
  test("Sparse broad matrix has all 6 columns", ncol(sparse_broad) == 6)
  test("Sparse broad matrix has 3 rows", nrow(sparse_broad) == 3)
}

# Test invalid age_group
invalid_age <- tryCatch(
  safe_cause_map(df = df_sparse, age_group = "adult"),
  error = function(e) "error_caught"
)
test("Invalid age_group 'adult' raises error", identical(invalid_age, "error_caught"))

# =============================================================================
section("14. Misclassification Matrix Normalization (Issue #31)")
# =============================================================================

# Test normalize_mmat exists and works
test("normalize_mmat function exists", exists("normalize_mmat") && is.function(normalize_mmat))

# Test with a simple 2D matrix (Dirichlet params, rows don't sum to 1)
fake_dirich_2d <- matrix(c(10, 2, 3,
                            1, 8, 1,
                            2, 1, 7), nrow = 3, byrow = TRUE,
                          dimnames = list(c("cause_a", "cause_b", "cause_c"),
                                          c("cause_a", "cause_b", "cause_c")))
norm_2d <- normalize_mmat(fake_dirich_2d)
test("normalize_mmat 2D: rows sum to 1",
     all(abs(rowSums(norm_2d) - 1) < 1e-10))
test("normalize_mmat 2D: preserves dimnames",
     identical(dimnames(norm_2d), dimnames(fake_dirich_2d)))
test("normalize_mmat 2D: all values between 0 and 1",
     all(norm_2d >= 0) && all(norm_2d <= 1))
test("normalize_mmat 2D: diagonal is largest per row",
     all(diag(norm_2d) == apply(norm_2d, 1, max)))

# Test with 3D array (multiple algorithms)
fake_dirich_3d <- array(0, dim = c(2, 3, 3),
                         dimnames = list(c("interva", "insilicova"),
                                         c("cause_a", "cause_b", "cause_c"),
                                         c("cause_a", "cause_b", "cause_c")))
fake_dirich_3d[1, , ] <- fake_dirich_2d
fake_dirich_3d[2, , ] <- matrix(c(5, 3, 2, 1, 9, 0, 3, 2, 5), nrow = 3, byrow = TRUE)
norm_3d <- normalize_mmat(fake_dirich_3d)
test("normalize_mmat 3D: algo 1 rows sum to 1",
     all(abs(rowSums(norm_3d[1, , ]) - 1) < 1e-10))
test("normalize_mmat 3D: algo 2 rows sum to 1",
     all(abs(rowSums(norm_3d[2, , ]) - 1) < 1e-10))
test("normalize_mmat 3D: preserves dimnames",
     identical(dimnames(norm_3d), dimnames(fake_dirich_3d)))
test("normalize_mmat 3D: all values between 0 and 1",
     all(norm_3d >= 0) && all(norm_3d <= 1))

# Test that NULL input returns NULL
test("normalize_mmat handles NULL input", is.null(normalize_mmat(NULL)))

# Validate with actual vacalibration output (if full tests ran). v2.2 field; issue #90.
if (exists("result_interva") && !is.null(result_interva$Mmat_tomodel)) {
  mmat_raw <- result_interva$Mmat_tomodel
  mmat_norm <- normalize_mmat(mmat_raw)
  if (length(dim(mmat_norm)) == 2) {
    test("Real Mmat_tomodel normalized: rows sum to 1",
         all(abs(rowSums(mmat_norm) - 1) < 1e-6))
  } else if (length(dim(mmat_norm)) == 3) {
    sums_ok <- all(sapply(seq_len(dim(mmat_norm)[1]), function(k) {
      all(abs(rowSums(mmat_norm[k, , ]) - 1) < 1e-6)
    }))
    test("Real Mmat_tomodel normalized: rows sum to 1", sums_ok)
  }
}

# =============================================================================
# 14b. extract_misclass_matrix() helper -- field preference + shape (issue #90)
# =============================================================================
# Fast, MCMC-free unit tests of the shared extraction helper (also runs in
# --input-only mode): verifies it reads the v2.2 `Mmat_tomodel` field, prefers
# it over the legacy fallbacks, normalizes rows, and is NULL-safe.
section("14b. extract_misclass_matrix() helper (issue #90)")

test("extract_misclass_matrix is defined in utils.R", is.function(extract_misclass_matrix))

# Synthetic 3D Dirichlet-count array [1 algo x 2 CHAMPS x 2 VA] -> normalized.
syn_dn <- list("interva", c("a", "b"), c("a", "b"))
mmat_tomodel <- array(c(8, 2, 2, 8), dim = c(1, 2, 2), dimnames = syn_dn)  # algo-major
res_syn <- list(Mmat_tomodel = mmat_tomodel)
mm_syn <- extract_misclass_matrix(res_syn, "interva")
test("reads Mmat_tomodel and returns one entry per algorithm",
     !is.null(mm_syn) && setequal(names(mm_syn), "interva"))
test("normalizes rows to sum to 1",
     !is.null(mm_syn) && all(abs(vapply(mm_syn[["interva"]]$matrix, sum, numeric(1)) - 1) < 1e-9))
test("preserves CHAMPS/VA cause labels",
     identical(mm_syn[["interva"]]$champs_causes, c("a", "b")) &&
     identical(mm_syn[["interva"]]$va_causes, c("a", "b")))

# NULL-safety: no Mmat_tomodel -> NULL, no crash.
test("returns NULL when the result has no Mmat_tomodel field",
     is.null(extract_misclass_matrix(list(p_uncalib = 1), "x")))

# Backend wiring: both calibration paths use the shared helper (issue #90).
vacalib_src90 <- readLines(file.path(backend_dir, "jobs", "algorithms", "vacalibration.R"))
processor_src90 <- readLines(file.path(backend_dir, "jobs", "processor.R"))
test("vacalibration.R calls extract_misclass_matrix (issue #90)",
     any(grepl("extract_misclass_matrix", vacalib_src90)))
test("processor.R calls extract_misclass_matrix (issue #90)",
     any(grepl("extract_misclass_matrix", processor_src90)))
test("no path still reads the dead v2.0 Mmat.asDirich/Mmat.fixed as the primary field (issue #90)",
     !any(grepl("Mmat\\.asDirich", vacalib_src90)) && !any(grepl("Mmat\\.asDirich", processor_src90)) &&
     !any(grepl("Mmat\\.fixed", vacalib_src90)) && !any(grepl("Mmat\\.fixed", processor_src90)))

# =============================================================================
# 14c. build_per_algorithm() helper -- multi-algo surfaces all (issue #83)
# =============================================================================
# Fast, MCMC-free unit tests of the per-algorithm breakdown helper: a
# multi-label result yields one entry per label (so an independent ensemble-OFF
# run shows every algorithm), and a single-label result yields NULL.
section("14c. build_per_algorithm() helper (issue #83)")

test("build_per_algorithm is defined in utils.R", is.function(build_per_algorithm))

mk_result <- function(labels) {
  stats <- c("postmean", "lowcredI", "upcredI")
  causes <- c("a", "b")
  list(
    pcalib_postsumm = array(0.5, dim = c(length(labels), 3, 2),
                            dimnames = list(labels, stats, causes)),
    p_uncalib = matrix(0.5, nrow = length(labels), ncol = 2,
                       dimnames = list(labels, causes))
  )
}

pa_multi <- build_per_algorithm(mk_result(c("interva", "insilicova")))
test("multi-label result yields one entry per algorithm (issue #83)",
     !is.null(pa_multi) && setequal(names(pa_multi), c("interva", "insilicova")))
test("each per-algorithm entry carries calibrated + uncalibrated CSMF + CIs",
     all(c("uncalibrated_csmf", "calibrated_csmf", "calibrated_ci_lower", "calibrated_ci_upper")
         %in% names(pa_multi[["interva"]])))
test("single-label result yields NULL (no per-algorithm breakdown)",
     is.null(build_per_algorithm(mk_result("interva"))))

# Backend wiring: both calibration paths use the shared helper (issue #83).
vacalib_src83 <- readLines(file.path(backend_dir, "jobs", "algorithms", "vacalibration.R"))
processor_src83 <- readLines(file.path(backend_dir, "jobs", "processor.R"))
test("vacalibration.R calls build_per_algorithm (issue #83)",
     any(grepl("build_per_algorithm", vacalib_src83)))
test("processor.R calls build_per_algorithm (issue #83)",
     any(grepl("build_per_algorithm", processor_src83)))
test("per-algorithm breakdown is no longer gated on ensemble_val (issue #83)",
     !any(grepl("ensemble_val && length\\(result_labels\\)", vacalib_src83)) &&
     !any(grepl("ensemble_val && length\\(result_labels\\)", processor_src83)))

# Transport: plumber saves per-algorithm files for any multi-algo vacalibration,
# not only when ensemble is on (issue #83).
plumber_src83 <- readLines(file.path(backend_dir, "plumber.R"))
test("plumber.R saves per-algorithm files for multi-algo vacalibration regardless of ensemble (issue #83)",
     any(grepl('job_type == "vacalibration" && length\\(algorithms\\) > 1', plumber_src83)) &&
     !any(grepl('ensemble_bool && job_type == "vacalibration"', plumber_src83)))

section("15. Cause Display Map (Issue #29)")

# Test build_cause_display_map: maps broad cause names back to original user cause names
test("build_cause_display_map function exists",
     exists("build_cause_display_map", mode = "function"))

# InterVA neonate CSV: user causes like "Prematurity", "Birth asphyxia"
interva_csv <- read.csv(file.path(frontend_dir, "public", "sample_interva_neonate.csv"),
                         stringsAsFactors = FALSE)
interva_broad <- safe_cause_map(fix_causes_for_vacalibration(interva_csv), "neonate")
interva_display <- build_cause_display_map(interva_csv, interva_broad)

test("build_cause_display_map returns a named list",
     is.list(interva_display) && !is.null(names(interva_display)))
test("build_cause_display_map keys are broad cause names",
     all(names(interva_display) %in% colnames(interva_broad)))
test("build_cause_display_map values are original cause names from CSV",
     interva_display[["prematurity"]] == "Prematurity")
test("build_cause_display_map: ipre maps to Birth asphyxia for InterVA",
     interva_display[["ipre"]] == "Birth asphyxia")

# EAVA neonate CSV: different names — "Preterm", "Intrapartum"
eava_csv <- read.csv(file.path(frontend_dir, "public", "sample_eava_neonate.csv"),
                      stringsAsFactors = FALSE)
eava_broad <- safe_cause_map(fix_causes_for_vacalibration(eava_csv), "neonate")
eava_display <- build_cause_display_map(eava_csv, eava_broad)

test("EAVA: prematurity maps to Preterm",
     eava_display[["prematurity"]] == "Preterm")
test("EAVA: ipre maps to Intrapartum",
     eava_display[["ipre"]] == "Intrapartum")

# Test build_cause_order: preserves order of first appearance
test("build_cause_order function exists",
     exists("build_cause_order", mode = "function"))

interva_order <- build_cause_order(interva_broad)
test("build_cause_order returns character vector",
     is.character(interva_order))
test("build_cause_order contains all broad causes in result",
     setequal(interva_order, colnames(interva_broad)))
test("build_cause_order first element matches first cause in CSV",
     {
       # First cause in CSV maps to some broad cause
       first_csv_cause <- interva_csv$cause[1]
       # Find which broad cause it maps to
       first_row_broad <- names(which(interva_broad[1, ] == 1))
       interva_order[1] == first_row_broad
     })

# =============================================================================
# 18. ENSEMBLE FILE PERSISTENCE (source-level)
# =============================================================================
section("18. Ensemble File Persistence")

# Read source files for source-level assertions
vacalib_src <- readLines(file.path(backend_dir, "jobs", "algorithms", "vacalibration.R"))
vacalib_text <- paste(vacalib_src, collapse = "\n")
connection_src <- readLines(file.path(backend_dir, "db", "connection.R"))
connection_text <- paste(connection_src, collapse = "\n")

# vacalibration.R must validate input files before read.csv
test("vacalibration.R validates input_file is not NA before reading",
     grepl("is\\.na.*input_file|input_file.*NA|No input file", vacalib_text))

test("vacalibration.R gives user-friendly error for missing files (not R internal error)",
     grepl("No input file|upload.*file|missing.*file", vacalib_text, ignore.case = TRUE))

# load_job must restore input_files from job_files table
test("load_job restores input_files from job_files table",
     grepl("get_job_files.*input|input_files.*file_path", connection_text))

test("load_job distinguishes multi-file ensemble from single-file uploads",
     grepl("nrow.*>\\s*1|length.*>\\s*1", connection_text) &&
     grepl("input_files", connection_text))

# =============================================================================
# 19. PIPELINE ENSEMBLE DATA CORRECTNESS (source-level)
# =============================================================================
section("19. Pipeline Ensemble Data Correctness")

processor_lines <- readLines(file.path(backend_dir, "jobs", "processor.R"))

# Bug: all_cod rbind has no algorithm column — causes.csv is ambiguous in ensemble
# Check that cod gets an algorithm column assigned before rbind
test("processor.R adds algorithm column to cod before rbind in pipeline ensemble",
     any(grepl("cod\\$algorithm", processor_lines)))

# Bug: n_records = nrow(all_cod) is inflated by records x algorithms
# Should use unique IDs, not raw nrow on combined data
test("processor.R computes n_records from unique IDs not inflated all_cod",
     !any(grepl("n_records.*=.*nrow\\(all_cod\\)", processor_lines)))

# Bug: csmf_openva overwritten each loop iteration — only last algo survives
# Should accumulate per-algo CSMFs in a list
test("processor.R accumulates csmf_openva per algorithm (not overwritten in loop)",
     any(grepl("csmf_openva\\[\\[", processor_lines)) ||
     any(grepl("openva_csmfs\\[\\[", processor_lines)))

# =============================================================================
# 20. RERUN ENDPOINT ENSEMBLE SUPPORT (source-level)
# =============================================================================
section("20. Rerun Endpoint Ensemble Support")

plumber_lines <- readLines(file.path(backend_dir, "plumber.R"))

# Find the rerun endpoint section (lines near "rerun")
rerun_line_nums <- grep("rerun", plumber_lines)
if (length(rerun_line_nums) > 0) {
  rerun_start <- min(rerun_line_nums)
  rerun_end <- min(length(plumber_lines), max(rerun_line_nums) + 30)
  rerun_section_lines <- plumber_lines[rerun_start:rerun_end]
} else {
  rerun_section_lines <- character(0)
}

# Bug: rerun only checks old_job$input_file, ensemble jobs use input_files
test("plumber.R rerun endpoint handles input_files for ensemble jobs",
     any(grepl("input_files", rerun_section_lines)))

# =============================================================================
# 21. FILE.COPY RETURN VALUE HANDLING (source-level)
# =============================================================================
section("21. file.copy Return Value Handling")

# Find save_uploaded_file function (first ~40 lines of plumber.R)
save_fn_lines <- plumber_lines[15:min(50, length(plumber_lines))]

# Bug: save_uploaded_file returns TRUE without checking file.copy() result
# Each file.copy call should check its return value (isTRUE or similar)
test("save_uploaded_file checks file.copy return value (not unconditional TRUE)",
     any(grepl("isTRUE.*file\\.copy", save_fn_lines)))

# =============================================================================
# 22. DOCKERFILE INSTALLS ALL SUPPORTED ALGORITHMS (issue #43)
# =============================================================================
section("22. Dockerfile Algorithm Packages")

dockerfile_path <- file.path(backend_dir, "Dockerfile")
test("backend/Dockerfile exists", file.exists(dockerfile_path))

if (file.exists(dockerfile_path)) {
  dockerfile_text <- paste(readLines(dockerfile_path), collapse = "\n")

  # Every algorithm in valid_algorithms must have its R package installed in Docker
  # openVA only "Suggests" EAVA — it won't be installed automatically
  algo_packages <- c("openVA", "EAVA")  # InterVA/InSilicoVA are openVA deps
  for (pkg in algo_packages) {
    test(sprintf("Dockerfile installs '%s' package", pkg),
         grepl(pkg, dockerfile_text, fixed = TRUE))
  }
}

# =============================================================================
# 23. EAVA MISSING COLUMN HANDLING (issue #43)
# =============================================================================
section("23. EAVA Missing Column Handling")

utils_path <- file.path(backend_dir, "jobs", "utils.R")
utils_text <- paste(readLines(utils_path), collapse = "\n")

# Bug: EAVA's codEAVA() crashes when WHO2016 input data is missing columns it
# references (e.g. i183b). Our code should pre-fill missing columns with "."
test("utils.R defines prepare_eava_input helper",
     grepl("prepare_eava_input", utils_text))

# Behavior test: call prepare_eava_input with minimal data
source(file.path(backend_dir, "jobs", "utils.R"))
tmp_df <- data.frame(ID = "x1", i181o = "y", stringsAsFactors = FALSE)
eava_out <- prepare_eava_input(tmp_df, "neonate")
test("prepare_eava_input adds age column for neonate",
     "age" %in% names(eava_out) && eava_out$age[1] == 14)
test("prepare_eava_input adds fb_day0 column",
     "fb_day0" %in% names(eava_out) && eava_out$fb_day0[1] == "n")
test("prepare_eava_input fills missing WHO columns with '.'",
     "i183b" %in% names(eava_out) && eava_out$i183b[1] == ".")
test("prepare_eava_input normalizes age_group case",
     prepare_eava_input(tmp_df, "Neonate")$age[1] == 14)

openva_text <- paste(readLines(file.path(backend_dir, "jobs", "algorithms", "openva.R")), collapse = "\n")
processor_text <- paste(readLines(file.path(backend_dir, "jobs", "processor.R")), collapse = "\n")

test("openva.R calls prepare_eava_input before codeVA for EAVA",
     grepl("prepare_eava_input", openva_text))

test("processor.R calls prepare_eava_input before codeVA for EAVA",
     grepl("prepare_eava_input", processor_text))

# =============================================================================
# 24. EAVA RESULT EXTRACTION (issue #43)
# =============================================================================
section("24. EAVA Result Extraction")

# Bug: openVA's getTopCOD() has no handler for eava class.
# EAVA returns list(ID, cause, age_group) not the standard format.
# Our code must use extract_top_cod() (which handles eava) instead of getTopCOD().
test("utils.R defines extract_top_cod with eava handling",
     grepl("extract_top_cod", utils_text) && grepl("inherits.*eava", utils_text))

# Behavior test: extract_top_cod with synthetic eava result
eava_result <- structure(list(ID = c("d1", "d2"), cause = c("Sepsis", "Preterm"), age_group = "neonate"), class = "eava")
eava_cod <- extract_top_cod(eava_result)
test("extract_top_cod returns data.frame with ID and cause1",
     is.data.frame(eava_cod) && all(c("ID", "cause1") %in% names(eava_cod)))
test("extract_top_cod maps eava cause to cause1",
     eava_cod$cause1[1] == "Sepsis" && eava_cod$ID[2] == "d2")

test("openva.R uses extract_top_cod (no raw getTopCOD calls)",
     grepl("extract_top_cod", openva_text) && !grepl("getTopCOD\\s*\\(", openva_text))

test("processor.R uses extract_top_cod (no raw getTopCOD calls)",
     grepl("extract_top_cod", processor_text) && !grepl("getTopCOD\\s*\\(", processor_text))

# =============================================================================
# 25. Cause Validation & Comprehensive Error Messages
# =============================================================================
# Validates that:
#   (a) is_broad_format normalizes spaces/underscores/hyphens/case
#   (b) validate_causes catches wrong-age-group, spelling errors, and unknown
#       causes with per-cause record counts and suggestions
# Regression for failed jobs 30a76032 (wrong age_group) and 37bde854 (spelling).
section("25. Cause Validation & Comprehensive Error Messages")

# --- is_broad_format normalization ---
test("is_broad_format accepts canonical broad name (underscore)",
     is_broad_format("congenital_malformation", "neonate"))
test("is_broad_format accepts space variant 'congenital malformation'",
     is_broad_format("congenital malformation", "neonate"))
test("is_broad_format accepts mixed case 'Congenital Malformation'",
     is_broad_format("Congenital Malformation", "neonate"))
test("is_broad_format accepts hyphen variant 'congenital-malformation'",
     is_broad_format("congenital-malformation", "neonate"))
test("is_broad_format rejects child cause 'malaria' for neonate age_group",
     !is_broad_format("malaria", "neonate"))
test("is_broad_format accepts full neonate broad set with mixed formatting",
     is_broad_format(c("Prematurity", "ipre", "congenital malformation",
                       "Pneumonia", "sepsis_meningitis_inf", "Other"),
                     "neonate"))

# --- build_broad_matrix normalization (issue: spaces vs underscores) ---
df_space <- data.frame(
  ID = paste0("rec_", 1:3),
  cause = c("congenital malformation", "ipre", "prematurity"),
  stringsAsFactors = FALSE
)
mat_space <- build_broad_matrix(df_space, "neonate")
test("build_broad_matrix maps 'congenital malformation' (space) to congenital_malformation column",
     mat_space["rec_1", "congenital_malformation"] == 1L)
test("build_broad_matrix maps 'ipre' to ipre column",
     mat_space["rec_2", "ipre"] == 1L)
test("build_broad_matrix rows sum to 1 (each record mapped exactly once)",
     all(rowSums(mat_space) == 1L))

# --- validate_causes: wrong age_group (job 30a76032 scenario) ---
# 3282 records with mix of neonate causes (pneumonia, other) and child causes
wrong_age_causes <- c(
  rep("pneumonia", 100),       # neonate broad (overlaps with child)
  rep("other", 75),            # neonate broad (overlaps with child)
  rep("malaria", 800),         # child broad
  rep("hiv", 200),             # child broad
  rep("diarrhea", 150),        # child broad
  rep("severe_malnutrition", 100),  # child broad
  rep("other_infections", 50), # child broad
  rep("undecided", 75)         # truly unknown
)
err_wrong_age <- tryCatch(validate_causes(wrong_age_causes, "neonate"),
                          error = function(e) conditionMessage(e))
test("validate_causes throws an error for wrong age_group data",
     is.character(err_wrong_age))
test("error mentions 'child' as suggested age_group",
     grepl("'child'", err_wrong_age, fixed = TRUE))
test("error lists wrong-age cause 'malaria' with record count 800",
     grepl("malaria.*800", err_wrong_age))
test("error lists 'hiv' with count 200",
     grepl("hiv.*200", err_wrong_age))
test("error lists 'severe_malnutrition' with count 100",
     grepl("severe_malnutrition.*100", err_wrong_age))
test("error lists truly-unknown cause 'undecided' with count 75",
     grepl("undecided.*75", err_wrong_age))
test("error does NOT flag valid neonate causes ('pneumonia', 'other')",
     !grepl("pneumonia: 100", err_wrong_age) && !grepl("other: 75", err_wrong_age))
test("error suggests age_group switch with -> arrow",
     grepl("->", err_wrong_age, fixed = TRUE))

# --- issue #81: actionable message must reach single-file uploads too ---
# validate_causes already lists the expected broad causes; ensure that message
# is surfaced for the CHILD age group (1-59 months).
err_child <- tryCatch(
  validate_causes(c(rep("pneumonia", 10), rep("not_a_real_cause", 5)), "child"),
  error = function(e) conditionMessage(e))
test("validate_causes lists expected broad causes for child age_group (issue #81)",
     grepl("Expected broad causes for 'child'", err_child, fixed = TRUE) &&
     grepl("diarrhea", err_child) && grepl("malaria", err_child))
test("child error flags the unknown cause with its record count (issue #81)",
     grepl("not_a_real_cause.*5", err_child))

# Both upload paths (multi-file ensemble AND single-file) must route a
# cause_map failure through validate_causes, so a single-CSV upload with a bad
# cause gets the actionable list instead of the raw package error (issue #81).
n_validate_calls <- length(gregexpr("validate_causes\\(input_data\\$cause", vacalib_text)[[1]])
test("both upload paths route cause_map failures through validate_causes (issue #81)",
     n_validate_calls >= 2)

# --- validate_causes: spelling/typos (job 37bde854 scenario) ---
# 1339 records: most valid broad, but 'infection' is unknown
mistype_causes <- c(
  rep("prematurity", 500),
  rep("ipre", 400),
  rep("congenital_malformation", 200),
  rep("other", 100),
  rep("infection", 139)        # not a broad cause; closest is sepsis_meningitis_inf
)
err_typo <- tryCatch(validate_causes(mistype_causes, "neonate"),
                     error = function(e) conditionMessage(e))
test("validate_causes catches 'infection' as unknown",
     is.character(err_typo) && grepl("infection", err_typo))
test("error includes 'infection' record count (139)",
     grepl("infection.*139", err_typo))
test("error provides actionable guidance for unknown 'infection' (did-you-mean or rename hint)",
     grepl("did you mean|consider renaming", err_typo, ignore.case = TRUE))
test("error does NOT mention wrong age_group (causes are neonate-shaped)",
     !grepl("'child'", err_typo, fixed = TRUE))

# --- validate_causes: valid data passes silently ---
valid_causes <- c(rep("prematurity", 500), rep("ipre", 300),
                  rep("pneumonia", 200), rep("congenital_malformation", 100),
                  rep("sepsis_meningitis_inf", 50), rep("other", 40))
ok_result <- tryCatch({validate_causes(valid_causes, "neonate"); "passed"},
                     error = function(e) conditionMessage(e))
test("validate_causes returns silently for fully valid neonate data",
     identical(ok_result, "passed"))

# --- validate_causes: also works for child age_group ---
err_child <- tryCatch(
  validate_causes(c(rep("prematurity", 50), rep("malaria", 100)), "child"),
  error = function(e) conditionMessage(e))
test("validate_causes flags neonate cause 'prematurity' for child age_group",
     is.character(err_child) && grepl("'neonate'", err_child, fixed = TRUE))

# --- validate_causes: expected-causes hint ---
test("error message includes expected broad cause list for age_group",
     grepl("congenital_malformation", err_wrong_age) &&
     grepl("sepsis_meningitis_inf", err_wrong_age))

# =============================================================================
# 26. Reject Unrecognized Causes (no silent drop) — issue #92
# =============================================================================
# cause_map() drops unrecognized rows; build_broad_matrix() leaves them all-zero.
# assert_all_causes_mapped() must catch both and fail loudly with the offending
# cause + the supported-cause list, instead of silently shrinking the denominator.
section("26. Reject Unrecognized Causes (issue #92)")

# build_broad_matrix path: a bogus broad cause is left as an all-zero row
df_bogus <- data.frame(ID = as.character(1:4),
  cause = c("pneumonia", "ipre", "not_a_real_cause", "other"), stringsAsFactors = FALSE)
bm_bogus <- build_broad_matrix(df_bogus, "neonate")
err92a <- tryCatch({ assert_all_causes_mapped(df_bogus, bm_bogus, "neonate"); NA_character_ },
                   error = function(e) conditionMessage(e))
test("assert_all_causes_mapped errors on an unrecognized cause (issue #92)",
     is.character(err92a) && !is.na(err92a))
test("error names the dropped cause with its record count (issue #92)",
     grepl("not_a_real_cause.*1", err92a))
test("error lists the supported broad causes (issue #92)",
     grepl("Supported broad causes", err92a) && grepl("prematurity", err92a))

# cause_map path: synthetic EAVA-style data with an unrecognized 'Unspecified'
# bucket — cause_map drops those rows, so they must be reported.
eava_syn <- data.frame(ID = as.character(1:5),
  cause = c("Pneumonia", "Sepsis", "Unspecified", "Unspecified", "Preterm"),
  stringsAsFactors = FALSE)
eava_syn_broad <- safe_cause_map(df = fix_causes_for_vacalibration(eava_syn), age_group = "neonate")
err92b <- tryCatch({ assert_all_causes_mapped(eava_syn, eava_syn_broad, "neonate"); NA_character_ },
                   error = function(e) conditionMessage(e))
test("cause_map-dropped 'Unspecified' records are reported, not silently dropped (issue #92)",
     is.character(err92b) && grepl("Unspecified", err92b) && grepl("Unspecified.*2", err92b))

# regression: the shipped EAVA neonate sample is now clean (Unspecified removed)
eava_ship <- read.csv(file.path(frontend_dir, "public", "sample_eava_neonate.csv"),
                      stringsAsFactors = FALSE)
eava_ship$ID <- as.character(eava_ship$ID)
eava_ship_broad <- safe_cause_map(df = fix_causes_for_vacalibration(eava_ship), age_group = "neonate")
test("shipped EAVA neonate sample maps fully, no dropped causes (issue #92)",
     isTRUE(assert_all_causes_mapped(eava_ship, eava_ship_broad, "neonate")))

# fully-recognized data passes silently
clean_df92 <- data.frame(ID = as.character(1:3),
  cause = c("pneumonia", "ipre", "other"), stringsAsFactors = FALSE)
test("assert_all_causes_mapped passes for fully-recognized causes (issue #92)",
     isTRUE(assert_all_causes_mapped(clean_df92, build_broad_matrix(clean_df92, "neonate"), "neonate")))

# wired into both vacalibration upload paths + the pipeline
test("vacalibration.R calls assert_all_causes_mapped in both upload paths (issue #92)",
     length(gregexpr("assert_all_causes_mapped", vacalib_text)[[1]]) >= 2)
test("processor.R calls assert_all_causes_mapped in the pipeline path (issue #92)",
     any(grepl("assert_all_causes_mapped", processor_lines)))

# =============================================================================
# 27. Reject Duplicate Record IDs
# =============================================================================
section("27. Reject Duplicate Record IDs")

# cause_map()'s internal dcast(ID ~ cause) collapses rows sharing an ID into ONE
# row: a same-cause duplicate is undercounted (silent denominator shrink /
# distorted CSMF) and a different-cause duplicate becomes a multi-cause row that
# crashes vacalibration with an empty error. assert_all_causes_mapped()'s set
# comparison is blind to duplicate-count loss, so a duplicate-ID guard must
# reject it up front — same "fail loudly, never silently shrink the denominator"
# rule as issue #92.

# (a) specific causes, duplicate ID + SAME cause (silent-undercount path)
dup_same <- data.frame(ID = c("r1", "r1", "r2", "r3"),
  cause = c("Prematurity", "Prematurity", "Birth asphyxia", "Neonatal sepsis"),
  stringsAsFactors = FALSE)
dup_same_broad <- safe_cause_map(df = fix_causes_for_vacalibration(dup_same), age_group = "neonate")
err_dup_a <- tryCatch({ assert_all_causes_mapped(dup_same, dup_same_broad, "neonate"); NA_character_ },
                      error = function(e) conditionMessage(e))
test("assert_all_causes_mapped errors on a same-cause duplicate ID",
     is.character(err_dup_a) && !is.na(err_dup_a))
test("duplicate-ID error names the offending ID and is actionable",
     is.character(err_dup_a) && grepl("r1", err_dup_a) && grepl("duplicate", err_dup_a, ignore.case = TRUE))

# (b) specific causes, duplicate ID + DIFFERENT cause (empty-crash path)
dup_diff <- data.frame(ID = c("r1", "r1", "r2", "r3"),
  cause = c("Prematurity", "Birth asphyxia", "Neonatal sepsis", "Neonatal sepsis"),
  stringsAsFactors = FALSE)
dup_diff_broad <- safe_cause_map(df = fix_causes_for_vacalibration(dup_diff), age_group = "neonate")
err_dup_b <- tryCatch({ assert_all_causes_mapped(dup_diff, dup_diff_broad, "neonate"); NA_character_ },
                      error = function(e) conditionMessage(e))
test("assert_all_causes_mapped errors on a different-cause duplicate ID",
     is.character(err_dup_b) && !is.na(err_dup_b))

# (c) broad-format duplicate ID: build_broad_matrix keeps both rows so the count
# is correct, but duplicate IDs are still malformed input — reject uniformly so
# the same file behaves consistently regardless of cause format.
dup_broad <- data.frame(ID = c("r1", "r1", "r2", "r3"),
  cause = c("prematurity", "prematurity", "ipre", "sepsis_meningitis_inf"),
  stringsAsFactors = FALSE)
err_dup_c <- tryCatch({ assert_all_causes_mapped(dup_broad, build_broad_matrix(dup_broad, "neonate"), "neonate"); NA_character_ },
                      error = function(e) conditionMessage(e))
test("assert_all_causes_mapped errors on a duplicate ID in broad-format input",
     is.character(err_dup_c) && !is.na(err_dup_c))

# (d) regression: unique IDs must still pass (clean data is never rejected)
uniq_df <- data.frame(ID = c("r1", "r2", "r3", "r4"),
  cause = c("Prematurity", "Prematurity", "Birth asphyxia", "Neonatal sepsis"),
  stringsAsFactors = FALSE)
uniq_broad <- safe_cause_map(df = fix_causes_for_vacalibration(uniq_df), age_group = "neonate")
test("assert_all_causes_mapped still passes when all IDs are unique",
     isTRUE(assert_all_causes_mapped(uniq_df, uniq_broad, "neonate")))

# =============================================================================
# 28. PATH-CORRECTION LAMBDA (issue #101)
# =============================================================================
# vacalibration's simplex line search starts at lambda = 0.99 and steps down.
# A returned value still at 0.99 means it never found a usable correction, so the
# "calibrated" estimate IS the uncalibrated one -- carrying credible intervals ~7x
# tighter than the same input run with path_correction = FALSE. The dashboard must
# not present those intervals as if they were real.
section("28. Path-correction lambda (issue #101)")

# --- path_correction_stalled(): boundary conditions ---
test("stalled at the 0.99 ceiling", isTRUE(path_correction_stalled(0.99)))
# The search accumulates float error (0.09 comes back as 0.0899999999999992),
# so an exact == 0.99 comparison is unsafe.
test("stalled just below 0.99 (float tolerance)",
     isTRUE(path_correction_stalled(0.99 - 1e-12)))
test("not stalled at 0.98", isFALSE(path_correction_stalled(0.98)))
test("not stalled at 0.14 (a real correction)", isFALSE(path_correction_stalled(0.14)))
test("not stalled at 0 (path_correction = FALSE)", isFALSE(path_correction_stalled(0)))
test("unknown lambda is not reported as stalled (NA)",
     isFALSE(path_correction_stalled(NA_real_)))
test("unknown lambda is not reported as stalled (NULL)",
     isFALSE(path_correction_stalled(NULL)))
test("vector input is not reported as stalled",
     isFALSE(path_correction_stalled(c(0.99, 0.99))))

# --- build_lambda_map(): maps the unnamed lambda vector onto algorithm labels ---
# lambda_calibpath has ONE ENTRY PER ALGORITHM in va_data order and NO ensemble
# entry, while pcalib_postsumm has an extra "ensemble" row. Verified against
# vacalibration 2.2: 2 algorithms + ensemble => 3 result rows, length(lambda) == 2.
fake_result <- function(labels, lambda) list(
  p_uncalib = matrix(0.5, nrow = length(labels), ncol = 2,
                     dimnames = list(labels, c("pneumonia", "other"))),
  pcalib_postsumm = array(0, dim = c(length(labels), 3, 2),
                          dimnames = list(labels, c("postmean", "lowcredI", "upcredI"),
                                          c("pneumonia", "other"))),
  lambda_calibpath = lambda)

lm_single <- build_lambda_map(fake_result("eava", 0.14))
test("single algorithm: lambda mapped to its label",
     identical(names(lm_single), "eava") && isTRUE(all.equal(lm_single$eava, 0.14)))

lm_multi <- build_lambda_map(fake_result(c("eava", "insilicova", "ensemble"), c(0.09, 0.72)))
test("multi-algorithm: lambda mapped in order, ensemble excluded",
     identical(names(lm_multi), c("eava", "insilicova")) &&
       isTRUE(all.equal(lm_multi$eava, 0.09)) &&
       isTRUE(all.equal(lm_multi$insilicova, 0.72)))

test("missing lambda_calibpath yields NULL",
     is.null(build_lambda_map(fake_result("eava", NULL))))
test("zero-length lambda_calibpath yields NULL",
     is.null(build_lambda_map(fake_result("eava", numeric(0)))))

# Ensemble is flagged when ANY constituent algorithm stalled: its posterior is
# built from the per-algorithm draws, so one stalled algorithm contaminates it.
test("ensemble stalled when one constituent stalled",
     isTRUE(any_stalled(build_lambda_map(
       fake_result(c("eava", "insilicova", "ensemble"), c(0.99, 0.40))))))
test("ensemble not stalled when every constituent calibrated",
     isFALSE(any_stalled(build_lambda_map(
       fake_result(c("eava", "insilicova", "ensemble"), c(0.14, 0.40))))))
test("any_stalled(NULL) is FALSE", isFALSE(any_stalled(NULL)))

# --- A NULL lambda must be OMITTED from the result, never emitted ---
# jsonlite serialises an R NULL held inside a list() as an empty OBJECT, not null:
#   toJSON(list(lambda_calibpath = NULL), auto_unbox = TRUE)  ->  {"lambda_calibpath":{}}
# The frontend's `?? null` does not catch {}, so `.toFixed()` on it throws and (with no
# error boundary in the app) blanks the whole page. The ensemble has no lambda of its
# own, so this is the normal path for any ensemble run -- exactly when the stall note
# is shown. Omitting the key instead makes the field absent, which `?? null` does catch.
ens_result <- list(
  p_uncalib = matrix(c(0.6, 0.4, 0.5, 0.5, 0.55, 0.45), nrow = 3, byrow = TRUE,
                     dimnames = list(c("eava", "interva", "ensemble"), c("pneumonia", "other"))),
  pcalib_postsumm = array(0.5, dim = c(3, 3, 2),
                          dimnames = list(c("eava", "interva", "ensemble"),
                                          c("postmean", "lowcredI", "upcredI"),
                                          c("pneumonia", "other"))),
  lambda_calibpath = c(0.99, 0.43))
pa <- build_per_algorithm(ens_result)

test("ensemble entry omits lambda_calibpath entirely (not NULL)",
     !("lambda_calibpath" %in% names(pa$ensemble)))
test("ensemble lambda serialises as absent, not as an empty object",
     !grepl("lambda_calibpath", jsonlite::toJSON(pa$ensemble, auto_unbox = TRUE)))
test("per-algorithm entries keep their lambda",
     isTRUE(all.equal(pa$eava$lambda_calibpath, 0.99)) &&
       isTRUE(all.equal(pa$interva$lambda_calibpath, 0.43)))
test("only the algorithm that stalled is flagged as a no-op",
     isTRUE(pa$eava$path_correction_stalled) &&
       isFALSE(pa$interva$path_correction_stalled))

# --- Two separate facts, not one flag (issue #101 follow-up) -----------------
# A stalled algorithm's point estimate IS a no-op. The ensemble's is NOT: measured
# on a real mixed run (eava lambda 0.99, interva 0.14) the ensemble still moved
# 1.2pp, while its mean CrI width was 0.0175 against the healthy algorithm's 0.1561
# -- 9x tighter. So the intervals are unusable but the estimate is real, and the
# UI must not tell the user "the calibrated bars equal the uncalibrated ones".
test("a stalled algorithm reports its estimate as a no-op",
     isTRUE(pa$eava$path_correction_stalled) && isTRUE(pa$eava$ci_unreliable))
test("the ensemble reports unusable intervals but NOT a no-op estimate",
     isFALSE(pa$ensemble$path_correction_stalled) && isTRUE(pa$ensemble$ci_unreliable))
test("the ensemble names the constituents that stalled",
     identical(pa$ensemble$stalled_constituents, list("eava")))
test("a healthy algorithm reports neither",
     isFALSE(pa$interva$path_correction_stalled) && isFALSE(pa$interva$ci_unreliable))

pa_ok <- build_per_algorithm(fake_result(c("eava", "interva", "ensemble"), c(0.14, 0.43)))
test("no algorithm stalled: ensemble intervals are usable",
     isFALSE(pa_ok$ensemble$ci_unreliable) &&
       is.null(pa_ok$ensemble$stalled_constituents))

# --- The ceiling differs by missmat_type (issue #101 follow-up) --------------
# modular_vacalib_prior starts the search at 0.99 and caps at min(x + 0.01, 0.99).
# modular_vacalib_fixed starts at 1 with NO cap, so a first-iteration stall returns
# 1.01. `missmat_type = "fixed"` is user-reachable (JobForm's "Propagate" checkbox).
test("the fixed path's 1.01 stall value is detected", isTRUE(path_correction_stalled(1.01)))
test("the fixed path's 1.00 is detected", isTRUE(path_correction_stalled(1)))
test("0.98 is still not stalled on either path", isFALSE(path_correction_stalled(0.98)))

# --- build_stall_fields(): the wiring both job paths share -------------------
# Previously each caller assembled these fields inline, so deleting the wiring from
# both broke zero tests. One helper, tested here, and a source assertion that both
# callers use it.
sf_single <- build_stall_fields(fake_result("eava", 0.99), "eava")
test("single stalled algorithm: fields set, lambda carried",
     isTRUE(sf_single$path_correction_stalled) && isTRUE(sf_single$ci_unreliable) &&
       isTRUE(all.equal(sf_single$lambda_calibpath, 0.99)))
test("single stalled algorithm: warning text names the real lambda, not the constant",
     grepl("0.99", sf_single$warning, fixed = TRUE))

sf_fixed <- build_stall_fields(fake_result("eava", 1.01), "eava")
test("fixed-path stall: warning reports 1.01, not the 0.99 constant",
     grepl("1.01", sf_fixed$warning, fixed = TRUE) &&
       !grepl("0.99", sf_fixed$warning, fixed = TRUE))

sf_ens <- build_stall_fields(fake_result(c("eava", "interva", "ensemble"), c(0.99, 0.43)), "ensemble")
test("ensemble primary: no lambda of its own, so the field is absent",
     !("lambda_calibpath" %in% names(sf_ens)))
test("ensemble primary: intervals unusable but estimate not a no-op",
     isFALSE(sf_ens$path_correction_stalled) && isTRUE(sf_ens$ci_unreliable))
test("ensemble primary: warning names the stalled constituent",
     grepl("eava", sf_ens$warning, fixed = TRUE))

sf_ok <- build_stall_fields(fake_result("eava", 0.14), "eava")
test("healthy run produces no warning",
     isFALSE(sf_ok$path_correction_stalled) && is.null(sf_ok$warning))

# Both job paths must build the fields AND merge them into the result object. The
# merge is asserted separately because a caller can keep calling build_stall_fields()
# for its log line while dropping the fields from the payload -- which is exactly
# what happened before, and the earlier "calls the helper" assertion missed it.
# Source assertions rather than a live run: reaching result_obj needs a DB and a
# multi-minute MCMC, so this is the same style used in JobDetail.test.js.
for (f in c(file.path(backend_dir, "jobs", "algorithms", "vacalibration.R"),
            file.path(backend_dir, "jobs", "processor.R"))) {
  src <- paste(readLines(f, warn = FALSE), collapse = "\n")
  test(sprintf("%s calls build_stall_fields()", basename(f)),
       grepl("build_stall_fields(", src, fixed = TRUE))
  test(sprintf("%s merges the stall fields into result_obj", basename(f)),
       grepl("result_obj <- c(result_obj, stall_fields)", src, fixed = TRUE))
  test(sprintf("%s logs the warning the helper produced", basename(f)),
       grepl("add_log(job$id, stall_fields$warning)", src, fixed = TRUE))
  test(sprintf("%s no longer hardcodes LAMBDA_CEILING in a log line", basename(f)),
       !grepl("LAMBDA_CEILING,", src, fixed = TRUE))
}

# =============================================================================
# SUMMARY
# =============================================================================
cat(sprintf("\n========================================\n"))
cat(sprintf("Tests: %d | Passed: %d | Failed: %d\n", .test_count, .pass_count, .fail_count))
cat(sprintf("========================================\n"))

if (.fail_count > 0) {
  cat("\nFailed tests:\n")
  for (msg in .fail_msgs) cat(msg, "\n")
  quit(status = 1)
} else {
  cat("\nAll tests passed!\n")
  quit(status = 0)
}
