# Ensemble Algorithm Runner
# Runs multiple VA algorithms for ensemble calibration

# Run multiple algorithms and return named list for ensemble
run_multiple_algorithms <- function(algorithms, input_data, age_group, job_id) {
  results <- list()

  for (algo in algorithms) {
    add_log(job_id, paste("Running algorithm:", algo))

    if (algo == "InterVA") {
      result <- run_with_capture(job_id, {
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
      results[["interva"]] <- result

    } else if (algo == "InSilicoVA") {
      # InSilicoVA global env workaround - assign to global variable
      # Use a unique variable name to avoid conflicts
      global_var_name <- paste0("..insilico_data_", job_id, "..")
      assign(global_var_name, input_data, envir = .GlobalEnv)

      # Call codeVA with data from global environment
      # Use backticks to escape the variable name (UUIDs have hyphens)
      result <- run_with_capture(job_id, {
        eval(parse(text = sprintf(
          "codeVA(data = `%s`, data.type = 'WHO2016', model = 'InSilicoVA', Nsim = 4000, auto.length = FALSE, write = FALSE)",
          global_var_name
        )), envir = .GlobalEnv)
      })

      # Clean up global variable
      rm(list = global_var_name, envir = .GlobalEnv)
      results[["insilicova"]] <- result

    } else if (algo == "EAVA") {
      # EAVA requires an 'age' column in days and 'fb_day0' column
      # Note: EAVA may not work properly with WHO2016 data format
      tryCatch({
        input_data_eava <- input_data
        if (!"age" %in% names(input_data_eava)) {
          input_data_eava$age <- if (age_group == "neonate") {
            rep(14, nrow(input_data_eava))  # Default to 14 days for neonates
          } else {
            rep(180, nrow(input_data_eava))  # Default to 6 months for children
          }
        }

        # Add fb_day0 (death on first day of life) - default to "n" for WHO2016 data
        if (!"fb_day0" %in% names(input_data_eava)) {
          input_data_eava$fb_day0 <- "n"
        }

        result <- run_with_capture(job_id, {
          codeVA(
            data = input_data_eava,
            data.type = "EAVA",
            model = "EAVA",
            age_group = age_group,
            write = FALSE
          )
        })
        results[["eava"]] <- result
        add_log(job_id, paste(algo, "complete"))
      }, error = function(e) {
        add_log(job_id, paste("EAVA failed:", conditionMessage(e), "- skipping"))
        # Don't add to results if it failed
      })
      next  # Skip the normal completion log below
    }

    add_log(job_id, paste(algo, "complete"))
  }

  return(results)
}
