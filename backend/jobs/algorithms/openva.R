# openVA Algorithm Implementation
# Runs InterVA, InSilicoVA, or EAVA algorithms

# Run openVA processing
run_openva <- function(job) {
  add_log(job$id, "Starting openVA processing")

  # Load data
  if (isTRUE(job$use_sample_data)) {
    add_log(job$id, "Loading sample data")
    input_data <- load_openva_sample(job$age_group, job$id)
  } else {
    add_log(job$id, paste("Loading data from:", job$input_file))
    input_data <- read.csv(job$input_file, stringsAsFactors = FALSE)
  }

  add_log(job$id, paste("Data loaded:", nrow(input_data), "records"))

  # Run openVA
  add_log(job$id, paste("Running", job$algorithm))

  if (job$algorithm == "InterVA") {
    result <- run_with_capture(job$id, {
      codeVA(
        data = input_data,
        data.type = "WHO2016",
        model = "InterVA",
        version = "5.0",
        HIV = "l",
        Malaria = "l",
        write = FALSE
      )
    })
  } else if (job$algorithm == "InSilicoVA") {
    # InSilicoVA uses rjags which has scoping issues in future contexts
    # Workaround: assign data to global environment temporarily
    assign("..insilico_data..", input_data, envir = .GlobalEnv)
    on.exit(rm("..insilico_data..", envir = .GlobalEnv), add = TRUE)
    result <- run_with_capture(job$id, {
      codeVA(
        data = ..insilico_data..,
        data.type = "WHO2016",
        model = "InSilicoVA",
        Nsim = 4000,
        auto.length = FALSE,
        write = FALSE
      )
    })
  } else if (job$algorithm == "EAVA") {
    # EAVA requires an 'age' column in days and 'fb_day0' column
    input_data_eava <- input_data
    if (!"age" %in% names(input_data_eava)) {
      input_data_eava$age <- if (job$age_group == "neonate") {
        rep(14, nrow(input_data_eava))  # Default to 14 days for neonates
      } else {
        rep(180, nrow(input_data_eava))  # Default to 6 months for children
      }
    }

    # Add fb_day0 (death on first day of life) - default to "n" for WHO2016 data
    if (!"fb_day0" %in% names(input_data_eava)) {
      input_data_eava$fb_day0 <- "n"
    }

    result <- run_with_capture(job$id, {
      codeVA(
        data = input_data_eava,
        data.type = "EAVA",
        model = "EAVA",
        age_group = job$age_group,
        write = FALSE
      )
    })
  } else {
    stop(paste("Unsupported algorithm:", job$algorithm))
  }

  add_log(job$id, "openVA processing complete")

  # Extract cause assignments
  cod <- getTopCOD(result)
  add_log(job$id, paste("Assigned causes for", nrow(cod), "deaths"))

  # Get CSMF
  csmf <- getCSMF(result)

  # Save outputs
  output_dir <- file.path("data", "outputs", job$id)
  dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

  causes_file <- file.path(output_dir, "causes.csv")
  write.csv(cod, causes_file, row.names = FALSE)

  # Track output file in database
  add_job_file(job$id, "output", "causes.csv", causes_file, file.info(causes_file)$size)

  add_log(job$id, "Results saved")

  # Return summary
  list(
    n_records = nrow(cod),
    cause_counts = as.list(table(cod$cause1)),
    csmf = as.list(csmf),
    files = list(
      causes = "causes.csv"
    )
  )
}
