# Run the plumber API server

library(plumber)

# Pre-initialize database connection pool before starting server
source("db/connection.R")
message("Pre-warming database connection pool...")
pool <- get_db_pool()
message("Database connection pool ready with ", pool::poolSize(pool), " connections")

# Load and run the API
pr <- plumber::plumb("plumber.R")
pr$run(host = "0.0.0.0", port = 8000)
