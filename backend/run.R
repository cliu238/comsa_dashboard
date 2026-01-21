# Run the plumber API server

library(plumber)

# Load and run the API
pr <- plumber::plumb("plumber.R")
pr$run(host = "0.0.0.0", port = 8000)
