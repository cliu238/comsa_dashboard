# backend/auth/middleware.R
# Plumber authentication filter with grace period support

source("auth/tokens.R")

# Grace period: if TRUE, allow unauthenticated requests through (req$user = NULL)
# Set to FALSE after frontend auth ships (Phase 5)
AUTH_GRACE_PERIOD <- TRUE

PUBLIC_ENDPOINTS <- c(
  "/health",
  "/auth/login",
  "/auth/register"
)

auth_filter <- function(req, res) {
  path <- req$PATH_INFO

  # Always skip auth for public endpoints
  if (path %in% PUBLIC_ENDPOINTS) {
    return(plumber::forward())
  }

  auth_header <- req$HTTP_AUTHORIZATION

  # No auth header present
  if (is.null(auth_header) || !grepl("^Bearer ", auth_header)) {
    if (AUTH_GRACE_PERIOD) {
      req$user <- NULL
      return(plumber::forward())
    }
    res$status <- 401
    return(list(error = "Missing or invalid Authorization header"))
  }

  # Validate token
  token <- sub("^Bearer ", "", auth_header)
  claims <- verify_token(token)

  if (is.null(claims)) {
    res$status <- 401
    return(list(error = "Invalid or expired token"))
  }

  # Check if user is active (requires DB lookup)
  user <- find_user_by_id(claims$sub)
  if (is.null(user) || !user$is_active) {
    res$status <- 401
    return(list(error = "Account disabled or not found"))
  }

  req$user <- list(
    id = claims$sub,
    email = claims$email,
    role = claims$role
  )

  plumber::forward()
}

require_admin <- function(req, res) {
  if (is.null(req$user) || req$user$role != "admin") {
    res$status <- 403
    return(list(error = "Admin access required"))
  }
  TRUE
}

# Helper: check if current user owns the job or is admin
check_job_access <- function(job, req, res) {
  if (is.null(req$user)) return(TRUE)  # Grace period: no user = allow
  if (req$user$role == "admin") return(TRUE)
  if (is.null(job$user_id)) return(TRUE)  # Legacy job with no owner
  if (job$user_id == req$user$id) return(TRUE)
  res$status <- 403
  return(list(error = "Access denied"))
}
