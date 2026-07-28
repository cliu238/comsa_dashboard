#!/usr/bin/env Rscript
# Input-file persistence base64 codec (issue #110) — backend/jobs/utils.R
#
# The DB read/write (save_input_file / restore_input_files) needs a live
# Postgres and is verified post-deploy. What is unit-testable without a DB is the
# byte-exact round-trip that everything else rests on: a CSV written to the DB as
# base64 must come back byte-identical, or a rehydrated input silently differs
# from what the user uploaded. Deliberately dependency-free (base R + jsonlite).

.test_count <- 0; .pass_count <- 0; .fail_count <- 0; .fail_msgs <- character()
test <- function(name, expr) {
  .test_count <<- .test_count + 1
  ok <- tryCatch(isTRUE(expr), error = function(e) {
    .fail_msgs <<- c(.fail_msgs, sprintf("  FAIL: %s -- error: %s", name, conditionMessage(e))); FALSE })
  if (ok) { .pass_count <<- .pass_count + 1; cat(sprintf("  PASS: %s\n", name)) }
  else { .fail_count <<- .fail_count + 1
    if (!any(grepl(name, .fail_msgs, fixed = TRUE)))
      .fail_msgs <<- c(.fail_msgs, sprintf("  FAIL: %s -- returned FALSE", name))
    cat(sprintf("  FAIL: %s\n", name)) }
}
section <- function(t) cat(sprintf("\n=== %s ===\n", t))

utils_path <- if (file.exists("backend/jobs/utils.R")) "backend/jobs/utils.R" else "../backend/jobs/utils.R"
source(utils_path)

tmp <- tempfile("persist_test_"); dir.create(tmp)
roundtrip <- function(bytes) {
  src <- file.path(tmp, "src.bin"); writeBin(bytes, src)
  dst <- file.path(tmp, "sub", "dst.bin")   # nested dir: decode must create it
  decode_b64_to_file(encode_file_b64(src), dst)
  readBin(dst, "raw", n = file.info(dst)$size)
}

section("1. A typical VA CSV survives the round-trip byte-for-byte")

csv <- charToRaw("ID,cause\nn1,Birth asphyxia\nn2,Neonatal sepsis\nn3,Prematurity\n")
test("decoded bytes are identical to the original", identical(roundtrip(csv), csv))
test("decode recreates a missing destination directory", {
  # roundtrip above wrote into tmp/sub which did not exist beforehand
  file.exists(file.path(tmp, "sub", "dst.bin"))
})

section("2. Edge content the codec must not corrupt")

test("empty file round-trips to empty", identical(roundtrip(raw(0)), raw(0)))
test("UTF-8 (accented cause names) survives", {
  b <- charToRaw("ID,cause\n1,pneumonie aiguë\n2,paludisme\n"); identical(roundtrip(b), b)
})
test("embedded CR/LF and quotes survive", {
  b <- charToRaw("ID,cause\r\n1,\"sepsis, neonatal\"\r\n"); identical(roundtrip(b), b)
})
test("arbitrary binary bytes (0x00-0xFF) survive", {
  b <- as.raw(0:255); identical(roundtrip(b), b)
})
test("a larger file (50k rows) survives", {
  big <- charToRaw(paste0("ID,cause\n", paste(sprintf("id%d,Prematurity", 1:50000), collapse = "\n"), "\n"))
  identical(roundtrip(big), big)
})

section("3. base64 output is a plausible ASCII payload for a TEXT column")

test("encode returns a single non-empty ASCII string", {
  s <- encode_file_b64(file.path(tmp, "src.bin"))
  is.character(s) && length(s) == 1 && nzchar(s) && !grepl("[^A-Za-z0-9+/=\r\n]", s)
})

section("4. job_input_paths pulls a path from whichever field carries it")

# The CodeRabbit finding: load_job returns the DB column `input_file_path`, not
# `input_file`, so a single-file job must still yield a path or restore no-ops.
test("single-file job via input_file",
     identical(job_input_paths(list(input_file = "data/uploads/j/input.csv")),
               "data/uploads/j/input.csv"))
test("single-file job via the raw DB column input_file_path",
     identical(job_input_paths(list(input_file_path = "data/uploads/j/input.csv")),
               "data/uploads/j/input.csv"))
test("ensemble job via input_files (order preserved)",
     identical(job_input_paths(list(input_files = c("a/input_interva.csv", "a/input_eava.csv"))),
               c("a/input_interva.csv", "a/input_eava.csv")))
test("input_file and input_file_path duplicate collapses to one",
     identical(job_input_paths(list(input_file = "p.csv", input_file_path = "p.csv")), "p.csv"))
test("a sample-data job (no input fields) yields nothing",
     length(job_input_paths(list(use_sample_data = TRUE))) == 0)
for (empty in list(NULL, NA, NA_character_, character(0), "")) {
  test(sprintf("empty input_file_path (%s) yields nothing",
               paste(utils::capture.output(str(empty)), collapse = " ")),
       length(job_input_paths(list(input_file_path = empty))) == 0)
}

unlink(tmp, recursive = TRUE)

cat(sprintf("\n%s\n", strrep("=", 70)))
cat(sprintf("Total: %d  Passed: %d  Failed: %d\n", .test_count, .pass_count, .fail_count))
if (.fail_count > 0) { cat("\nFailures:\n"); for (m in .fail_msgs) cat(m, "\n"); quit(status = 1) }
cat("All input persistence tests passed.\n")
quit(status = 0)
