# =============================================================================
# Misclassification Matrix Tests -- GitHub issue #104 (item 1)
# =============================================================================
# The dashboard's misclassification matrix must equal vacalibration's own
# "Prior Mean of Misclassification Matrix -- Used For Calibration" panel.
#
# vacalibration calibrates only a SUBMATRIX of the broad causes. Causes in
# `donotcalib` (which vacalibration() defaults to "other") are excluded, and
# with `donotcalib_type = "learn"` (the default) it excludes ADDITIONAL causes
# PER ALGORITHM whose misclassification column is near-constant. Its own plot
# subsets to the calibrated causes FIRST, then row-normalizes over that
# submatrix. Normalizing over all causes instead deflates every probability by
# 1 / (1 - excluded mass) and renders rows that are not calibration output.
#
# Pure unit tests: no MCMC, no database, no network. Runs in < 1 second.
#
# Usage:
#   Rscript tests/test_misclass_matrix.R
#
# Run from the project root or backend/. Exit code: 0 = all pass, 1 = failures.

# --- Test helpers (same style as test_vacalibration_backend.R) ---
.test_count <- 0L
.pass_count <- 0L
.fail_count <- 0L
.fail_msgs  <- character()

test <- function(desc, expr) {
  .test_count <<- .test_count + 1L
  tryCatch({
    ok <- eval(expr, envir = parent.frame())
    if (!isTRUE(ok)) stop("assertion returned FALSE")
    .pass_count <<- .pass_count + 1L
    cat(sprintf("  PASS: %s\n", desc))
  }, error = function(e) {
    .fail_count <<- .fail_count + 1L
    msg <- sprintf("  FAIL: %s -- %s", desc, conditionMessage(e))
    .fail_msgs <<- c(.fail_msgs, msg)
    cat(msg, "\n")
  })
}

section <- function(title) cat(sprintf("\n=== %s ===\n", title))

# --- Locate and load the code under test ---
if (file.exists("backend/jobs/utils.R")) {
  utils_path <- "backend/jobs/utils.R"
} else if (file.exists("jobs/utils.R")) {
  utils_path <- "jobs/utils.R"
} else {
  stop("Run this test from the project root or backend/ directory")
}
source(utils_path)

# --- Helpers for building synthetic vacalibration results ---

# A named square misclassification matrix whose rows are deliberately NOT
# normalized, so a missing/incorrect normalization step is visible.
make_slice <- function(causes, diag_weight = 50, off_weight = 10) {
  n <- length(causes)
  m <- matrix(off_weight, nrow = n, ncol = n, dimnames = list(causes, causes))
  diag(m) <- diag_weight
  m
}

# Stack 2D slices into the [algorithm, CHAMPS, VA] array vacalibration returns.
make_array <- function(slices) {
  causes <- colnames(slices[[1]])
  a <- array(NA_real_, dim = c(length(slices), length(causes), length(causes)),
             dimnames = list(names(slices), causes, causes))
  for (k in seq_along(slices)) a[k, , ] <- slices[[k]]
  a
}

# A logical `algorithm x cause` declaration matrix, as both package versions use.
make_donotcalib <- function(algos, causes, excluded) {
  m <- matrix(FALSE, nrow = length(algos), ncol = length(causes),
              dimnames = list(algos, causes))
  for (a in algos) {
    ex <- if (is.list(excluded)) excluded[[a]] else excluded
    if (length(ex)) m[a, ex] <- TRUE
  }
  m
}

# Emitted cells are deliberately rounded to 4 decimals, so a row of up to six
# of them can sum to 1 only within ~3e-4. Assertions on row sums and on exact
# cell values must allow for that; they are NOT a tolerance on the defect
# itself, which is asserted separately against R's panel in section 10.
ROUND_TOL <- 1e-3      # probability scale
ROUND_TOL_PCT <- 0.01  # percentage-point scale

# Row sums of an emitted matrix (list of named numeric rows).
row_sums_of <- function(entry) sapply(entry$matrix, sum)

# Percent value of a single emitted cell, for comparison against R's integers.
cell_pct <- function(entry, champs_cause, va_cause) {
  ri <- match(champs_cause, entry$champs_causes)
  ci <- match(va_cause, entry$va_causes)
  if (is.na(ri) || is.na(ci)) return(NA_real_)
  100 * entry$matrix[[ri]][[ci]]
}

JOB_CAUSES <- c("congenital_malformation", "pneumonia", "sepsis_meningitis_inf", "ipre", "other", "prematurity")

# Mmat_tomodel as a 3D array [algorithm, CHAMPS cause, VA cause]
JOB_MMAT <- array(
  c(0.6417, 0.4874, 0.0389, 0.0221, 0.0303, 0.0163, 0.0258, 0.0295, 0.0137,
    0.0771, 0.0906, 0.0068, 0.0677, 0.0703, 0.0423, 0.0169, 0.0191, 0.0058,
    0.1126, 0.0390, 0.1002, 0.6097, 0.4135, 0.4518, 0.1872, 0.0668, 0.1536,
    0.2011, 0.0478, 0.0565, 0.2210, 0.0642, 0.1409, 0.0758, 0.0161, 0.0440,
    0.0523, 0.0277, 0.1445, 0.1421, 0.0437, 0.0627, 0.5317, 0.3724, 0.4307,
    0.0764, 0.0164, 0.0254, 0.2345, 0.0707, 0.1411, 0.0343, 0.0431, 0.0402,
    0.0923, 0.1686, 0.1634, 0.1230, 0.2584, 0.2289, 0.1225, 0.2489, 0.1521,
    0.5485, 0.6660, 0.7279, 0.1805, 0.2995, 0.1895, 0.1016, 0.2114, 0.0429,
    0.0223, 0.1499, 0.2178, 0.0171, 0.0320, 0.0207, 0.0122, 0.0521, 0.0162,
    0.0066, 0.0216, 0.0092, 0.0919, 0.0933, 0.1217, 0.0069, 0.0211, 0.0085,
    0.0787, 0.1274, 0.3352, 0.0859, 0.2220, 0.2196, 0.1207, 0.2302, 0.2337,
    0.0903, 0.1576, 0.1742, 0.2044, 0.4021, 0.3645, 0.7644, 0.6891, 0.8586),
  dim = c(3, 6, 6),
  dimnames = list(c("eava", "interva", "insilicova"), JOB_CAUSES, JOB_CAUSES)
)

# p_uncalib [algorithm x cause] and pcalib_postsumm [algorithm x summary x cause]
JOB_P_UNCALIB <- matrix(
  c(0.0468, 0.0353, 0.0008, 0.0262, 0.1787, 0.0689, 0.1244, 0.1199, 0.2840, 0.2244, 0.3050, 0.2702, 0.2851, 0.2420, 0.2748, 0.2660, 0.0309, 0.0134, 0.0521, 0.0322, 0.1745, 0.4160, 0.2429, 0.2855),
  nrow = 4, dimnames = list(c("eava", "interva", "insilicova", "ensemble"), JOB_CAUSES)
)
JOB_PCALIB_POSTSUMM <- array(
  c(0.0233, 0.0271, 0.0008, 0.0017, 0.0012, 0.0013, 0.0008, 0.0002, 0.0589, 0.0669, 0.0008, 0.0049,
    0.0595, 0.0772, 0.0865, 0.0534, 0.0021, 0.0047, 0.0044, 0.0030, 0.1578, 0.1751, 0.2251, 0.1234,
    0.4381, 0.4744, 0.5865, 0.5922, 0.3154, 0.3157, 0.4389, 0.4914, 0.6012, 0.6978, 0.7671, 0.7147,
    0.3446, 0.0613, 0.2019, 0.2092, 0.1955, 0.0020, 0.0472, 0.1141, 0.4752, 0.1650, 0.3223, 0.2905,
    0.0309, 0.0134, 0.0521, 0.0322, 0.0309, 0.0134, 0.0521, 0.0322, 0.0309, 0.0134, 0.0521, 0.0322,
    0.1037, 0.3465, 0.0722, 0.1113, 0.0162, 0.1262, 0.0047, 0.0364, 0.1780, 0.5123, 0.1636, 0.1740),
  dim = c(4, 3, 6),
  dimnames = list(c("eava", "interva", "insilicova", "ensemble"), c("postmean", "lowcredI", "upcredI"), JOB_CAUSES)
)

# R's published "Used For Calibration" panel for job 901322df, read off the
# reference PDF Sandi attached to issue #104
# (https://github.com/user-attachments/files/30411163/neonate.pdf).
# NA = a cell R greys out because the cause was not calibrated. Note insilicova
# greys out congenital_malformation IN ADDITION to other.
R_PANEL <- list(
  eava = rbind(
    congenital_malformation = c(65, 12,  5, 10, NA,  8),
    pneumonia               = c( 2, 62, 15, 12, NA,  9),
    sepsis_meningitis_inf   = c( 3, 19, 54, 12, NA, 12),
    ipre                    = c( 8, 20,  8, 55, NA,  9),
    other                   = c(NA, NA, NA, NA, NA, NA),
    prematurity             = c( 2,  8,  3, 10, NA, 77)
  ),
  interva = rbind(
    congenital_malformation = c(58,  4,  3, 20, NA, 15),
    pneumonia               = c( 3, 43,  4, 27, NA, 23),
    sepsis_meningitis_inf   = c( 3,  7, 39, 27, NA, 24),
    ipre                    = c( 9,  5,  2, 68, NA, 16),
    other                   = c(NA, NA, NA, NA, NA, NA),
    prematurity             = c( 2,  2,  4, 22, NA, 70)
  ),
  insilicova = rbind(
    congenital_malformation = c(NA, NA, NA, NA, NA, NA),
    pneumonia               = c(NA, 47,  7, 23, NA, 23),
    sepsis_meningitis_inf   = c(NA, 16, 44, 16, NA, 24),
    ipre                    = c(NA,  6,  3, 74, NA, 17),
    other                   = c(NA, NA, NA, NA, NA, NA),
    prematurity             = c(NA,  4,  4,  5, NA, 87)
  )
)
for (a in names(R_PANEL)) colnames(R_PANEL[[a]]) <- JOB_CAUSES

# The causes vacalibration did not calibrate for job 901322df, per algorithm.
JOB_NOT_CALIB <- list(
  eava       = "other",
  interva    = "other",
  insilicova = c("congenital_malformation", "other")
)

CAUSES6 <- JOB_CAUSES

# =============================================================================
# 1. Contract preserved: NULL / malformed input
# =============================================================================
section("1. NULL and malformed input")

test("extract_misclass_matrix returns NULL when Mmat_tomodel is absent",
     is.null(extract_misclass_matrix(list(p_uncalib = 1), "x")))

test("extract_misclass_matrix returns NULL for NULL result",
     is.null(extract_misclass_matrix(list(), "x")))

test("normalize_mmat still returns NULL for NULL input", is.null(normalize_mmat(NULL)))

# =============================================================================
# 2. (a) All causes calibrated -> nothing dropped
# =============================================================================
section("2. Boundary (a): all causes calibrated")

res_all <- list(
  Mmat_tomodel = make_array(list(interva = make_slice(CAUSES6))),
  donotcalib_tomodel = make_donotcalib("interva", CAUSES6, character())
)
mm_all <- extract_misclass_matrix(res_all, "interva")

test("(a) all six causes are kept when nothing is excluded",
     identical(mm_all$interva$champs_causes, CAUSES6) &&
     identical(mm_all$interva$va_causes, CAUSES6))
test("(a) rows sum to 1",
     all(abs(row_sums_of(mm_all$interva) - 1) < ROUND_TOL))
test("(a) not_calibrated is empty",
     length(mm_all$interva$not_calibrated) == 0)
test("(a) diagonal is 50/(50+5*10) = 0.5",
     abs(cell_pct(mm_all$interva, "ipre", "ipre") - 50) < ROUND_TOL_PCT)

# =============================================================================
# 3. (b) One excluded cause -> renormalize over the remaining five
# =============================================================================
section("3. Boundary (b): one excluded cause")

res_one <- list(
  Mmat_tomodel = make_array(list(interva = make_slice(CAUSES6))),
  donotcalib_tomodel = make_donotcalib("interva", CAUSES6, "other")
)
mm_one <- extract_misclass_matrix(res_one, "interva")

test("(b) the excluded cause is dropped from BOTH axes",
     !("other" %in% mm_one$interva$champs_causes) &&
     !("other" %in% mm_one$interva$va_causes))
test("(b) five causes remain on each axis",
     length(mm_one$interva$champs_causes) == 5 &&
     length(mm_one$interva$va_causes) == 5)
test("(b) rows sum to 1 over the remaining five",
     all(abs(row_sums_of(mm_one$interva) - 1) < ROUND_TOL))
test("(b) probabilities are INFLATED relative to the 6-cause denominator",
     abs(cell_pct(mm_one$interva, "ipre", "ipre") - 100 * 50 / 90) < ROUND_TOL_PCT)
test("(b) not_calibrated reports the excluded cause",
     identical(mm_one$interva$not_calibrated, "other"))

# =============================================================================
# 4. (c) More than one excluded cause
# =============================================================================
section("4. Boundary (c): two excluded causes")

res_two <- list(
  Mmat_tomodel = make_array(list(insilicova = make_slice(CAUSES6))),
  donotcalib_tomodel = make_donotcalib("insilicova", CAUSES6,
                                       c("congenital_malformation", "other"))
)
mm_two <- extract_misclass_matrix(res_two, "insilicova")

test("(c) both excluded causes are dropped from both axes",
     length(mm_two$insilicova$champs_causes) == 4 &&
     length(mm_two$insilicova$va_causes) == 4 &&
     !any(c("congenital_malformation", "other") %in% mm_two$insilicova$va_causes))
test("(c) rows sum to 1 over the remaining four",
     all(abs(row_sums_of(mm_two$insilicova) - 1) < ROUND_TOL))
test("(c) not_calibrated reports both causes",
     setequal(mm_two$insilicova$not_calibrated,
              c("congenital_malformation", "other")))

# =============================================================================
# 5. (d) A row that sums to zero after masking -> no division by zero
# =============================================================================
section("5. Boundary (d): zero row after masking")

slice_zero <- make_slice(CAUSES6)
# All of ipre's mass sits on the excluded cause; masking leaves a zero row.
slice_zero["ipre", ] <- 0
slice_zero["ipre", "other"] <- 7
res_zero <- list(
  Mmat_tomodel = make_array(list(interva = slice_zero)),
  donotcalib_tomodel = make_donotcalib("interva", CAUSES6, "other")
)
mm_zero <- extract_misclass_matrix(res_zero, "interva")

test("(d) no NaN or Inf is produced by a zero row",
     all(is.finite(unlist(mm_zero$interva$matrix))))
test("(d) the zero row stays all-zero rather than becoming NaN",
     all(mm_zero$interva$matrix[[match("ipre", mm_zero$interva$champs_causes)]] == 0))
test("(d) other rows still sum to 1",
     {
       rs <- row_sums_of(mm_zero$interva)
       keep <- mm_zero$interva$champs_causes != "ipre"
       all(abs(rs[keep] - 1) < ROUND_TOL)
     })

# =============================================================================
# 6. (e) 2D single-algorithm input
# =============================================================================
section("6. Boundary (e): 2D single-algorithm input")

res_2d <- list(
  Mmat_tomodel = make_slice(CAUSES6),
  donotcalib_tomodel = make_donotcalib("eava", CAUSES6, "other")
)
mm_2d <- extract_misclass_matrix(res_2d, "eava")

test("(e) 2D input is labelled with single_algo_name",
     identical(names(mm_2d), "eava"))
test("(e) 2D input masks the excluded cause",
     length(mm_2d$eava$va_causes) == 5 && !("other" %in% mm_2d$eava$va_causes))
test("(e) 2D rows sum to 1",
     all(abs(row_sums_of(mm_2d$eava) - 1) < ROUND_TOL))

# A 2D result with no algorithm dimname must still find its mask when the
# declaration carries a single row.
test("(e) 2D input uses a single-row declaration even if the name differs",
     {
       r <- list(Mmat_tomodel = make_slice(CAUSES6),
                 donotcalib_tomodel = make_donotcalib("combined", CAUSES6, "other"))
       length(extract_misclass_matrix(r, "eava")$eava$va_causes) == 5
     })

# =============================================================================
# 7. (f) 3D multi-algorithm input with DIFFERENT masks per algorithm
# =============================================================================
section("7. Boundary (f): 3D multi-algorithm, per-algorithm masks")

res_3d <- list(
  Mmat_tomodel = make_array(list(
    eava       = make_slice(CAUSES6),
    interva    = make_slice(CAUSES6),
    insilicova = make_slice(CAUSES6)
  )),
  donotcalib_tomodel = make_donotcalib(
    c("eava", "interva", "insilicova"), CAUSES6, JOB_NOT_CALIB)
)
mm_3d <- extract_misclass_matrix(res_3d, "combined")

test("(f) one entry per algorithm, names preserved",
     identical(names(mm_3d), c("eava", "interva", "insilicova")))
test("(f) eava and interva keep five causes",
     length(mm_3d$eava$va_causes) == 5 && length(mm_3d$interva$va_causes) == 5)
test("(f) insilicova keeps only four causes (its own extra exclusion)",
     length(mm_3d$insilicova$va_causes) == 4)
test("(f) every algorithm's rows sum to 1",
     all(sapply(mm_3d, function(e) all(abs(row_sums_of(e) - 1) < ROUND_TOL))))

# =============================================================================
# 8. Version tolerance: the declaring field is named differently per version
# =============================================================================
section("8. Version tolerance across vacalibration 2.0 / 2.2")

mask_field_works <- function(field) {
  r <- list(Mmat_tomodel = make_array(list(interva = make_slice(CAUSES6))))
  r[[field]] <- make_donotcalib("interva", CAUSES6, "other")
  e <- extract_misclass_matrix(r, "interva")$interva
  length(e$va_causes) == 5 && !("other" %in% e$va_causes)
}

test("v2.2 `donotcalib_tomodel` is honoured",  mask_field_works("donotcalib_tomodel"))
test("v2.2 `donotcalib_study` is honoured",    mask_field_works("donotcalib_study"))
test("v2.0 `donotcalib` is honoured",          mask_field_works("donotcalib"))

test("v2.0 `causes_notcalibrated` (named list of character vectors) is honoured",
     {
       r <- list(Mmat_tomodel = make_array(list(interva = make_slice(CAUSES6))),
                 causes_notcalibrated = list(interva = "other"))
       e <- extract_misclass_matrix(r, "interva")$interva
       length(e$va_causes) == 5 && !("other" %in% e$va_causes)
     })

# =============================================================================
# 9. Fallbacks when no declaration is present
# =============================================================================
section("9. Fallbacks")

test("the CSMF passthrough signature identifies not-calibrated causes with NO declaring field",
     {
       r <- list(Mmat_tomodel = JOB_MMAT,
                 p_uncalib = JOB_P_UNCALIB,
                 pcalib_postsumm = JOB_PCALIB_POSTSUMM)
       e <- extract_misclass_matrix(r, "combined")
       setequal(e$eava$not_calibrated, "other") &&
         setequal(e$insilicova$not_calibrated,
                  c("congenital_malformation", "other"))
     })

test("with no declaration AND no CSMF, falls back to vacalibration's own donotcalib default",
     {
       r <- list(Mmat_tomodel = make_array(list(interva = make_slice(CAUSES6))))
       identical(extract_misclass_matrix(r, "interva")$interva$not_calibrated, "other")
     })

# This is the defensive case that matters on the deployed 2.2 backend: the CRAN
# 2.2 manual says `donotcalib_tomodel` is "a modified donotcalib_study if
# donotcalib_type is provided and ensemble=TRUE", and 2.0's ensemble branch ANDs
# the per-algorithm masks -- so an ensemble run's declaration can under-report a
# per-algorithm exclusion. The CSMF read-out must still catch it.
test("an ensemble-collapsed declaration is still corrected by the CSMF read-out",
     {
       r <- list(
         Mmat_tomodel = JOB_MMAT,
         # declares only the intersection ("other") for every algorithm
         donotcalib_tomodel = make_donotcalib(
           c("eava", "interva", "insilicova"), JOB_CAUSES, "other"),
         p_uncalib = JOB_P_UNCALIB,
         pcalib_postsumm = JOB_PCALIB_POSTSUMM
       )
       e <- extract_misclass_matrix(r, "combined")
       setequal(e$insilicova$not_calibrated,
                c("congenital_malformation", "other")) &&
         length(e$insilicova$va_causes) == 4
     })

# =============================================================================
# 10. (g) Numeric regression against R's published values for job 901322df
# =============================================================================
section("10. Boundary (g): numeric regression vs R, job 901322df")

res_job <- list(
  Mmat_tomodel = JOB_MMAT,
  donotcalib_tomodel = make_donotcalib(
    c("eava", "interva", "insilicova"), JOB_CAUSES, JOB_NOT_CALIB),
  p_uncalib = JOB_P_UNCALIB,
  pcalib_postsumm = JOB_PCALIB_POSTSUMM
)
mm_job <- extract_misclass_matrix(res_job, "combined")

# R's plot does NOT simply round each cell. It rounds every cell to an integer and
# then OVERWRITES the row's largest cell with `100 - sum(rounded others)`
# (modular_vacalib_2.0.R:1237-1245). That derived cell can therefore differ from its
# own true value by nearly 1pp even when every underlying number agrees, so a
# comparison against the printed integers can only be asserted to 1pp.
R_TOL <- 1.0

# The informative cells are the NON-derived ones: for those, R printing `x` means
# R's true value was in [x-0.5, x+0.5). The distance of our value from that interval
# is the only honest measure of disagreement. Measured worst case across all three
# algorithms is 0.269pp (43 of the 52 informative cells are satisfied exactly); the
# residual is a difference in the numbers vacalibration itself produced, not in this
# code — see .planning/debug/issue-104-matrix-mismatch.md, "Residual investigation".
# This bound is the tight regression guard; R_TOL alone would let a 0.9pp drift pass.
R_CELL_TOL <- 0.3

for (algo in names(R_PANEL)) {
  panel <- R_PANEL[[algo]]
  entry <- mm_job[[algo]]

  test(sprintf("(g) %s: exactly the causes R greys out are absent", algo),
       {
         expected_kept <- setdiff(JOB_CAUSES, JOB_NOT_CALIB[[algo]])
         setequal(entry$champs_causes, expected_kept) &&
           setequal(entry$va_causes, expected_kept)
       })

  test(sprintf("(g) %s: every row sums to 1", algo),
       all(abs(row_sums_of(entry) - 1) < ROUND_TOL))

  worst <- 0
  worst_at <- ""
  for (rc in rownames(panel)) {
    for (cc in colnames(panel)) {
      expected <- panel[rc, cc]
      if (is.na(expected)) next
      got <- cell_pct(entry, rc, cc)
      if (is.na(got)) { worst <- Inf; worst_at <- paste(rc, cc, "MISSING"); next }
      if (abs(got - expected) > worst) {
        worst <- abs(got - expected)
        worst_at <- sprintf("%s|%s got %.2f want %d", rc, cc, got, expected)
      }
    }
  }
  test(sprintf("(g) %s: all cells match R within %.1fpp (worst: %s)",
               algo, R_TOL, worst_at),
       worst <= R_TOL)

  # Tight bound on the cells R actually rounded (excluding the derived largest one).
  cworst <- 0
  cworst_at <- ""
  for (rc in rownames(panel)) {
    kept <- colnames(panel)[!is.na(panel[rc, ])]
    if (!length(kept)) next
    got_row <- sapply(kept, function(cc) cell_pct(entry, rc, cc))
    derived <- kept[which.max(round(got_row))]  # the cell R overwrites
    for (cc in setdiff(kept, derived)) {
      got <- got_row[[cc]]
      lo <- panel[rc, cc] - 0.5
      hi <- panel[rc, cc] + 0.5
      d <- max(0, lo - got, got - hi)
      if (d > cworst) {
        cworst <- d
        cworst_at <- sprintf("%s|%s got %.3f, R's %d implies [%.1f,%.1f)",
                             rc, cc, got, panel[rc, cc], lo, hi)
      }
    }
  }
  test(sprintf("(g) %s: rounded cells within %.1fpp of R's implied interval (worst: %s)",
               algo, R_CELL_TOL, if (nzchar(cworst_at)) cworst_at else "none"),
       cworst <= R_CELL_TOL)
}

# The single most diagnostic number in the whole issue: before the fix the
# dashboard served 48.74 for this cell while R prints 58.
test("(g) interva congenital_malformation diagonal is ~58, not the deflated 48.74",
     abs(cell_pct(mm_job$interva, "congenital_malformation",
                  "congenital_malformation") - 58) <= R_TOL)

# =============================================================================
# 11. Serialization safety: no NA reaches the JSONB payload
# =============================================================================
section("11. Serialization safety")

# backend/db/connection.R calls toJSON(result, auto_unbox = TRUE) WITHOUT
# na = "null", so an NA cell would serialize as the STRING "NA" and poison the
# payload. Blanked causes must be dropped, never emitted as NA.
test("no NA / NaN / Inf anywhere in the emitted matrices",
     all(sapply(mm_job, function(e) all(is.finite(unlist(e$matrix))))))

test("emitted values are valid probabilities",
     all(sapply(mm_job, function(e) {
       v <- unlist(e$matrix)
       all(v >= 0 & v <= 1)
     })))

test("toJSON of the emitted matrix contains no \"NA\" string",
     {
       if (!requireNamespace("jsonlite", quietly = TRUE)) TRUE
       else !grepl('"NA"', jsonlite::toJSON(mm_job, auto_unbox = TRUE), fixed = TRUE)
     })

# =============================================================================
# Summary
# =============================================================================
cat(sprintf("\n%s\n", strrep("=", 70)))
cat(sprintf("Total: %d  Passed: %d  Failed: %d\n",
            .test_count, .pass_count, .fail_count))
if (.fail_count > 0) {
  cat("\nFailures:\n")
  for (m in .fail_msgs) cat(m, "\n")
  quit(status = 1)
}
cat("All misclassification matrix tests passed.\n")
quit(status = 0)
